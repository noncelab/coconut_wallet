import 'dart:typed_data';
import 'package:ur/fountain_encoder.dart';
import 'package:ur/fountain_utils.dart';
import 'package:ur/utils.dart';

class InvalidPart implements Exception {
  String message;
  InvalidPart([this.message = 'Invalid part']);
}

class InvalidChecksum implements Exception {
  String message;
  InvalidChecksum([this.message = 'Invalid checksum']);
}

class FountainDecoderPart {
  final Set<int> indexes;
  final Uint8List data;

  FountainDecoderPart(this.indexes, this.data);

  factory FountainDecoderPart.fromEncoderPart(FountainEncoderPart p) {
    return FountainDecoderPart(chooseFragments(p.seqNum, p.seqLen, p.checksum), Uint8List.fromList(p.data));
  }

  bool get isSimple => indexes.length == 1;

  int get index => indexes.first;
}

class FountainDecoder {
  Set<int> receivedPartIndexes = {};
  Set<int>? lastPartIndexes;
  int processedPartsCount = 0;
  dynamic result;
  Set<int>? expectedPartIndexes;
  int? expectedFragmentLen;
  int? expectedMessageLen;
  int? expectedChecksum;
  Map<Set<int>, FountainDecoderPart> simpleParts = {};
  Map<Set<int>, FountainDecoderPart> mixedParts = {};
  List<FountainDecoderPart> queuedParts = [];

  int? expectedPartCount() {
    return expectedPartIndexes?.length;
  }

  bool isSuccess() {
    return result != null && result is! Exception;
  }

  bool isFailure() {
    return result != null && result is Exception;
  }

  bool isComplete() {
    return result != null;
  }

  dynamic resultMessage() {
    return result;
  }

  Exception? resultError() {
    return result is Exception ? result : null;
  }

  double estimatedPercentComplete() {
    if (isComplete()) {
      return 1;
    }
    if (expectedPartIndexes == null) {
      return 0;
    }
    double estimatedInputParts = expectedPartCount()! * 1.75;
    return (processedPartsCount / estimatedInputParts).clamp(0, 0.99);
  }

  bool receivePart(FountainEncoderPart encoderPart) {
    if (isComplete()) {
      return false;
    }

    if (!validatePart(encoderPart)) {
      return false;
    }

    var p = FountainDecoderPart.fromEncoderPart(encoderPart);
    lastPartIndexes = p.indexes;
    enqueue(p);

    while (!isComplete() && queuedParts.isNotEmpty) {
      processQueueItem();
    }

    processedPartsCount++;

    return true;
  }

  static Uint8List joinFragments(List<Uint8List> fragments, int messageLen) {
    var message = joinBytes(fragments);
    return takeFirst(message, messageLen);
  }

  void enqueue(FountainDecoderPart p) {
    queuedParts.add(p);
  }

  void processQueueItem() {
    var part = queuedParts.removeAt(0);

    if (part.isSimple) {
      processSimplePart(part);
    } else {
      processMixedPart(part);
    }
  }

  void reduceBy(FountainDecoderPart p) {
    var reducedParts = mixedParts.values.map((value) => reducePartByPart(value, p)).toList();

    var newMixed = <Set<int>, FountainDecoderPart>{};
    for (var reducedPart in reducedParts) {
      if (reducedPart.isSimple) {
        enqueue(reducedPart);
      } else {
        newMixed[reducedPart.indexes] = reducedPart;
      }
    }

    mixedParts = newMixed;
  }

  FountainDecoderPart reducePartByPart(FountainDecoderPart a, FountainDecoderPart b) {
    if (isStrictSubset(b.indexes, a.indexes)) {
      var newIndexes = a.indexes.difference(b.indexes);
      var newData = xorWith(Uint8List.fromList(a.data), b.data);
      return FountainDecoderPart(newIndexes, newData);
    } else {
      return a;
    }
  }

  void processSimplePart(FountainDecoderPart p) {
    var fragmentIndex = p.index;
    if (receivedPartIndexes.contains(fragmentIndex)) {
      return;
    }

    simpleParts[p.indexes] = p;
    receivedPartIndexes.add(fragmentIndex);

    if (receivedPartIndexes.length == expectedPartIndexes!.length) {
      var sortedParts = simpleParts.values.toList()..sort((a, b) => a.index.compareTo(b.index));

      var fragments = sortedParts.map((part) => part.data).toList();

      var message = joinFragments(fragments, expectedMessageLen!);

      var checksum = crc32Int(message);
      if (checksum == expectedChecksum) {
        result = message;
      } else {
        result = InvalidChecksum();
      }
    } else {
      reduceBy(p);
    }
  }

  void processMixedPart(FountainDecoderPart p) {
    if (mixedParts.values.any((r) => r.indexes == p.indexes)) {
      return;
    }

    var p2 = p;
    for (var r in simpleParts.values) {
      p2 = reducePartByPart(p2, r);
    }

    for (var r in mixedParts.values) {
      p2 = reducePartByPart(p2, r);
    }

    if (p2.isSimple) {
      enqueue(p2);
    } else {
      reduceBy(p2);
      mixedParts[p2.indexes] = p2;
    }
  }

  bool validatePart(FountainEncoderPart p) {
    if (expectedPartIndexes == null) {
      expectedPartIndexes = Set<int>.from(List<int>.generate(p.seqLen, (i) => i));
      expectedMessageLen = p.messageLen;
      expectedChecksum = p.checksum;
      expectedFragmentLen = p.data.length;
    } else {
      if (expectedPartCount() != p.seqLen) return false;
      if (expectedMessageLen != p.messageLen) return false;
      if (expectedChecksum != p.checksum) return false;
      if (expectedFragmentLen != p.data.length) return false;
    }

    return true;
  }
}
