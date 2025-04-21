import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:ur/utils.dart';
import 'package:ur/constants.dart';

int rotl(int x, int k) {
  return (x << k) | (x >>> (64 - k));
}

final List<int> JUMP = [
  0x180ec6d33cfd0aba,
  0xd5a61266f0c9392c,
  0xa9582618e03fc9aa,
  0x39abdc4529b1661c
];

final List<int> LONG_JUMP = [
  0x76e15d3efefdcbbf,
  0xc5004e441c522fb3,
  0x77710069854ee241,
  0x39109bb02acbe635
];

class Xoshiro256 {
  List<int> s = List<int>.filled(4, 0);

  Xoshiro256([List<int>? arr]) {
    if (arr != null) {
      for (int i = 0; i < 4; i++) {
        s[i] = arr[i];
      }
    }
  }

  void _setS(Uint8List arr) {
    for (int i = 0; i < 4; i++) {
      int o = i * 8;
      int v = 0;
      for (int n = 0; n < 8; n++) {
        v <<= 8;
        v |= arr[o + n];
        // print("v: " + v.toString());
      }
      s[i] = v;
    }
    // print("s: " + s.toString());
  }

  void _hashThenSetS(Uint8List buf) {
    var digest = sha256.convert(buf).bytes;
    _setS(Uint8List.fromList(digest));
  }

  static Xoshiro256 fromInt8Array(Uint8List arr) {
    var x = Xoshiro256();
    x._setS(arr);
    return x;
  }

  static Xoshiro256 fromBytes(Uint8List buf) {
    var x = Xoshiro256();
    x._hashThenSetS(buf);
    return x;
  }

  static Xoshiro256 fromCrc32(int crc32) {
    var x = Xoshiro256();
    var buf = intToBytes(crc32);
    x._hashThenSetS(buf);
    return x;
  }

  static Xoshiro256 fromString(String s) {
    var x = Xoshiro256();
    var buf = stringToBytes(s);
    x._hashThenSetS(buf);
    return x;
  }

  BigInt next() {
    var resultRaw = rotl(s[1] * 5, 7) * 9;
    BigInt result = BigInt.from(resultRaw).toUnsigned(64);

    int t = (s[1] << 17);

    s[2] ^= s[0];
    s[3] ^= s[1];
    s[1] ^= s[2];
    s[0] ^= s[3];

    s[2] ^= t;

    s[3] = rotl(s[3], 45);

    return result;
  }

  double nextDouble() {
    BigInt m = BigInt.from(MAX_UINT64).toUnsigned(64) + BigInt.one;
    BigInt nxt = next();
    return nxt / m;
  }

  int nextInt(int low, int high) {
    return (nextDouble() * (high - low + 1) + low).floor() & MAX_UINT64;
  }

  int nextByte() {
    return nextInt(0, 255);
  }

  Uint8List nextData(int count) {
    var result = Uint8List(count);
    for (int i = 0; i < count; i++) {
      result[i] = nextByte();
    }
    return result;
  }

  void jump() {
    int s0 = 0, s1 = 0, s2 = 0, s3 = 0;
    for (int i = 0; i < JUMP.length; i++) {
      for (int b = 0; b < 64; b++) {
        if ((JUMP[i] & (1 << b)) != 0) {
          s0 ^= s[0];
          s1 ^= s[1];
          s2 ^= s[2];
          s3 ^= s[3];
        }
        next();
      }
    }
    s[0] = s0;
    s[1] = s1;
    s[2] = s2;
    s[3] = s3;
  }

  void longJump() {
    int s0 = 0, s1 = 0, s2 = 0, s3 = 0;
    for (int i = 0; i < LONG_JUMP.length; i++) {
      for (int b = 0; b < 64; b++) {
        if ((LONG_JUMP[i] & (1 << b)) != 0) {
          s0 ^= s[0];
          s1 ^= s[1];
          s2 ^= s[2];
          s3 ^= s[3];
        }
        next();
      }
    }
    s[0] = s0;
    s[1] = s1;
    s[2] = s2;
    s[3] = s3;
  }
}
