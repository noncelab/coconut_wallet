import 'dart:ui';

Color? fromHexString(String input) {
  String normalized = input.replaceFirst('#', '');

  if (normalized.length == 6) {
    normalized = 'FF$normalized';
  }

  if (normalized.length != 8) {
    return null;
  }

  final int? decimal = int.tryParse(normalized, radix: 16);
  return decimal == null ? null : Color(decimal);
}
