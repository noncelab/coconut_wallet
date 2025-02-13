import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

String hashString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

String hexHashString(String input) {
  final bytes = hex.decode(input);
  final digest = sha256.convert(bytes);
  return hex.encode(digest.bytes);
}
