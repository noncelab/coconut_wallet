import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextUtils.preventLineBreakInsideWords', () {
    // 여러 코드 포인트로 된 이모지(국기·ZWJ 가족·피부색·키캡·VS16)가 든 한글 문장. 지갑 이름처럼 사용자가 쓴 글에 들어온다
    for (final text in ['🇰🇷 저축 지갑', '가족👨‍👩‍👧 생활비', '좋아요👍🏽 Daily', '1️⃣번 지갑', '사랑❤️ 지갑']) {
      test('"$text": joins grapheme clusters, so emoji stay whole, words stay joined and spaces stay', () {
        final joined = TextUtils.preventLineBreakInsideWords(text);
        // 이음 문자만 더한다: 띄어쓰기(줄을 바꿀 자리)는 그대로
        expect(joined.replaceAll('\u2060', ''), text);
        final words = joined.split(' ');
        expect(words, hasLength(text.split(' ').length));
        for (final (i, word) in text.split(' ').indexed) {
          // 단어 안 글자 묶음 사이마다 이음 문자 하나: 단어 가운데서 줄이 바뀌지 않고, 이모지 묶음 안에는 끼지 않는다
          expect(words[i].split('\u2060'), word.characters.toList(), reason: word);
        }
      });
    }
  });

  group('TextUtils.ellipsisIfLonger', () {
    test('ASCII and Korean keep the same output', () {
      expect(TextUtils.ellipsisIfLonger('abcdefghijklmnop', maxLength: 15), 'abcdefghijkl...');
      expect(TextUtils.ellipsisIfLonger('가나다라마바사아자차카타파하가나', maxLength: 15), '가나다라마바사아자차카타...');
      expect(TextUtils.ellipsisIfLonger('Daily', maxLength: 15), 'Daily');
    });

    // 같은 지갑 팝업은 이름을 15자로 줄인다(앞 12자 + "..."). 자르는 자리에 걸친 이모지는 묶음째 남아야 한다.
    // UTF-16 단위로 자르면 짝 없는 서로게이트(깨진 글자)가 남는다
    for (final emoji in ['🇰🇷', '👨‍👩‍👧', '👍🏽']) {
      test('"$emoji" right at the cut stays whole', () {
        expect(TextUtils.ellipsisIfLonger('가나다라마바사아자차카${emoji}wxyz', maxLength: 15), '가나다라마바사아자차카$emoji...');
      });
    }

    test('counts grapheme clusters, so a short emoji name is not cut', () {
      expect(TextUtils.ellipsisIfLonger('🇰🇷🇯🇵🇺🇸🇩🇪 지갑', maxLength: 15), '🇰🇷🇯🇵🇺🇸🇩🇪 지갑');
    });
  });
}
