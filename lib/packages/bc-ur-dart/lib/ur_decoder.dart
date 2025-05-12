import 'package:ur/ur.dart';
import 'package:ur/fountain_encoder.dart' as FountainEncoder;
import 'package:ur/fountain_decoder.dart' as FountainDecoder;
import 'package:ur/bytewords.dart' as Bytewords;
import 'package:ur/utils.dart';

class InvalidScheme implements Exception {}

class InvalidType implements Exception {}

class InvalidPathLength implements Exception {}

class InvalidSequenceComponent implements Exception {}

class InvalidFragment implements Exception {}

class URDecoder {
  final FountainDecoder.FountainDecoder fountainDecoder = FountainDecoder.FountainDecoder();
  String? expectedType;
  dynamic result;

  static UR decode(String str) {
    var (type, components) = URDecoder.parse(str);
    if (components.isEmpty) {
      throw InvalidPathLength();
    }

    var body = components[0];
    return URDecoder.decodeByType(type, body);
  }

  static UR decodeByType(String type, String body) {
    var cbor = Bytewords.decodeStyle(Bytewords.Style.minimal, body);
    return UR(type, cbor);
  }

  static (String, List<String>) parse(String str) {
    // Don't consider case
    var lowered = str.toLowerCase();

    // Validate URI scheme
    if (!lowered.startsWith('ur:')) {
      throw InvalidScheme();
    }

    var path = lowered.substring(3);

    // Split the remainder into path components
    var components = path.split('/');

    // Make sure there are at least two path components
    if (components.length < 2) {
      throw InvalidPathLength();
    }

    // Validate the type
    var type = components[0];
    if (!isUrType(type)) {
      throw InvalidType();
    }

    var comps = components.sublist(1); // Don't include the ur type
    return (type, comps);
  }

  static (int, int) parseSequenceComponent(String str) {
    try {
      var comps = str.split('-');
      if (comps.length != 2) {
        throw InvalidSequenceComponent();
      }
      var seqNum = int.parse(comps[0]);
      var seqLen = int.parse(comps[1]);
      if (seqNum < 1 || seqLen < 1) {
        throw InvalidSequenceComponent();
      }
      return (seqNum, seqLen);
    } catch (_) {
      throw InvalidSequenceComponent();
    }
  }

  bool validatePart(String type) {
    if (expectedType == null) {
      if (!isUrType(type)) {
        return false;
      }
      expectedType = type;
      return true;
    } else {
      return type == expectedType;
    }
  }

  bool receivePart(String str) {
    try {
      // Don't process the part if we're already done
      if (result != null) {
        return false;
      }

      // Don't continue if this part doesn't validate
      var (type, components) = URDecoder.parse(str);
      if (!validatePart(type)) {
        return false;
      }

      // If this is a single-part UR then we're done
      if (components.length == 1) {
        var body = components[0];
        result = URDecoder.decodeByType(type, body);
        return true;
      }

      // Multi-part URs must have two path components: seq/fragment
      if (components.length != 2) {
        throw InvalidPathLength();
      }
      var seq = components[0];
      var fragment = components[1];

      // Parse the sequence component and the fragment, and make sure they agree.
      var (seqNum, seqLen) = URDecoder.parseSequenceComponent(seq);
      var cbor = Bytewords.decodeStyle(Bytewords.Style.minimal, fragment);
      var part = FountainEncoder.FountainEncoderPart.fromCbor(cbor);
      if (seqNum != part.seqNum || seqLen != part.seqLen) {
        return false;
      }

      // Process the part
      if (!fountainDecoder.receivePart(part)) {
        return false;
      }

      if (fountainDecoder.isSuccess()) {
        result = UR(type, fountainDecoder.resultMessage());
      } else if (fountainDecoder.isFailure()) {
        result = fountainDecoder.resultError();
      }

      return true;
    } catch (err) {
      return false;
    }
  }

  // String? expectedType() {
  // return expectedType;
  // }

  int? expectedPartCount() {
    return fountainDecoder.expectedPartCount();
  }

  Set<int> receivedPartIndexes() {
    return fountainDecoder.receivedPartIndexes;
  }

  Set<int>? lastPartIndexes() {
    return fountainDecoder.lastPartIndexes;
  }

  int processedPartsCount() {
    return fountainDecoder.processedPartsCount;
  }

  double estimatedPercentComplete() {
    return fountainDecoder.estimatedPercentComplete();
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
}
