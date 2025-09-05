import 'dart:convert';
import 'dart:typed_data';
import 'package:base32/base32.dart';

class BbQrEncoder {
  final int maxChunkSize;
  final String encodingType; // 예: 'Z' (zlib)
  final String dataType; // 예: 'P' (PSBT)

  BbQrEncoder({
    this.maxChunkSize = 800, // Qr 버전 27에 더 적합한 크기
    this.encodingType = 'Z',
    this.dataType = 'P',
  });

  List<String> encodeBase64(String base64String) {
    final originalBytes = base64.decode(base64String);
    final chunks = _chunkBytes(originalBytes, maxChunkSize);
    final total = chunks.length;

    final encodedChunks = <String>[];
    for (int i = 0; i < total; i++) {
      // Base32 패딩 제거
      final base32Data =
          base32.encode(Uint8List.fromList(chunks[i])).replaceAll(RegExp(r'=+$'), '');
      final totalStr = total.toRadixString(36).padLeft(2, '0').toUpperCase();
      final indexStr = i.toRadixString(36).padLeft(2, '0').toUpperCase();
      final header = 'B\$U$dataType$totalStr$indexStr'; // 'U' = uncompressed
      final fullPart = '$header$base32Data';

      encodedChunks.add(fullPart);
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
