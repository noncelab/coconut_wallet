import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:base32/base32.dart';
import 'package:flutter/foundation.dart';

class BbQrEncoder {
  final int maxChunkSize;
  final String encodingTypeInstance;
  final String dataTypeInstance;

  BbQrEncoder({this.maxChunkSize = 800, String encodingType = 'Z', String dataType = 'P'})
    : encodingTypeInstance = encodingType,
      dataTypeInstance = dataType;

  // PSBT
  List<String> encodeBase64(String base64String) {
    final originalBytes = base64.decode(base64String);
    final chunks = _chunkBytes(originalBytes, maxChunkSize);
    final total = chunks.length;

    final encodedChunks = <String>[];
    for (int i = 0; i < total; i++) {
      final base32Data = base32.encode(Uint8List.fromList(chunks[i])).replaceAll(RegExp(r'=+$'), '');

      final totalStr = total.toRadixString(36).padLeft(2, '0').toUpperCase();
      final indexStr = i.toRadixString(36).padLeft(2, '0').toUpperCase();

      final header = 'B\$U$dataTypeInstance$totalStr$indexStr';
      final fullPart = '$header$base32Data';

      encodedChunks.add(fullPart);
    }
    return encodedChunks;
  }

  // 압축(Coldcard)
  static List<String> encode({
    required String data,
    String dataType = 'U',
    String encodingType = 'Z',
    int maxFragmentLength = 1200,
  }) {
    try {
      List<int> rawBytes = utf8.encode(data);
      List<int> processedBytes;

      if (encodingType == 'Z') {
        processedBytes = Deflate(rawBytes).getBytes();
      } else if (encodingType == '2') {
        processedBytes = rawBytes;
      } else if (encodingType == 'H') {
        processedBytes = rawBytes;
      } else {
        throw Exception('Unsupported encoding type: $encodingType');
      }

      if (processedBytes.isEmpty) {
        debugPrint('--> BbQrEncoder: processedBytes is empty');
        return [];
      }

      List<List<int>> chunks = _chunkBytes(processedBytes, maxFragmentLength);

      int total = chunks.length;
      if (total > 1295) {
        throw Exception('Data too large: exceeds BBQr fragment limit.');
      }

      List<String> qrStrings = [];

      for (int i = 0; i < total; i++) {
        String totalStr = total.toRadixString(36).toUpperCase().padLeft(2, '0');
        String indexStr = i.toRadixString(36).toUpperCase().padLeft(2, '0');

        String header = 'B\$$encodingType$dataType$totalStr$indexStr';
        String payload;

        if (encodingType == 'H') {
          payload = utf8.decode(chunks[i]);
        } else {
          payload = base32.encode(Uint8List.fromList(chunks[i]));
          payload = payload.replaceAll('=', '');
        }

        qrStrings.add(header + payload);
      }

      return qrStrings;
    } catch (e, st) {
      debugPrint('--> BbQrEncoder.encode error: $e\n$st');
      return [];
    }
  }

  static List<List<int>> _chunkBytes(List<int> bytes, int chunkSize) {
    final chunks = <List<int>>[];
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize;
      chunks.add(bytes.sublist(i, end));
    }
    return chunks;
  }
}
