import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailStickyHeader extends StatefulWidget {
  final Key widgetKey;
  final double height;
  final bool isVisible;
  final BitcoinUnit currentUnit;
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
  State<WalletDetailStickyHeader> createState() => _WalletDetailStickyHeaderState();
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
                color: CoconutColors.black,
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
                          AnimatedBalance(
                            prevValue: widget.animatedBalanceData.previous,
                            value: widget.animatedBalanceData.current,
                            currentUnit: widget.currentUnit,
                            textStyle: CoconutTypography.body1_16_NumberBold.merge(
                              const TextStyle(
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Text(
                            ' ${widget.currentUnit.symbol}',
                            style: CoconutTypography.body2_14_Number,
                          ),
                        ],
                      ),
                    ),
                    Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                            width: MediaQuery.of(context).size.width / 3,
                            child: _buildButtonRow())),
                  ],
                ),
              ),
              Stack(
                children: [
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.sizeOf(context).width,
                        padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 9),
                        decoration: const BoxDecoration(
                          color: CoconutColors.black,
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
                      const SizedBox(height: 16),
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

  Widget _buildButtonRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: t.receive,
            onPressed: widget.onTapReceive,
            backgroundColor: CoconutColors.white,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            label: t.send,
            onPressed: widget.onTapSend,
            backgroundColor: CoconutColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return CupertinoButton(
      minSize: 32,
      onPressed: onPressed,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        overflow: TextOverflow.fade,
        softWrap: false,
        maxLines: 1,
        style: CoconutTypography.body3_12.merge(
          const TextStyle(
            color: CoconutColors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
