import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/bitcoin_amount_unit.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailStickyHeader extends StatefulWidget {
  final Key widgetKey;
  final double height;
  final bool isVisible;
  final BitcoinUnit currentUnit;
  final AnimatedBalanceData animatedBalanceData;
  final String fiatPrice;

  const WalletDetailStickyHeader({
    required this.widgetKey,
    required this.height,
    required this.isVisible,
    required this.currentUnit,
    required this.animatedBalanceData,
    required this.fiatPrice,
  }) : super(key: widgetKey);

  @override
  State<WalletDetailStickyHeader> createState() => _WalletDetailStickyHeaderState();
}

class _WalletDetailStickyHeaderState extends State<WalletDetailStickyHeader> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.height.floorToDouble(),
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
                padding: const EdgeInsets.only(left: 16.0, right: 16, top: 0),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.fiatPrice.isNotEmpty)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          widget.fiatPrice,
                          style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500),
                        ),
                      ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: BitcoinAmountUnit(
                        currentUnit: widget.currentUnit,
                        unitStyle: CoconutTypography.body2_14_Number,
                        child: AnimatedBalance(
                          prevValue: widget.animatedBalanceData.previous,
                          value: widget.animatedBalanceData.current,
                          currentUnit: widget.currentUnit,
                          textStyle: CoconutTypography.body1_16_NumberBold.merge(const TextStyle(fontSize: 18)),
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
                        padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 9),
                        decoration: const BoxDecoration(
                          color: CoconutColors.black,
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(255, 255, 255, 0.12),
                              offset: Offset(0, 5),
                              blurRadius: 12,
                              spreadRadius: -2,
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
}
