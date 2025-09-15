import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _queryWord(String input) {
    final query = input.toLowerCase();
    final isBinary = RegExp(r'^[01]+$').hasMatch(query);
    final isNumeric = RegExp(r'^\d+$').hasMatch(query);
    final isAlphabetic = RegExp(r'^[a-zA-Z]+$').hasMatch(query);

    final numericResults = <Map<String, dynamic>>[];
    final binaryResults = <Map<String, dynamic>>[];
    final alphabeticResults = <Map<String, dynamic>>[];

    for (var i = 0; i < wordList.length; i++) {
      final indexNum = i + 1;
      final item = wordList[i];
      final binaryStr = (indexNum - 1).toRadixString(2).padLeft(11, '0');

      // 숫자 검색
      if (isNumeric && query.length <= 4 && i.toString() == query) {
        numericResults.add({'index': indexNum, 'item': item, 'type': 'numeric'});
      }

      // 이진 검색
      if (isBinary && binaryStr.contains(query)) {
        binaryResults.add({'index': indexNum, 'item': item, 'type': 'binary'});
      }

      // 알파벳 검색
      if (isAlphabetic && item.toLowerCase().contains(query)) {
        alphabeticResults.add({'index': indexNum, 'item': item, 'type': 'alphabetic'});
      }
    }

    // 알파벳 검색 → startsWith 우선 정렬
    if (isAlphabetic) {
      alphabeticResults.sort((a, b) {
        final itemA = (a['item'] as String).toLowerCase();
        final itemB = (b['item'] as String).toLowerCase();
        final startsWithA = itemA.startsWith(query);
        final startsWithB = itemB.startsWith(query);

        if (startsWithA && !startsWithB) return -1;
        if (!startsWithA && startsWithB) return 1;
        return itemA.compareTo(itemB);
      });
      return alphabeticResults;
    } else {
      return [
        ...numericResults..sort((a, b) => a['index'].compareTo(b['index'])),
        ...binaryResults..sort((a, b) => a['index'].compareTo(b['index']))
      ];
    }
  }

void main() {
  group('mnemonic search', () {
    group('십진법 검색', () {
      final numericTests = {
        '0': 'abandon',
        '1': 'ability',
        '10': 'access',
        '616': 'escape',
      };

      numericTests.forEach((input, expected) {
        test('$input 검색 → $expected', () {
          final result = _queryWord(input);
          expect(result.first['item'], expected);
          expect(result.first['type'], 'numeric');
        });
      });
    });

    group('영문 검색', () {
      final alphaTests = {
        'test': 'test',
        'royal': 'royal',
      };

      alphaTests.forEach((input, expected) {
        test('$input 검색 → $expected', () {
          final result = _queryWord(input);
          expect(result.first['item'], expected);
          expect(result.first['type'], 'alphabetic');
        });
      });
    });

    group('이진법 검색', () {
      final binaryTests = {
        '01010101010': 'fetch',
        '01001101000': 'escape',
      };

      binaryTests.forEach((input, expected) {
        test('$input 검색 → $expected', () {
          final result = _queryWord(input);
          expect(result.first['item'], expected);
          expect(result.first['type'], 'binary');
        });
      });
    });
  });
}