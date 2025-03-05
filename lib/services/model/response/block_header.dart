import 'dart:convert';
import 'dart:typed_data';
import 'package:coconut_lib/coconut_lib.dart' as lib;

/// Entity class for block header
class BlockHeader {
  int height = 0;
  int timestamp;
  String header;
  int? version;
  Uint8List? prevBlockHash;
  Uint8List? merkleRoot;
  Uint8List? bits;
  Uint8List? nonce;

  ///@nodoc
  BlockHeader(
    this.height,
    this.timestamp,
    this.header, {
    this.version,
    this.prevBlockHash,
    this.merkleRoot,
    this.bits,
    this.nonce,
  });

  /// Parse the block header
  factory BlockHeader.parse(int height, String header) {
    Uint8List bytes = lib.Codec.decodeHex(header);
    int version = lib.Converter.littleEndianToInt(bytes.sublist(0, 4));
    Uint8List prevBlockHash =
        Uint8List.fromList(bytes.sublist(4, 36).reversed.toList());
    Uint8List merkleRoot =
        Uint8List.fromList(bytes.sublist(36, 68).reversed.toList());
    int timestamp = lib.Converter.littleEndianToInt(bytes.sublist(68, 72));
    Uint8List bits = bytes.sublist(72, 76);
    Uint8List nonce = bytes.sublist(76, 80);

    return BlockHeader(height, timestamp, header,
        version: version,
        prevBlockHash: prevBlockHash,
        merkleRoot: merkleRoot,
        bits: bits,
        nonce: nonce);
  }

  ///@nodoc
  BlockHeader.fromJson(Map<String, dynamic> json)
      : height = json['height'],
        timestamp = json['timestamp'],
        header = json['header'],
        version = json['version'],
        prevBlockHash = json['prevBlockHash'] != null
            ? base64Decode(json['prevBlockHash'])
            : null,
        merkleRoot = json['merkleRoot'] != null
            ? base64Decode(json['merkleRoot'])
            : null,
        bits = json['bits'] != null ? base64Decode(json['bits']) : null,
        nonce = json['nonce'] != null ? base64Decode(json['nonce']) : null;

  ///@nodoc
  Map<String, dynamic> toJson() {
    return {
      'height': height,
      'timestamp': timestamp,
      'header': header,
      'version': version,
      'prevBlockHash':
          prevBlockHash != null ? base64Encode(prevBlockHash!) : null,
      'merkleRoot': merkleRoot != null ? base64Encode(merkleRoot!) : null,
      'bits': bits != null ? base64Encode(bits!) : null,
      'nonce': nonce != null ? base64Encode(nonce!) : null,
    };
  }
}
