import 'dart:io';

import 'package:coconut_wallet/services/label_file_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LabelFileService', () {
    test('readFileLines reads large memo JSONL files without truncating lines', () async {
      const service = LabelFileService();
      const lineCount = 5000;
      final longMemo = 'large memo '.padRight(256 * 1024, 'x');
      final directory = await Directory.systemTemp.createTemp('label_file_service_test_');
      final file = File('${directory.path}/large-memos.jsonl');

      try {
        final sink = file.openWrite();
        for (var i = 0; i < lineCount; i++) {
          final label = i == lineCount - 1 ? longMemo : 'memo-$i';
          sink.writeln('{"type":"tx","ref":"${i.toRadixString(16).padLeft(64, '0')}","label":"$label"}');
        }
        await sink.close();

        final lines = await service.readFileLines(file.path);

        expect(lines.length, equals(lineCount));
        expect(lines.first, contains('"label":"memo-0"'));
        expect(lines.last, contains(longMemo));
        expect(lines.last.length, greaterThan(longMemo.length));
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });
}
