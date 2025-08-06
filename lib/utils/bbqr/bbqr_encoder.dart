import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:base32/base32.dart';

class BbqrEncoder {
  final int maxChunkSize;
  final String encodingType; // 예: 'Z' (zlib)
  final String dataType; // 예: 'P' (PSBT)

  BbqrEncoder({
    this.maxChunkSize = 500,
    this.encodingType = 'Z',
    this.dataType = 'P',
  });

  List<String> encodeBase64(String base64String) {
    final compressedBytes = ZLibCodec(raw: true).encode(base64.decode(base64String));
    final chunks = _chunkBytes(compressedBytes, maxChunkSize);
    final total = chunks.length;

    final encodedChunks = <String>[];
    for (int i = 0; i < total; i++) {
      final base32Data = base32.encode(Uint8List.fromList(chunks[i]));
      final totalStr = total.toRadixString(36).padLeft(2, '0').toUpperCase();
      final indexStr = i.toRadixString(36).padLeft(2, '0').toUpperCase();
      final header = 'B\$$encodingType$dataType$totalStr$indexStr';
      encodedChunks.add('$header$base32Data');
    }
    return encodedChunks;
  }

  List<List<int>> _chunkBytes(List<int> bytes, int chunkSize) {
    final chunks = <List<int>>[];
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize;
      chunks.add(bytes.sublist(i, end));
    }
    return chunks;
  }
}
