import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/text_utils.dart';

/// 한국어 문장이 단어 중간에서 줄바꿈되지 않게 한다(띄어쓰기에서만 줄을 바꾼다).
/// 띄어쓰기가 없는 일본어 문장까지 한 단어로 묶이지 않도록 한국어일 때만 적용한다.
///
/// 보이는 글에만 쓴다. 단어 잇기 문자(U+2060)가 들어가므로 [Text]에는 원문을 `semanticsLabel`로 함께 넘긴다
/// (앱의 `coconut_overlays.dart`와 같은 방식). 저장·비교·알림 본문에는 원문을 쓴다.
String keepWords(String text) =>
    LocaleSettings.currentLocale == AppLocale.ko ? TextUtils.preventLineBreakInsideWords(text) : text;
