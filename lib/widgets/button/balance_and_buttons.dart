import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/overlays/receive_address_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';

class BalanceAndButtons extends StatefulWidget {
  final int walletId;
  final String address;
  final String derivationPath;
  final int? balance;
  final Unit currentUnit;
  final int? btcPriceInKrw;
  final bool Function()? checkPrerequisites;

  const BalanceAndButtons({
    super.key,
    required this.walletId,
    required this.address,
    required this.derivationPath,
    required this.balance,
    required this.currentUnit,
    required this.btcPriceInKrw,
    this.checkPrerequisites,
  });

  @override
  State<BalanceAndButtons> createState() => _BalanceAndButtonsState();
}

class _BalanceAndButtonsState extends State<BalanceAndButtons> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Text(
              widget.balance != null
                  ? (widget.currentUnit == Unit.btc
                      ? satoshiToBitcoinString(widget.balance!)
                      : addCommasToIntegerPart(widget.balance!.toDouble()))
                  : "잔액 조회 불가",
              style: Styles.h1Number
                  .merge(const TextStyle(color: MyColors.white))),
          if (widget.balance != null && widget.btcPriceInKrw != null)
            Text(
                '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(widget.balance!, widget.btcPriceInKrw!).toDouble())} ${CurrencyCode.KRW.code}',
                style: Styles.subLabel.merge(TextStyle(
                    fontFamily: CustomFonts.number.getFontFamily,
                    color: MyColors.transparentWhite_70))),
          const SizedBox(height: 24.0),
          Row(
            children: [
              Expanded(
                  child: CupertinoButton(
                      onPressed: () {
                        if (widget.checkPrerequisites != null) {
                          if (!widget.checkPrerequisites!()) return;
                        }
                        // TODO: ReceiveAddressScreen에 widget.walletId 말고 다른 매개변수 고려해보기
                        CommonBottomSheets.showBottomSheet_90(
                          context: context,
                          child: ReceiveAddressBottomSheet(
                            id: widget.walletId,
                            address: widget.address,
                            derivationPath: widget.derivationPath,
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
                        if (widget.balance == null) {
                          CustomToast.showToast(
                              context: context, text: "잔액이 없습니다.");
                          return;
                        }
                        if (widget.checkPrerequisites != null) {
                          if (!widget.checkPrerequisites!()) return;
                        }
                        Navigator.pushNamed(context, '/send-address',
                            arguments: {'id': widget.walletId});
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
