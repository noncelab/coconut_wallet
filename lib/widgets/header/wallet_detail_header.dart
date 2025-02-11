import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/button/small_action_button.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_receive_address_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailHeader extends StatelessWidget {
  final int walletId;
  final String address;
  final String derivationPath;
  final int? balance;
  final Unit currentUnit;
  final int? btcPriceInKrw;
  final Function onPressedUnitToggle;
  final Function removePopup;
  final bool Function()? checkPrerequisites;

  const WalletDetailHeader({
    super.key,
    required this.walletId,
    required this.address,
    required this.derivationPath,
    required this.balance,
    required this.currentUnit,
    required this.btcPriceInKrw,
    required this.onPressedUnitToggle,
    required this.removePopup,
    this.checkPrerequisites,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 12),
            child: SmallActionButton(
              onPressed: () {
                onPressedUnitToggle();
                removePopup();
              },
              height: 32,
              width: 64,
              child: Text(
                currentUnit == Unit.btc ? 'BTC' : 'sats',
                style: Styles.label.merge(
                  TextStyle(
                      fontFamily: CustomFonts.number.getFontFamily,
                      color: MyColors.white),
                ),
              ),
            ),
          ),
          Text(
              balance != null
                  ? (currentUnit == Unit.btc
                      ? satoshiToBitcoinString(balance!)
                      : addCommasToIntegerPart(balance!.toDouble()))
                  : "잔액 조회 불가",
              style: Styles.h1Number
                  .merge(const TextStyle(color: MyColors.white))),
          if (balance != null && btcPriceInKrw != null)
            Text(
                '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(balance!, btcPriceInKrw!).toDouble())} ${CurrencyCode.KRW.code}',
                style: Styles.subLabel.merge(TextStyle(
                    fontFamily: CustomFonts.number.getFontFamily,
                    color: MyColors.transparentWhite_70))),
          const SizedBox(height: 24.0),
          Row(
            children: [
              Expanded(
                  child: CupertinoButton(
                      onPressed: () {
                        removePopup();
                        if (checkPrerequisites != null) {
                          if (!checkPrerequisites!()) return;
                        }

                        CommonBottomSheets.showBottomSheet_90(
                          context: context,
                          child: ReceiveAddressBottomSheet(
                            id: walletId,
                            address: address,
                            derivationPath: derivationPath,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      padding: EdgeInsets.zero,
                      color: MyColors.white,
                      child: Text('받기',
                          style: Styles.label.merge(const TextStyle(
                              color: MyColors.black,
                              fontWeight: FontWeight.w600))))),
              const SizedBox(width: 12.0),
              Expanded(
                  child: CupertinoButton(
                      onPressed: () {
                        removePopup();
                        if (balance == null) {
                          CustomToast.showToast(
                              context: context, text: "잔액이 없습니다.");
                          return;
                        }
                        if (checkPrerequisites != null) {
                          if (!checkPrerequisites!()) return;
                        }
                        Navigator.pushNamed(context, '/send-address',
                            arguments: {'id': walletId});
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      padding: EdgeInsets.zero,
                      color: MyColors.primary,
                      child: Text('보내기',
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
