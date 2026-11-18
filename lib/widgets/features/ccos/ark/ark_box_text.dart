import 'package:flutter/painting.dart';

/// 상자 안 글자의 첫 줄 위·마지막 줄 아래 줄 간격 여백을 빼, 상자 위쪽 여백이 왼쪽 여백과 같아 보이게
const arkBoxTextHeight = TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false);
