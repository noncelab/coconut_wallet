import 'dart:math';

import 'package:coconut_wallet/screens/wallet_detail/wallet_info/mnemonic_backup_confirm_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('selectMnemonicChallengeIndices', () {
    for (final wordCount in [12, 24]) {
      test('$wordCount개 단어에서 서로 다른 3개 위치를 선택한다', () {
        final indices = selectMnemonicChallengeIndices(wordCount: wordCount, random: Random(42));

        expect(indices, hasLength(3));
        expect(indices.toSet(), hasLength(3));
        expect(indices.every((index) => index >= 0 && index < wordCount), isTrue);
      });
    }

    test('3개 미만의 단어는 확인 문제를 만들 수 없다', () {
      expect(() => selectMnemonicChallengeIndices(wordCount: 2, random: Random(42)), throwsArgumentError);
    });

    test('패스프레이즈 확인이 있으면 서로 다른 니모닉 3개를 선택한다', () {
      final indices = selectMnemonicChallengeIndices(wordCount: 12, challengeCount: 3, random: Random(42));
      expect(indices, hasLength(3));
      expect(indices.toSet(), hasLength(3));
    });
  });
}
