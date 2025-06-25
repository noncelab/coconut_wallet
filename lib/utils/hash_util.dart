import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateHashString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// 여러 개의 파라미터(int, String)를 조합하여 안정적인 integer ID를 생성합니다.
int generateHashInt(List<dynamic> params) {
  final buffer = StringBuffer();
  bool hasValidParam = false;

  for (int i = 0; i < params.length; i++) {
    final param = params[i];
    if (param is String || param is int) {
      if (hasValidParam) buffer.write('_');
      buffer.write(param);
      hasValidParam = true;
    }
  }

  if (!hasValidParam) return 0;

  final digest = sha256.convert(utf8.encode(buffer.toString()));
  final bytes = digest.bytes;

  return ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]).abs();
}
