import 'package:coconut_wallet/localization/strings.g.dart';

/// 남은 블록 수를 시간으로, 블록 하나 10분
String arkExpiryText(int? blocksLeft) {
  if (blocksLeft == null) return '-';
  if (blocksLeft <= 0) return t.ark_wallet.expiry_expired;
  if (blocksLeft < 6) return t.ark_wallet.expiry_within_hour;
  if (blocksLeft < 144) return t.ark_wallet.expiry_hours(n: blocksLeft ~/ 6);
  return t.ark_wallet.expiry_days(n: blocksLeft ~/ 144);
}

/// 블록 수를 대략의 기간으로, 블록 하나 10분
String arkDurationText(int blocks) {
  if (blocks < 6) return t.ark_wallet.duration_under_hour;
  if (blocks < 144) return t.ark_wallet.duration_hours(n: blocks ~/ 6);
  return t.ark_wallet.duration_days(n: blocks ~/ 144);
}

/// 블록 높이에 세 자리마다 쉼표
String arkBlockText(int height) => height.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
