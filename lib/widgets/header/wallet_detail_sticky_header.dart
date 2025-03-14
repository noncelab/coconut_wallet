import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailStickyHeader extends StatefulWidget {
  final Key widgetKey;
  final double height;
  final bool isVisible;
  final Unit currentUnit;
  final int? balance;
  final int? prevBalance;
  final Function() onTapReceive;
  final Function() onTapSend;

  const WalletDetailStickyHeader({
    required this.widgetKey,
    required this.height,
    required this.isVisible,
    required this.currentUnit,
    required this.balance,
    required this.prevBalance,
    required this.onTapReceive,
    required this.onTapSend,
  }) : super(key: widgetKey);

  @override
  State<WalletDetailStickyHeader> createState() =>
      _WalletDetailStickyHeaderState();
}

class _WalletDetailStickyHeaderState extends State<WalletDetailStickyHeader>
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
  void didUpdateWidget(covariant WalletDetailStickyHeader oldWidget) {
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
    return Positioned(
      top: widget.height,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !widget.isVisible,
        child: AnimatedOpacity(
          opacity: widget.isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            children: [
              Container(
                color: MyColors.black,
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16,
                  top: 20.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: widget.balance != null
                              ? (widget.currentUnit == Unit.btc
                                  ? satoshiToBitcoinString(
                                      _currentBalance.toInt())
                                  : addCommasToIntegerPart(_currentBalance))
                              : '-',
                          style: Styles.h2Number,
                          children: [
                            TextSpan(
                              text: widget.balance != null
                                  ? widget.currentUnit == Unit.btc
                                      ? ' ${t.btc}'
                                      : ' ${t.sats}'
                                  : '',
                              style: Styles.label.merge(
                                TextStyle(
                                  fontFamily: CustomFonts.number.getFontFamily,
                                  color: MyColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: widget.onTapReceive,
                      borderRadius: BorderRadius.circular(8.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minSize: 0,
                      color: MyColors.white,
                      child: SizedBox(
                        width: 35,
                        child: Center(
                          child: Text(
                            t.receive,
                            style: Styles.caption.merge(
                              const TextStyle(
                                  color: MyColors.black,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    CupertinoButton(
                      onPressed: widget.onTapSend,
                      borderRadius: BorderRadius.circular(8.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minSize: 0,
                      color: MyColors.primary,
                      child: SizedBox(
                        width: 35,
                        child: Center(
                          child: Text(
                            '보내기',
                            style: Styles.caption.merge(
                              const TextStyle(
                                  color: MyColors.black,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.sizeOf(context).width,
                        padding: const EdgeInsets.only(
                            top: 10, left: 16, right: 16, bottom: 9),
                        decoration: const BoxDecoration(
                          color: MyColors.black,
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(255, 255, 255, 0.2),
                              offset: Offset(0, 3),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 16,
                        child: Container(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
