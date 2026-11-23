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

    // 태국어는 낱말 사이를 띄우지 않는다. 이음 문자를 넣으면 문장이 한 덩어리가 되어 음절 중간에서 줄이 바뀐다
    test('Thai words are left as they are, so the renderer can break lines between words', () {
      const thai = 'เพิ่มกระเป๋าแบบดูอย่างเดียว เพื่อดูยอดคงเหลือและรับบิตคอยน์';
      expect(TextUtils.preventLineBreakInsideWords(thai), thai);
      expect(TextUtils.preventLineBreakInsideWords('ธีม Coconut'), 'ธีม C\u2060o\u2060c\u2060o\u2060n\u2060u\u2060t');
    });

    test('a sentence with Thai and Korean joins only the words without Thai letters', () {
      expect(TextUtils.preventLineBreakInsideWords('지갑 กระเป๋า 추가'), '지\u2060갑 กระเป๋า 추\u2060가');
    });

    // 띄어쓰기 없이 붙여 쓴 낱말에 태국 글자가 하나라도 있으면 그 낱말 전체를 그대로 둔다
    test('a word that mixes Thai with other letters is left whole', () {
      expect(TextUtils.preventLineBreakInsideWords('지갑กระเป๋า Coconutธีม'), '지갑กระเป๋า Coconutธีม');
    });

    test('spans keep their children, style and semantics label; only texts without Thai are joined', () {
      const style = TextStyle(fontSize: 14);
      final result =
          TextUtils.preventLineBreakInsideWordsInSpan(
                const TextSpan(
                  text: 'กระเป๋าเงิน ',
                  style: style,
                  semanticsLabel: 'wallet',
                  children: [TextSpan(text: '지갑'), TextSpan(text: 'เพิ่มกระเป๋า')],
                ),
              )
              as TextSpan;
      expect(result.text, 'กระเป๋าเงิน ');
      expect(result.style, style);
      expect(result.semanticsLabel, 'wallet');
      expect(result.children!.map((child) => (child as TextSpan).text), ['지\u2060갑', 'เพิ่มกระเป๋า']);
      // 이음 문자가 든 글은 화면 낭독에서 원래 글을 읽는다
      expect((result.children!.first as TextSpan).semanticsLabel, '지갑');
    });
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
