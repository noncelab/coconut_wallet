#include <flutter/runtime_effect.glsl>

// A backdrop filter shader: bends and rim-lights whatever is already behind it (the caller
// is expected to blur that backdrop first via ImageFilter.compose, since a real Gaussian blur
// from the engine is both cheaper and higher quality than one hand-rolled in a fragment shader).
//
// Uniform order matters: ImageFilter.shader requires the first uniform to be a vec2 (the
// engine overwrites it with the filtered surface's own size) and the first (only) sampler2D
// to be the filtered input - see dart:ui's ImageFilter.shader docs. Everything after those two
// is ours to set from Dart via FragmentShader.setFloat, index-numbered ignoring the sampler.
uniform vec2 uSize;
uniform float uRadius;
uniform float uDistortion;
uniform float uDistortionWidth;
uniform float uMagnification;
uniform vec4 uTintColor;
uniform vec4 uRimColor;
uniform float uRimWidth;
// Which sides of the shape show the rim: 1.0 to include that axis's pair of sides, 0.0 to
// exclude it. Both 1.0 gives a uniform rim all the way around (see the mask math below).
uniform float uRimHorizontal;
uniform float uRimVertical;

uniform sampler2D uTexture;

out vec4 fragColor;

// Signed distance to a centered rounded box: negative inside, zero on the border, positive
// outside. Standard formulation (Inigo Quilez) - b is the half-size, r the corner radius.
float sdRoundedBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Analytic gradient of sdRoundedBox. A finite-difference gradient (sampling the SDF a pixel to
// either side and subtracting) breaks down here: abs(p) has a derivative kink at p.x == 0 and
// p.y == 0, so any sample straddling those lines reads a wrong/discontinuous normal - visible as
// a seam running down the box's own vertical/horizontal centerlines. This computes the gradient
// directly from which region of the box a point falls in instead, so there is no kink to cross.
vec2 sdRoundedBoxNormal(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  vec2 s = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
  if (q.x > 0.0 && q.y > 0.0) {
    // Rounded-corner region: the gradient points radially away from the arc's own center.
    return s * normalize(q);
  } else if (q.x > q.y) {
    return vec2(s.x, 0.0); // nearer a left/right edge
  } else {
    return vec2(0.0, s.y); // nearer a top/bottom edge
  }
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 halfSize = uSize * 0.5;
  vec2 p = fragCoord - halfSize;
  float r = min(uRadius, min(halfSize.x, halfSize.y));

  float d = sdRoundedBox(p, halfSize, r);
  vec2 normal = sdRoundedBoxNormal(p, halfSize, r);

  // 0 well inside the shape, 1 right at the rim - the band the refraction bulge lives in.
  float bandWidth = max(uDistortionWidth, 1.0);
  float bandT = clamp((d + bandWidth) / bandWidth, 0.0, 1.0);
  // Grows toward the rim rather than peaking mid-band and easing back out - like light
  // bending more and more sharply the closer it passes to a lens's own edge.
  float bulge = bandT * bandT;

  vec2 magnified = halfSize + p / max(uMagnification, 0.0001);
  vec2 refracted = magnified - normal * bulge * uDistortion * bandWidth;

  vec2 sampleUv = clamp(refracted / uSize, vec2(0.0), vec2(1.0));
  vec4 backdrop = texture(uTexture, sampleUv);

  vec3 tinted = mix(backdrop.rgb, uTintColor.rgb, uTintColor.a);

  // A thin glass-edge highlight, like the rim of an actual sheet of glass seen edge-on. normal
  // is a unit vector, so normal.x^2 + normal.y^2 == 1 everywhere - with both side uniforms at
  // 1.0 that sums to a uniform rim; dropping one to 0.0 fades that pair of sides out smoothly
  // (including through the rounded corners, which blend between the two) instead of a hard cut.
  //
  // The product abs(nx * ny) rises toward 45-degree normals, i.e. the rounded corners. We use
  // that to softly suppress the rim specifically in the top-right and bottom-left corners, so
  // "top/bottom rims" don't look unnaturally wrapped around those two diagonal corners.
  float rimT = 1.0 - smoothstep(0.0, max(uRimWidth, 1.0), abs(d));
  float sideMask = uRimHorizontal * (normal.x * normal.x) + uRimVertical * (normal.y * normal.y);
  float cornerAmount = smoothstep(0.12, 0.42, abs(normal.x * normal.y));
  float topRight = step(0.0, p.x) * step(p.y, 0.0);
  float bottomLeft = step(p.x, 0.0) * step(0.0, p.y);
  float suppressedCornerMask = 1.0 - max(topRight, bottomLeft) * cornerAmount * uRimVertical;
  vec3 rim = uRimColor.rgb * rimT * sideMask * suppressedCornerMask * uRimColor.a;

  fragColor = vec4(tinted + rim, backdrop.a);
}
