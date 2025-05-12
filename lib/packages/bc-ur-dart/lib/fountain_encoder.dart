import 'dart:math';
import 'dart:typed_data';
import 'package:ur/cbor_lite.dart';
import 'package:ur/fountain_utils.dart';
import 'package:ur/utils.dart';
import 'package:ur/constants.dart';

class InvalidHeader implements Exception {
  String message;
  InvalidHeader([this.message = 'Invalid header']);
}

class FountainEncoderPart {
  final int seqNum;
  final int seqLen;
  final int messageLen;
  final int checksum;
  final Uint8List data;

  FountainEncoderPart(this.seqNum, this.seqLen, this.messageLen, this.checksum, this.data);

  static FountainEncoderPart fromCbor(Uint8List cborBuf) {
    var decoder = CBORDecoder(cborBuf);
    var (arraySize, _) = decoder.decodeArraySize();
    if (arraySize != 5) {
      throw InvalidHeader();
    }

    var (seqNum, _) = decoder.decodeUnsigned();
    var (seqLen, _) = decoder.decodeUnsigned();
    var (messageLen, _) = decoder.decodeUnsigned();
    var (checksum, _) = decoder.decodeUnsigned();
    var (data, _) = decoder.decodeBytes();

    return FountainEncoderPart(seqNum, seqLen, messageLen, checksum, data);
  }

  Uint8List cbor() {
    var encoder = CBOREncoder();
    encoder.encodeArraySize(5);
    encoder.encodeInteger(seqNum);
    encoder.encodeInteger(seqLen);
    encoder.encodeInteger(messageLen);
    encoder.encodeInteger(checksum);
    encoder.encodeBytes(data);
    return encoder.getBytes();
  }

  String description() {
    return "seqNum:$seqNum, seqLen:$seqLen, messageLen:$messageLen, checksum:$checksum, data:${dataToHex(data)}";
  }
}

class FountainEncoder {
  final int messageLen;
  final int checksum;
  final int fragmentLen;
  final List<Uint8List> fragments;
  int seqNum;

  FountainEncoder(Uint8List message, int maxFragmentLen,
      {int firstSeqNum = 0, int minFragmentLen = 10})
      : messageLen = message.length,
        checksum = crc32Int(message),
        fragmentLen = findNominalFragmentLength(message.length, minFragmentLen, maxFragmentLen),
        fragments = partitionMessage(
            message, findNominalFragmentLength(message.length, minFragmentLen, maxFragmentLen)),
        seqNum = firstSeqNum {
    assert(message.length <= MAX_UINT32);
  }

  static int findNominalFragmentLength(int messageLen, int minFragmentLen, int maxFragmentLen) {
    assert(messageLen > 0);
    assert(minFragmentLen > 0);
    assert(maxFragmentLen >= minFragmentLen);
    int maxFragmentCount = messageLen ~/ minFragmentLen;
    int fragmentLen = messageLen;

    for (int fragmentCount = 1; fragmentCount <= maxFragmentCount; fragmentCount++) {
      fragmentLen = (messageLen / fragmentCount).ceil();
      if (fragmentLen <= maxFragmentLen) {
        break;
      }
    }

    return fragmentLen;
  }

  static List<Uint8List> partitionMessage(Uint8List message, int fragmentLen) {
    List<Uint8List> fragments = [];
    for (int i = 0; i < message.length; i += fragmentLen) {
      int end = min(i + fragmentLen, message.length);
      Uint8List fragment = Uint8List(fragmentLen);
      fragment.setAll(0, message.sublist(i, end));
      fragments.add(fragment);
    }
    return fragments;
  }

  // Set<int> get lastPartIndexes =>
  // chooseDegree(seqNum, seqLen, checksum).toSet();

  int get seqLen => fragments.length;

  bool get isComplete => seqNum >= seqLen;

  bool get isSinglePart => seqLen == 1;

  FountainEncoderPart nextPart() {
    seqNum++;
    seqNum %= MAX_UINT32; // wrap at period 2^32
    var indexes = chooseFragments(seqNum, seqLen, checksum);
    var mixed = mix(indexes);
    return FountainEncoderPart(seqNum, seqLen, messageLen, checksum, mixed);
  }

  Uint8List mix(Set<int> indexes) {
    var result = Uint8List(fragmentLen);
    for (var index in indexes) {
      xorInto(result, fragments[index]);
    }
    return result;
  }
}
