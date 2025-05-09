import 'dart:typed_data';
import 'dart:convert';
import 'package:ur/crc32.dart';

Uint8List crc32Bytes(Uint8List buf) {
  return CRC32.crc32n(buf);
}

int crc32Int(Uint8List buf) {
  return CRC32.crc32(buf);
}

String dataToHex(Uint8List buf) {
  return buf.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List intToBytes(int n) {
  return Uint8List.fromList([
    (n >> 24) & 0xFF,
    (n >> 16) & 0xFF,
    (n >> 8) & 0xFF,
    n & 0xFF,
  ]);
}

int bytesToInt(Uint8List buf) {
  return (buf[0] << 24) | (buf[1] << 16) | (buf[2] << 8) | buf[3];
}

Uint8List stringToBytes(String s) {
  return Uint8List.fromList(utf8.encode(s));
}

bool isUrType(String type) {
  return RegExp(r'^[a-z0-9-]+$').hasMatch(type);
}

List<String> partition(String s, int n) {
  return List.generate((s.length / n).ceil(),
      (i) => s.substring(i * n, (i + 1) * n > s.length ? s.length : (i + 1) * n));
}

Tuple<Uint8List, Uint8List> split(Uint8List buf, int count) {
  return Tuple(buf.sublist(0, count), buf.sublist(count));
}

List<T> joinLists<T>(List<List<T>> lists) {
  return lists.expand((list) => list).toList();
}

Uint8List joinBytes(List<Uint8List> listOfBa) {
  return Uint8List.fromList(listOfBa.expand((ba) => ba).toList());
}

void xorInto(Uint8List target, Uint8List source) {
  assert(target.length == source.length, "Must be the same length");
  for (int i = 0; i < target.length; i++) {
    target[i] ^= source[i];
  }
}

Uint8List xorWith(Uint8List a, Uint8List b) {
  Uint8List target = Uint8List.fromList(a);
  xorInto(target, b);
  return target;
}

Uint8List takeFirst(Uint8List s, int count) {
  return s.sublist(0, count);
}

Uint8List dropFirst(Uint8List s, int count) {
  return s.sublist(count);
}

class Tuple<T1, T2> {
  final T1 item1;
  final T2 item2;

  Tuple(this.item1, this.item2);
}
