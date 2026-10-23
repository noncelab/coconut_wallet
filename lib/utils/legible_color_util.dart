import 'package:flutter/painting.dart';

/// [color]의 명도가 [surface]와 비슷하면 잘 보이지 않으므로, 표면과의 명도 차이를 최소한도 이상으로 밀어낸다.
/// UTXO 구간 색처럼 테마마다 밝기가 다른 색을 어떤 표면 위에서든 고르게 보이게 할 때 쓴다.
Color legibleOn(Color color, Color surface) {
  const minLightnessGap = 0.28;
  final hsl = HSLColor.fromColor(color);
  final surfaceLightness = HSLColor.fromColor(surface).lightness;
  if ((hsl.lightness - surfaceLightness).abs() >= minLightnessGap) return color;
  final target = surfaceLightness >= 0.5 ? surfaceLightness - minLightnessGap : surfaceLightness + minLightnessGap;
  return hsl.withLightness(target.clamp(0.0, 1.0)).toColor();
}
