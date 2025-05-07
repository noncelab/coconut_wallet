import 'dart:typed_data';
import 'package:ur/constants.dart';

class CRC32 {
  static List<int>? _table;

  static int crc32(Uint8List buf) {
    // Lazily instantiate CRC table
    if (_table == null) {
      _table = List<int>.filled(256 * 4, 0);

      for (int i = 0; i < 256; i++) {
        int c = i;
        for (int j = 0; j < 8; j++) {
          c = (c % 2 == 0) ? (c >> 1) : (0xEDB88320 ^ (c >> 1));
        }
        _table![i] = c;
      }
    }

    int crc = MAX_UINT32 & ~0;
    for (int byte in buf) {
      crc = (crc >> 8) ^ _table![(crc ^ byte) & 0xFF];
    }

    return MAX_UINT32 & ~crc;
  }

  static Uint8List crc32n(Uint8List buf) {
    int n = crc32(buf);
    return Uint8List(4)..buffer.asByteData().setUint32(0, n, Endian.big);
  }
}
