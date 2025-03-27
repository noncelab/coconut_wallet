import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class UtxoListHeader extends StatefulWidget {
  final GlobalKey dropdownGlobalKey;
  final int? balance;
  final String selectedFilter;
  final Function onTapDropdown;
  final List<UtxoTag> utxoTagList;
  final String selectedUtxoTagName;
  final Function(String) onTagSelected;

  const UtxoListHeader(
      {super.key,
      required this.dropdownGlobalKey,
      required this.balance,
      required this.selectedFilter,
      required this.onTapDropdown,
      required this.utxoTagList,
      required this.selectedUtxoTagName,
      required this.onTagSelected});

  @override
  State<UtxoListHeader> createState() => _UtxoListHeaderState();
}

class _UtxoListHeaderState extends State<UtxoListHeader> {
  @override
  Widget build(BuildContext context) {
    return Column(
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
                  IntrinsicWidth(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.balance != null
                                ? satoshiToBitcoinString(widget.balance!)
                                : t.fetch_balance_failed,
                            style: CoconutTypography.heading1_32_NumberBold,
                          ),
                        ),
                        CoconutLayout.spacing_100w,
                        Text(
                          t.btc,
                          style: CoconutTypography.heading3_21_Number,
                        ),
                      ],
                    ),
                  ),
                  CoconutLayout.spacing_50h,
                  if (widget.balance != null)
                    Consumer<UpbitConnectModel>(
                        builder: (context, viewModel, child) => Text(
                            viewModel.getFiatPrice(
                                widget.balance!, CurrencyCode.KRW),
                            style: CoconutTypography.body2_14_Number
                                .setColor(CoconutColors.gray500))),
                  CoconutLayout.spacing_400h,
                  Row(
                    children: [
                      Expanded(
                        child: Container(),
                      ),
                      CupertinoButton(
                        key: widget.dropdownGlobalKey,
                        padding: const EdgeInsets.only(
                            top: 7, bottom: 7, left: 8, right: 26),
                        minSize: 0,
                        onPressed: () {
                          widget.onTapDropdown();
                        },
                        child: Row(
                          children: [
                            Text(widget.selectedFilter,
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
                ],
              ),
            ),
            Consumer<UtxoListViewModel>(builder: (context, viewModel, child) {
              return Visibility(
                visible: viewModel.utxoTagList.isNotEmpty,
                child: CustomTagHorizontalSelector(
                  tags: viewModel.utxoTagList.map((e) => e.name).toList(),
                  selectedName: viewModel.selectedUtxoTagName,
                  onSelectedTag: widget.onTagSelected,
                ),
              );
            }),
            CoconutLayout.spacing_300h,
          ],
        )
      ],
    );
  }
}
