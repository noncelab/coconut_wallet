import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class UtxoListStickyHeader extends StatelessWidget {
  final GlobalKey dropdownGlobalKey;
  final double height;
  final bool isVisible;
  final bool enableDropdown;
  final AnimatedBalanceData animatedBalanceData;
  final int? totalCount;
  final String selectedOption;
  final Function onTapDropdown;
  final Function removePopup;
  final BitcoinUnit currentUnit;
  const UtxoListStickyHeader({
    super.key,
    required this.dropdownGlobalKey,
    required this.height,
    required this.isVisible,
    required this.enableDropdown,
    required this.animatedBalanceData,
    required this.totalCount,
    required this.selectedOption,
    required this.onTapDropdown,
    required this.removePopup,
    required this.currentUnit,
  });

  @override
  Widget build(BuildContext context) {
    int totalCount = this.totalCount ?? 0;
    return Consumer<UtxoListViewModel>(
      builder: (context, viewModel, child) => Positioned(
        top: height,
        left: 0,
        right: 0,
        child: IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Stack(
              children: [
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: 10,
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
                ),
                Container(
                  color: CoconutColors.black,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(
                          left: 20.0,
                          right: 16,
                          top: 20.0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AnimatedBalance(
                              prevValue: animatedBalanceData.previous,
                              value: animatedBalanceData.current,
                              isBtcUnit: currentUnit == BitcoinUnit.btc,
                              textStyle: CoconutTypography.heading4_18_NumberBold,
                            ),
                            CoconutLayout.spacing_100w,
                            Text(
                              t.btc,
                              style: CoconutTypography.body2_14_Number,
                            ),
                            CoconutLayout.spacing_100w,
                            Text(
                              t.total_utxo_count(count: totalCount),
                              style: CoconutTypography.body3_12.setColor(
                                CoconutColors.gray400,
                              ),
                            )
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Container(),
                          ),
                          CupertinoButton(
                            key: dropdownGlobalKey,
                            padding: const EdgeInsets.only(top: 7, bottom: 7, left: 8, right: 26),
                            minSize: 0,
                            onPressed: () {
                              if (!enableDropdown) return;
                              onTapDropdown();
                            },
                            child: Row(
                              children: [
                                Text(selectedOption,
                                    style: CoconutTypography.body3_12.setColor(enableDropdown
                                        ? CoconutColors.white
                                        : CoconutColors.gray700)),
                                CoconutLayout.spacing_200w,
                                SvgPicture.asset(
                                  'assets/svg/arrow-down.svg',
                                  colorFilter: enableDropdown
                                      ? null
                                      : const ColorFilter.mode(
                                          CoconutColors.gray700, BlendMode.srcIn),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      CoconutLayout.spacing_50h,
                      Visibility(
                        visible: !viewModel.isUtxoTagListEmpty,
                        child: CustomTagHorizontalSelector(
                          tags: viewModel.utxoTagList.map((e) => e.name).toList(),
                          selectedName: viewModel.selectedUtxoTagName,
                          onSelectedTag: (tagName) {
                            viewModel.setSelectedUtxoTagName(tagName);
                          },
                          scrollPhysics: const AlwaysScrollableScrollPhysics(),
                        ),
                      ),
                      CoconutLayout.spacing_300h,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
