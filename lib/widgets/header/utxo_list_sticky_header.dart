import 'package:coconut_design_system/coconut_design_system.dart';
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
  final AnimatedBalanceData animatedBalanceData;
  final int? totalCount;
  final String selectedFilter;
  final Function onTapDropdown;
  final Function removePopup;
  const UtxoListStickyHeader({
    super.key,
    required this.dropdownGlobalKey,
    required this.height,
    required this.isVisible,
    required this.animatedBalanceData,
    required this.totalCount,
    required this.selectedFilter,
    required this.onTapDropdown,
    required this.removePopup,
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
                            if (animatedBalanceData.current == null)
                              Text(
                                t.fetch_balance_failed,
                                style: CoconutTypography.heading4_18_NumberBold,
                              )
                            else
                              AnimatedBalance(
                                prevValue: animatedBalanceData.previous ?? 0,
                                value: animatedBalanceData.current!,
                                isBtcUnit: true,
                                textStyle:
                                    CoconutTypography.heading4_18_NumberBold,
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
                      Visibility(
                        visible: totalCount != 0,
                        maintainAnimation: true,
                        maintainState: true,
                        maintainSize: true,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(),
                            ),
                            CupertinoButton(
                              key: dropdownGlobalKey,
                              padding: const EdgeInsets.only(
                                  top: 7, bottom: 7, left: 8, right: 26),
                              minSize: 0,
                              onPressed: () {
                                onTapDropdown();
                              },
                              child: Row(
                                children: [
                                  Text(selectedFilter,
                                      style: CoconutTypography.body3_12
                                          .setColor(CoconutColors.white)),
                                  CoconutLayout.spacing_200w,
                                  SvgPicture.asset(
                                    'assets/svg/arrow-down.svg',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      CoconutLayout.spacing_50h,
                      Visibility(
                        visible: !viewModel.isUtxoTagListEmpty,
                        child: CustomTagHorizontalSelector(
                          tags:
                              viewModel.utxoTagList.map((e) => e.name).toList(),
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
