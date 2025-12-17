import 'package:ur/ur.dart';
import 'package:ur/fountain_encoder.dart';
import 'package:ur/bytewords.dart' as Bytewords;

class UREncoder {
  final UR ur;
  final FountainEncoder fountainEncoder;

  UREncoder(this.ur, int maxFragmentLen, {int firstSeqNum = 0, int minFragmentLen = 10})
    : fountainEncoder = FountainEncoder(
        ur.cbor,
        maxFragmentLen,
        firstSeqNum: firstSeqNum,
        minFragmentLen: minFragmentLen,
      );

  static String encode(UR ur) {
    String body = Bytewords.encodeStyle(Bytewords.Style.minimal, ur.cbor);
    return UREncoder.encodeUR([ur.type, body]);
  }

  // Set<int> lastPartIndexes() {
  // return fountainEncoder.lastPartIndexes;
  // }

  bool get isComplete => fountainEncoder.isComplete;

  bool get isSinglePart => fountainEncoder.isSinglePart;

  String nextPart() {
    FountainEncoderPart part = fountainEncoder.nextPart();
    if (isSinglePart) {
      return UREncoder.encode(ur);
    } else {
      return UREncoder.encodePart(ur.type, part);
    }
  }

  static String encodePart(String type, FountainEncoderPart part) {
    String seq = '${part.seqNum}-${part.seqLen}';
    String body = Bytewords.encodeStyle(Bytewords.Style.minimal, part.cbor());
    return UREncoder.encodeUR([type, seq, body]);
  }

  static String encodeUri(String scheme, List<String> pathComponents) {
    String path = pathComponents.join('/');
    return '$scheme:$path';
  }

  static String encodeUR(List<String> pathComponents) {
    return UREncoder.encodeUri('ur', pathComponents);
  }
}
