import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_activity.dart';

String formatSats(BitcoinUnit unit, int sats) =>
    unit.displayBitcoinAmount(sats, withUnit: true, shouldCheckZero: true, defaultWhenZero: '0 ${unit.symbol}');

String arkRailText(ArkRail rail) => switch (rail) {
  ArkRail.onchain => t.ark.rail.onchain,
  ArkRail.ark => t.ark.rail.ark,
  ArkRail.lightning => t.ark.rail.lightning,
};

String? arkActivityLabelText(ArkActivityLabel? label) {
  final texts = t.ark.activity;
  return switch (label) {
    null => null,
    ArkActivityLabel.refresh => texts.refresh,
    ArkActivityLabel.movedToArk => texts.moved_to_ark,
    ArkActivityLabel.movedOnchain => texts.moved_onchain,
    ArkActivityLabel.exit => texts.exit,
    ArkActivityLabel.failed => texts.failed,
    ArkActivityLabel.canceled => texts.canceled,
  };
}
