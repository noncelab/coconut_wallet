import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';

class WalletDetailHeader extends StatelessWidget {
  final int? balance;
  final Unit currentUnit;
  final String btcPriceInKrw;
  final int sendingAmount;
  final int receivingAmount;
  final void Function() onPressedUnitToggle;
  final void Function() onTapReceive;
  final void Function() onTapSend;

  const WalletDetailHeader({
    super.key,
    required this.balance,
    required this.currentUnit,
    required this.btcPriceInKrw,
    required this.sendingAmount,
    required this.receivingAmount,
    required this.onPressedUnitToggle,
    required this.onTapReceive,
    required this.onTapSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CoconutLayout.spacing_800h,
          GestureDetector(
              onTap: () {
                if (balance != null) onPressedUnitToggle();
              },
              child: Column(
                children: [
                  SizedBox(
                      height: 20,
                      child: Text(balance != null ? btcPriceInKrw : '-',
                          style: CoconutTypography.body3_12_Number)),
                  SizedBox(
                      height: 36,
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
                            style: CoconutTypography.heading1_32_NumberBold,
                          ),
                          const SizedBox(width: 4.0),
                          Text(currentUnit == Unit.btc ? t.btc : t.sats,
                              style: CoconutTypography.heading4_18_Number
                                  .setColor(CoconutColors.gray350)),
                        ],
                      )),
                  CoconutLayout.spacing_100h,
                  // TODO: 로티 추가
                  SizedBox(
                      height: sendingAmount != 0 ? 20 : 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              color: CoconutColors.primary.withOpacity(0.2),
                            ),
                            child: Lottie.asset('assets/lottie/arrow-up.json',
                                width: 20, height: 20),
                          ),
                          Text(
                              sendingAmount != 0
                                  ? '${satoshiToBitcoinString(sendingAmount)} BTC 보내는 중'
                                  : '',
                              style: CoconutTypography.body2_14_Number),
                        ],
                      )),
                  SizedBox(
                      height: receivingAmount != 0 ? 20 : 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              color: CoconutColors.cyan.withOpacity(0.2),
                            ),
                            child: Lottie.asset('assets/lottie/arrow-down.json',
                                width: 20, height: 20),
                          ),
                          CoconutLayout.spacing_200w,
                          Text(
                              receivingAmount != 0
                                  ? '${satoshiToBitcoinString(receivingAmount)} BTC 받는 중'
                                  : '',
                              style: CoconutTypography.body2_14_Number),
                        ],
                      )),
                  CoconutLayout.spacing_500h,
                ],
              )),
          Row(
            children: [
              Expanded(
                  // TODO: cds 버튼으로 변경
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
    );
  }
}
