import 'package:coconut_wallet/localization/strings.g.dart';

/// 남은 블록 수를 시간으로, 블록 하나 10분
String arkExpiryText(int? blocksLeft) {
  if (blocksLeft == null) return '-';
  if (blocksLeft <= 0) return t.ark_wallet.expiry_expired;
  if (blocksLeft < 6) return t.ark_wallet.expiry_within_hour;
  if (blocksLeft < 144) return t.ark_wallet.expiry_hours(n: blocksLeft ~/ 6);
  final days = blocksLeft ~/ 144;
  return days == 1 ? t.ark_wallet.expiry_one_day : t.ark_wallet.expiry_days(n: days);
}

/// 블록 수를 대략의 기간으로, 블록 하나 10분
String arkDurationText(int blocks) {
  if (blocks < 6) return t.ark_wallet.duration_under_hour;
  if (blocks < 144) return t.ark_wallet.duration_hours(n: blocks ~/ 6);
  final days = blocks ~/ 144;
  return days == 1 ? t.ark_wallet.duration_one_day : t.ark_wallet.duration_days(n: days);
}

/// 블록 높이에 세 자리마다 쉼표
String arkBlockText(int height) => height.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// 블록 수와 걸리는 시간, 예: 144블록(약 하루). 한 시간이 안 되면 분으로
String arkBlocksText(int blocks) => t.ark_wallet.blocks_with_time(
  n: arkBlockText(blocks),
  time: blocks < 6 ? t.ark_wallet.duration_minutes(n: blocks * 10) : arkDurationText(blocks),
);

/// 지금부터 블록 수만큼 뒤, 예: 144블록(약 하루) 뒤
String arkBlocksLaterText(int blocks) => t.ark_wallet.after_blocks(blocks: arkBlocksText(blocks));
