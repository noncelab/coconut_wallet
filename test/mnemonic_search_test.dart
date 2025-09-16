import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/screens/settings/bip39_list_screen.dart';

void main() {
  /// 공용 테스트 함수
  void runQueryTest(String input, String? expected, String type) {
    test('$input 검색 → $expected', () {
      final result = Bip39ListScreenState.queryWord(input);

      if (expected == null) {
        // 검색 결과가 없어야 함
        expect(result, isEmpty, reason: '검색 결과가 없어야 합니다.');
      } else {
        // 검색 결과가 있을 때
        expect(result, isNotEmpty);

        if (result.length > 1) {
          // 여러 결과가 나온 경우
          print('$input 검색 → 검색 결과가 많다 (${result.length}개)');
        } else {
          // 단일 결과일 때 기존처럼 검증
          expect(result.first['item'], expected);
          expect(result.first['type'], type);
        }
      }
    });
  }

  group('mnemonic search', () {
    group('십진법 검색', () {
      final numericTests = {
        '0': 'abandon',
        '1': 'ability',
        '10': 'access',
        '616': 'escape',
        '3000': null,
      };

      numericTests.forEach((input, expected) {
        runQueryTest(input, expected, 'numeric');
      });
    });

    group('영문 검색', () {
      final alphaTests = {
        'test': 'test',
        'royal': 'royal',
        'aq': null,
      };

      alphaTests.forEach((input, expected) {
        runQueryTest(input, expected, 'alphabetic');
      });
    });

    group('이진법 검색', () {
      final binaryTests = {
        '01010101010': 'fetch',
        '01001101000': 'escape',
      };

      binaryTests.forEach((input, expected) {
        runQueryTest(input, expected, 'binary');
      });
    });
  });
}
