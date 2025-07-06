import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class UtxoListHeader extends StatefulWidget {
  final GlobalKey headerGlobalKey;
  final GlobalKey dropdownGlobalKey;
  final AnimatedBalanceData animatedBalanceData;
  final String selectedOption;
  final Function onTapDropdown;
  final bool isLoadComplete;
  final void Function() onPressedUnitToggle;
  final BitcoinUnit currentUnit;
  final Widget tagListWidget;

  const UtxoListHeader({
    super.key,
    required this.headerGlobalKey,
    required this.dropdownGlobalKey,
    required this.animatedBalanceData,
    required this.selectedOption,
    required this.onTapDropdown,
    required this.isLoadComplete,
    required this.currentUnit,
    required this.onPressedUnitToggle,
    required this.tagListWidget,
  });

  @override
  State<UtxoListHeader> createState() => _UtxoListHeaderState();
}

class _UtxoListHeaderState extends State<UtxoListHeader> {
  @override
  Widget build(BuildContext context) {
    return Column(
      key: widget.headerGlobalKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.only(
                left: 20,
                top: 28,
              ),
              width: MediaQuery.sizeOf(context).width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.utxo_list_screen.total_balance,
                    style: CoconutTypography.body1_16_Bold,
                  ),
                  CoconutLayout.spacing_100h,
                  GestureDetector(
                    onTap: widget.onPressedUnitToggle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IntrinsicWidth(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    AnimatedBalance(
                                        prevValue: widget.animatedBalanceData.previous,
                                        value: widget.animatedBalanceData.current,
                                        currentUnit: widget.currentUnit,
                                        textStyle: CoconutTypography.heading1_32_NumberBold),
                                  ],
                                ),
                              ),
                              CoconutLayout.spacing_100w,
                              Text(
                                widget.currentUnit.symbol,
                                style: CoconutTypography.heading3_21_Number,
                              ),
                            ],
                          ),
                        ),
                        CoconutLayout.spacing_50h,
                        FiatPrice(satoshiAmount: widget.animatedBalanceData.current),
                      ],
                    ),
                  ),
                  CoconutLayout.spacing_400h,
                  Row(
                    children: [
                      Expanded(
                        child: Container(),
                      ),
                      Visibility(
                        visible: !widget.isLoadComplete,
                        child: Align(
                          child: Container(
                            margin: const EdgeInsets.only(
                              right: 4,
                            ),
                            width: 12,
                            height: 12,
                            child: const CircularProgressIndicator(
                              color: CoconutColors.gray400,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        key: widget.dropdownGlobalKey,
                        padding: const EdgeInsets.only(top: 7, bottom: 7, left: 8, right: 26),
                        minSize: 0,
                        onPressed: () {
                          if (!widget.isLoadComplete) return;
                          widget.onTapDropdown();
                        },
                        child: Row(
                          children: [
                            Text(widget.selectedOption,
                                style: CoconutTypography.body3_12.setColor(widget.isLoadComplete
                                    ? CoconutColors.white
                                    : CoconutColors.gray700)),
                            CoconutLayout.spacing_200w,
                            SvgPicture.asset(
                              'assets/svg/arrow-down.svg',
                              colorFilter: widget.isLoadComplete
                                  ? null
                                  : const ColorFilter.mode(CoconutColors.gray700, BlendMode.srcIn),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            widget.tagListWidget,
            CoconutLayout.spacing_300h,
          ],
        )
      ],
    );
  }
}
