import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_receive_address_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailHeader extends StatefulWidget {
  final int walletId;
  final String address;
  final String derivationPath;
  final int? balance;
  final int? prevBalance;
  final Unit currentUnit;
  final int? btcPriceInKrw;
  final Function onPressedUnitToggle;
  final bool Function()? checkPrerequisites;

  const WalletDetailHeader({
    super.key,
    required this.walletId,
    required this.address,
    required this.derivationPath,
    required this.balance,
    required this.prevBalance,
    required this.currentUnit,
    required this.btcPriceInKrw,
    required this.onPressedUnitToggle,
    this.checkPrerequisites,
  });

  @override
  State<WalletDetailHeader> createState() => _WalletDetailHeaderState();
}

class _WalletDetailHeaderState extends State<WalletDetailHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _balanceAnimController;
  late Animation<double> _balanceAnimation;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _balanceAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _initializeAnimation();
  }

  void _initializeAnimation() {
    double startBalance = widget.prevBalance?.toDouble() ?? 0.0;
    double endBalance = widget.balance?.toDouble() ?? 0.0;

    _balanceAnimation =
        Tween<double>(begin: startBalance, end: endBalance).animate(
      CurvedAnimation(
          parent: _balanceAnimController, curve: Curves.easeOutCubic),
    )..addListener(() {
            setState(() {
              _currentBalance = _balanceAnimation.value;
            });
          });

    if (startBalance != endBalance) {
      _balanceAnimController.forward(
          from: 0.0); // 애니메이션의 진행도를 처음부터 다시 시작하기 위함(부드럽게)
    } else {
      _currentBalance = endBalance;
    }
  }

  @override
  void didUpdateWidget(covariant WalletDetailHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.balance != oldWidget.balance) {
      _initializeAnimation();
    }
  }

  @override
  void dispose() {
    _balanceAnimController.dispose();
    super.dispose();
  }

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
                  if (widget.balance != null) widget.onPressedUnitToggle();
                },
                child: Column(
                  children: [
                    SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.balance == null
                                  ? '-'
                                  : widget.currentUnit == Unit.btc
                                      ? satoshiToBitcoinString(
                                          _currentBalance.toInt())
                                      : addCommasToIntegerPart(_currentBalance),
                              style: Styles.h1Number.merge(
                                  const TextStyle(color: MyColors.white)),
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                                widget.currentUnit == Unit.btc ? t.btc : t.sats,
                                style: Styles.unit),
                          ],
                        )),
                    SizedBox(
                        height: 24,
                        child: Text(
                            widget.balance != null
                                ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(_currentBalance.toInt(), widget.btcPriceInKrw!).toDouble())} ${CurrencyCode.KRW.code}'
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
                        onPressed: () {
                          if (widget.checkPrerequisites != null) {
                            if (!widget.checkPrerequisites!()) return;
                          }

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
                        child: Text(t.receive,
                            style: Styles.label.merge(const TextStyle(
                                color: MyColors.black,
                                fontWeight: FontWeight.w600))))),
                const SizedBox(width: 12.0),
                Expanded(
                    child: CupertinoButton(
                        onPressed: () {
                          if (widget.balance == null) {
                            CustomToast.showToast(
                                context: context, text: t.toast.no_balance);
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
