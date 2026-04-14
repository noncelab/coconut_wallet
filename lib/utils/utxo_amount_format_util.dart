import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

/// 지정 단위에 따라 금액 표시. dust(≤546, 0 제외)는 항상 sats로 표기.
String formatUtxoAmountForDisplay(int sats, BitcoinUnit unit, {required int dustThreshold, bool forceSats = false}) {
  if (sats == 0) {
    return unit.displayBitcoinAmount(sats, withUnit: true);
  }
  if (forceSats || sats <= dustThreshold) {
    return '${sats.toThousandsSeparatedString()} ${t.sats}';
  }
  return unit.displayBitcoinAmount(sats, withUnit: true);
}

/// 차트 툴팁용: 단위 생략, dust만 sats 표기.
String formatUtxoBalanceForTooltip(
  int sats,
  BitcoinUnit unit, {
  required int dustThreshold,
  bool isDustBucket = false,
}) {
  if (isDustBucket || sats <= dustThreshold) {
    return '${sats.toThousandsSeparatedString()} ${t.sats}';
  }
  return unit.displayBitcoinAmount(sats, withUnit: false);
}
