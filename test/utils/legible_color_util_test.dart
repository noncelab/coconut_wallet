import 'package:coconut_wallet/utils/legible_color_util.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _lightness(Color color) => HSLColor.fromColor(color).lightness;

void main() {
  const dark = Color(0xFF1C1C1E);
  const light = Color(0xFFF2F2F7);

  test('a color far enough from the surface is kept as is', () {
    const orange = Color(0xFFF7931A);
    expect(legibleOn(orange, dark), orange);
  });

  test('a color close to a dark surface is lifted and one close to a light surface is pushed down', () {
    final lifted = legibleOn(const Color(0xFF2C2C30), dark);
    final pushed = legibleOn(const Color(0xFFE0E0E8), light);

    expect(_lightness(lifted) - _lightness(dark), closeTo(0.28, 0.01));
    expect(_lightness(light) - _lightness(pushed), closeTo(0.28, 0.01));
    expect(HSLColor.fromColor(lifted).hue, closeTo(HSLColor.fromColor(const Color(0xFF2C2C30)).hue, 1));
  });
}
