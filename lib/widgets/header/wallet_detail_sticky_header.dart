import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailStickyHeader extends StatefulWidget {
  final Key widgetKey;
  final double height;
  final bool isVisible;
  final Unit currentUnit;
  final AnimatedBalanceData animatedBalanceData;
  final Function() onTapReceive;
  final Function() onTapSend;

  const WalletDetailStickyHeader({
    required this.widgetKey,
    required this.height,
    required this.isVisible,
    required this.currentUnit,
    required this.animatedBalanceData,
    required this.onTapReceive,
    required this.onTapSend,
  }) : super(key: widgetKey);

  @override
  State<WalletDetailStickyHeader> createState() =>
      _WalletDetailStickyHeaderState();
}

class _WalletDetailStickyHeaderState extends State<WalletDetailStickyHeader> {
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
                      child: Row(
                        children: [
                          if (widget.animatedBalanceData.current == null)
                            Text(
                              '-',
                              style: CoconutTypography.heading1_32_NumberBold,
                            )
                          else
                            AnimatedBalance(
                              prevValue:
                                  widget.animatedBalanceData.previous ?? 0,
                              value: widget.animatedBalanceData.current!,
                              isBtcUnit: widget.currentUnit == Unit.btc,
                              textStyle:
                                  CoconutTypography.body1_16_NumberBold.merge(
                                const TextStyle(
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          Text(
                            widget.animatedBalanceData.current != null
                                ? widget.currentUnit == Unit.btc
                                    ? ' ${t.btc}'
                                    : ' ${t.sats}'
                                : '',
                            style: CoconutTypography.body2_14_Number,
                          ),
                        ],
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
