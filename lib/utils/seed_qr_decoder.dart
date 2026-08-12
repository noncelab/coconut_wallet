import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:crypto/crypto.dart';

class SeedQrDecoder {
  const SeedQrDecoder._();

  static Uint8List? decode({String? code, List<int>? rawBytes}) {
    List<String>? words;
    try {
      if (code == null && rawBytes != null) {
        words = _decodeCompactQR(rawBytes);
      } else if (code != null && rawBytes != null) {
        words = _decodeStandardQR(code);
      }
    } catch (e) {
      if (e is FormatException && e.message.contains('Invalid radix-10 number') && rawBytes != null) {
        words = _decodeCompactQR(rawBytes);
      } else {
        return null;
      }
    }

    if (words == null || (words.length != 12 && words.length != 24)) {
      return null;
    }
    return Uint8List.fromList(utf8.encode(words.join(' ')));
  }

  static List<String> _decodeStandardQR(String data) {
    final words = <String>[];
    final indexes = <int>[];
    for (var i = 0; i < data.length; i += 4) {
      final idx = int.parse(data.substring(i, i + 4));
      indexes.add(idx);
      words.add(wordList[idx]);
    }
    return words;
  }

  static List<String>? _decodeCompactQR(List<int> bytes) {
    var wordCount = 0;
    try {
      wordCount = _detectMnemonicWords(bytes);
      List<int> usefulBits = _getUsefulBits(bytes, wordCount);
      int expectedLength = wordCount == 12 ? 132 : 264;

      List<int> paddedBits = List.from(usefulBits);
      while (paddedBits.length < expectedLength) {
        paddedBits.add(0);
      }
      if (paddedBits.length > expectedLength) {
        paddedBits = paddedBits.sublist(0, expectedLength);
      }

      final indices = <int>[];
      List<String> words = [];
      for (var i = 0; i < paddedBits.length; i += 11) {
        final index = _bitsToInt(paddedBits.sublist(i, i + 11));
        indices.add(index);
        words.add(wordList[index]);
      }

      int checksum = _computeChecksum(paddedBits, wordCount);
      int lastIndex = indices[indices.length - 1] + checksum;

      words.replaceRange(words.length - 1, words.length, [wordList[lastIndex]]);
      return words;
    } catch (_) {
      return null;
    }
  }

  static int _detectMnemonicWords(List<int> rawBytes) {
    final len = rawBytes.length;
    if (len <= 20) {
      return 12;
    } else if (len <= 36) {
      return 24;
    } else {
      throw ArgumentError('Unsupported CompactSeedQR length: $len (must be 12 or 24 words)');
    }
  }

  static List<int> _getUsefulBits(List<int> bytes, int wordCount) {
    final bits = <int>[];
    for (final b in bytes) {
      for (int i = 7; i >= 0; i--) {
        bits.add((b >> i) & 1);
      }
    }

    if (bits.length < 3 * 8) {
      throw Exception('Invalid QR data: too short');
    }

    if (wordCount == 12) {
      if (bits[0] == 0 &&
          bits[1] == 1 &&
          bits[2] == 0 &&
          bits[3] == 0 &&
          bits[4] == 0 &&
          bits[5] == 0 &&
          bits[6] == 0 &&
          bits[7] == 1 &&
          bits[8] == 0 &&
          bits[9] == 0 &&
          bits[10] == 0 &&
          bits[11] == 0 &&
          bits[bits.length - 12] == 0 &&
          bits[bits.length - 11] == 0 &&
          bits[bits.length - 10] == 0 &&
          bits[bits.length - 9] == 0 &&
          bits[bits.length - 8] == 1 &&
          bits[bits.length - 7] == 1 &&
          bits[bits.length - 6] == 1 &&
          bits[bits.length - 5] == 0 &&
          bits[bits.length - 4] == 1 &&
          bits[bits.length - 3] == 1 &&
          bits[bits.length - 2] == 0 &&
          bits[bits.length - 1] == 0) {
        return bits.sublist(12, bits.length - 12);
      }
    }

    if (wordCount == 24) {
      if (bits[0] == 0 &&
          bits[1] == 1 &&
          bits[2] == 0 &&
          bits[3] == 0 &&
          bits[4] == 0 &&
          bits[5] == 0 &&
          bits[6] == 1 &&
          bits[7] == 0 &&
          bits[8] == 0 &&
          bits[9] == 0 &&
          bits[10] == 0 &&
          bits[11] == 0 &&
          bits[bits.length - 4] == 0 &&
          bits[bits.length - 3] == 0 &&
          bits[bits.length - 2] == 0 &&
          bits[bits.length - 1] == 0) {
        return bits.sublist(12, bits.length - 4);
      }
    }

    return bits.sublist(12);
  }

  static int _bitsToInt(List<int> bits) {
    var val = 0;
    for (final bit in bits) {
      val = (val << 1) | bit;
    }
    return val;
  }

  static int _computeChecksum(List<int> bits, int wordCount) {
    int entropyLength = wordCount == 12 ? 128 : 256;
    int checksumLength = wordCount == 12 ? 4 : 8;

    int entropyBytesLength = entropyLength ~/ 8;
    Uint8List entropyBytes = Uint8List(entropyBytesLength);
    for (int i = 0; i < entropyLength; i++) {
      int byteIndex = i ~/ 8;
      entropyBytes[byteIndex] |= bits[i] << (7 - (i % 8));
    }

    Digest hash = sha256.convert(entropyBytes);
    int mask = (1 << checksumLength) - 1;
    int checksum = (hash.bytes[0] >> (8 - checksumLength)) & mask;
    return checksum;
  }
}
