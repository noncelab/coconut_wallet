import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailHeader extends StatelessWidget {
  final int? balance;
  final Unit currentUnit;
  final int? btcPriceInKrw;
  final void Function() onPressedUnitToggle;
  final void Function() onTapReceive;
  final void Function() onTapSend;

  const WalletDetailHeader({
    super.key,
    required this.balance,
    required this.currentUnit,
    required this.btcPriceInKrw,
    required this.onPressedUnitToggle,
    required this.onTapReceive,
    required this.onTapSend,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            GestureDetector(
                onTap: () {
                  if (balance != null) onPressedUnitToggle();
                },
                child: Column(
                  children: [
                    SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              balance == null
                                  ? '-'
                                  : currentUnit == Unit.btc
                                      ? satoshiToBitcoinString(balance!)
                                      : addCommasToIntegerPart(
                                          balance!.toDouble()),
                              style: Styles.h1Number.merge(
                                  const TextStyle(color: MyColors.white)),
                            ),
                            const SizedBox(width: 4.0),
                            Text(currentUnit == Unit.btc ? t.btc : t.sats,
                                style: Styles.unit),
                          ],
                        )),
                    SizedBox(
                        height: 24,
                        child: Text(
                            balance != null && btcPriceInKrw != null
                                ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(balance!, btcPriceInKrw!).toDouble())} ${CurrencyCode.KRW.code}'
                                : '-',
                            style: Styles.subLabel.merge(TextStyle(
                                fontFamily: CustomFonts.number.getFontFamily,
                                color: MyColors.transparentWhite_70))))
                  ],
                )),
            const SizedBox(height: 24.0),
            Row(
              children: [
                Expanded(
                    child: CupertinoButton(
                        onPressed: onTapReceive,
                        borderRadius: BorderRadius.circular(12.0),
                        padding: EdgeInsets.zero,
                        color: MyColors.white,
                        child: Text(t.receive,
                            style: Styles.label.merge(const TextStyle(
                                color: MyColors.black,
                                fontWeight: FontWeight.w600))))),
                const SizedBox(width: 12.0),
                Expanded(
                    child: CupertinoButton(
                        onPressed: onTapSend,
                        borderRadius: BorderRadius.circular(12.0),
                        padding: EdgeInsets.zero,
                        color: MyColors.primary,
                        child: Text(t.send,
                            style: Styles.label.merge(const TextStyle(
                                color: MyColors.black,
                                fontWeight: FontWeight.w600))))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
