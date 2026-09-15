import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/mnemonic_backup_confirm_screen.dart';
import 'package:flutter/material.dart';
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

  group('splitMnemonicWordBytes', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    test('공백 기준으로 단어를 분리한다', () {
      final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic));
      final words = splitMnemonicWordBytes(mnemonicBytes);

      expect(words, hasLength(12));
      for (int i = 0; i < 12; i++) {
        expect(words[i], equals(utf8.encode(i == 11 ? 'about' : 'abandon')));
      }
    });

    test('선행/후행/다중 공백을 무시한다', () {
      final mnemonicBytes = Uint8List.fromList(utf8.encode('  abandon   abandon  about  '));
      final words = splitMnemonicWordBytes(mnemonicBytes);

      expect(words, hasLength(3));
      expect(words[0], equals(utf8.encode('abandon')));
      expect(words[1], equals(utf8.encode('abandon')));
      expect(words[2], equals(utf8.encode('about')));
    });

    test('빈 입력은 빈 리스트를 반환한다', () {
      expect(splitMnemonicWordBytes(Uint8List(0)), isEmpty);
    });

    test('각 단어는 원본 버퍼와 독립적인 복사본이다', () {
      final mnemonicBytes = Uint8List.fromList(utf8.encode('abandon about'));
      final words = splitMnemonicWordBytes(mnemonicBytes);

      // 원본을 wipe해도 단어 복사본은 영향을 받지 않는다
      mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
      expect(words[0], equals(utf8.encode('abandon')));
      expect(words[1], equals(utf8.encode('about')));
    });
  });

  group('mnemonicGhostSuffix', () {
    test('wordlist 단어의 앞 4글자를 입력하면 나머지 글자를 반환한다', () {
      expect(mnemonicGhostSuffix(input: 'aban'), 'don');
      expect(mnemonicGhostSuffix(input: 'zebr'), 'a');
      expect(completeMnemonicWordOnSpace(input: 'zebr '), 'zebra');
    });

    test('4글자 미만이거나 접두어가 틀리면 표시하지 않는다', () {
      expect(mnemonicGhostSuffix(input: 'aba'), isEmpty);
      expect(mnemonicGhostSuffix(input: 'abcd'), isEmpty);
    });

    test('단어를 전부 입력하면 표시하지 않는다', () {
      expect(mnemonicGhostSuffix(input: 'abandon'), isEmpty);
    });

    test('고스트 텍스트가 표시된 상태에서 스페이스를 입력하면 단어를 완성한다', () {
      expect(completeMnemonicWordOnSpace(input: 'aban '), 'abandon');
    });

    test('고스트 텍스트 표시 조건이 아니면 스페이스로 자동완성하지 않는다', () {
      expect(completeMnemonicWordOnSpace(input: 'aba '), isNull);
      expect(completeMnemonicWordOnSpace(input: 'abcd '), isNull);
      expect(completeMnemonicWordOnSpace(input: 'abandon '), isNull);
    });
  });

  testWidgets('고스트 텍스트가 보일 때 스페이스를 누르면 실제 입력값을 완성한다', (tester) async {
    final mnemonic = Uint8List.fromList(utf8.encode(List<String>.filled(12, 'abandon').join(' ')));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: MnemonicBackupConfirmScreen(mnemonic: mnemonic, passphrase: Uint8List(0)),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(EditableText), 'aban ');
    await tester.pump();

    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'abandon');
  });
}
