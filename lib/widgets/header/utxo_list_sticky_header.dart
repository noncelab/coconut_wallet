import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class UtxoListStickyHeader extends StatelessWidget {
  final Key widgetKey;
  final double height;
  final bool isVisible;
  final int? balance;
  final int? totalCount;
  final String selectedFilter;
  final Function onTapDropdown;
  final Function removePopup;
  const UtxoListStickyHeader({
    required this.widgetKey,
    required this.height,
    required this.isVisible,
    required this.balance,
    required this.totalCount,
    required this.selectedFilter,
    required this.onTapDropdown,
    required this.removePopup,
  }) : super(key: widgetKey);

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
                          children: [
                            Text.rich(
                              TextSpan(
                                text: balance != null
                                    ? satoshiToBitcoinString(balance!)
                                    : t.fetch_balance_failed,
                                style: CoconutTypography.heading4_18_NumberBold,
                                children: [
                                  TextSpan(
                                    text: balance != null
                                        ? ' ${t.btc}'
                                        : t.fetch_balance_failed,
                                    style: CoconutTypography.body2_14_Number,
                                  ),
                                ],
                              ),
                            ),
                            CoconutLayout.spacing_200w,
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
                              padding: const EdgeInsets.only(
                                  top: 7, bottom: 7, left: 8, right: 26),
                              minSize: 0,
                              onPressed: () {
                                onTapDropdown();
                              },
                              child: Row(
                                children: [
                                  Text(selectedFilter,
                                      style: CoconutTypography.caption_10
                                          .setColor(CoconutColors.white)),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  SvgPicture.asset(
                                    'assets/svg/arrow-down.svg',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      CoconutLayout.spacing_200h,
                      Visibility(
                        visible: !viewModel.isUtxoTagListEmpty,
                        child: Container(
                          margin: const EdgeInsets.only(left: 16, bottom: 12),
                          child: CustomTagHorizontalSelector(
                            tags: viewModel.utxoTagList
                                .map((e) => e.name)
                                .toList(),
                            onSelectedTag: (tagName) {
                              viewModel.setSelectedUtxoTagName(tagName);
                            },
                          ),
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
