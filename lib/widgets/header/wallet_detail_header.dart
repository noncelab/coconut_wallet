import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';

class WalletDetailHeader extends StatefulWidget {
  final int? balance;
  final int? prevBalance;
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
    required this.prevBalance,
    required this.currentUnit,
    required this.btcPriceInKrw,
    required this.sendingAmount,
    required this.receivingAmount,
    required this.onPressedUnitToggle,
    required this.onTapReceive,
    required this.onTapSend,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CoconutLayout.spacing_800h,
          _buildBalanceInfo(),
          CoconutLayout.spacing_200h,
          _buildPendingAmountStatus(),
          CoconutLayout.spacing_500h,
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo() {
    return GestureDetector(
      onTap: () {
        if (widget.balance != null) widget.onPressedUnitToggle();
      },
      child: Column(
        children: [
          FiatPrice(satoshiAmount: widget.balance ?? 0),
          _buildBtcBalance(),
        ],
      ),
    );
  }

  Widget _buildBtcBalance() {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.balance == null
                ? '-'
                : widget.currentUnit == Unit.btc
                    ? satoshiToBitcoinString(widget.balance!)
                    : addCommasToIntegerPart(widget.balance!.toDouble()),
            style: CoconutTypography.heading1_32_NumberBold,
          ),
          const SizedBox(width: 4.0),
          Text(
            widget.currentUnit == Unit.btc ? t.btc : t.sats,
            style: CoconutTypography.heading4_18_Number
                .setColor(CoconutColors.gray350),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAmountStatus() {
    return Column(
      children: [
        _buildPendingAmountRow(
          widget.sendingAmount != 0,
          'assets/lottie/arrow-up.json',
          widget.sendingAmount != 0
              ? '${t.bitcoin_text(bitcoin: satoshiToBitcoinString(widget.sendingAmount))} ${t.status_sending}'
              : '',
          CoconutColors.primary.withOpacity(0.2),
        ),
        CoconutLayout.spacing_100h,
        _buildPendingAmountRow(
          widget.receivingAmount != 0,
          'assets/lottie/arrow-down.json',
          widget.receivingAmount != 0
              ? '${t.bitcoin_text(bitcoin: satoshiToBitcoinString(widget.receivingAmount))} ${t.status_receiving}'
              : '',
          CoconutColors.cyan.withOpacity(0.2),
        ),
      ],
    );
  }

  Widget _buildPendingAmountRow(
      bool condition, String animationPath, String text, Color color) {
    if (!condition) return const SizedBox.shrink();

    return SizedBox(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: color,
            ),
            child: Lottie.asset(animationPath, width: 12, height: 12),
          ),
          CoconutLayout.spacing_200w,
          Text(
            text,
            style: CoconutTypography.body2_14_Number
                .setColor(CoconutColors.gray200),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildActionButton(widget.onTapReceive, t.receive, CoconutColors.white,
            CoconutColors.black),
        const SizedBox(width: 12.0),
        _buildActionButton(widget.onTapSend, t.send, CoconutColors.primary,
            CoconutColors.black),
      ],
    );
  }

  Widget _buildActionButton(void Function() onTap, String label,
      Color backgroundColor, Color textColor) {
    return Expanded(
      child: CoconutButton(
        onPressed: onTap,
        backgroundColor: backgroundColor,
        buttonType: CoconutButtonType.filled,
        text: label,
        foregroundColor: textColor,
      ),
    );
  }
}
