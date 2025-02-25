import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class UtxoListHeader extends StatelessWidget {
  final GlobalKey dropdownGlobalKey;
  final int? balance;
  final int? btcPriceInKrw;
  final String selectedFilter;
  final Function onTapDropdown;

  const UtxoListHeader({
    super.key,
    required this.dropdownGlobalKey,
    required this.balance,
    required this.btcPriceInKrw,
    required this.selectedFilter,
    required this.onTapDropdown,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UtxoListViewModel>(
      builder: (context, viewModel, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.only(
                  left: 35,
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
                    CoconutLayout.spacing_200h,
                    IntrinsicWidth(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              balance != null
                                  ? satoshiToBitcoinString(balance!)
                                  : "잔액 조회 불가",
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
                    CoconutLayout.spacing_100h,
                    if (balance != null && btcPriceInKrw != null)
                      Text(
                          '₩ ${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(balance!, btcPriceInKrw!).toDouble())}',
                          style: Styles.subLabel.merge(TextStyle(
                              fontFamily: CustomFonts.number.getFontFamily,
                              color: MyColors.transparentWhite_70))),
                    CoconutLayout.spacing_400h,
                    Row(
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
                  ],
                ),
              ),
              Visibility(
                visible: !viewModel.isUtxoTagListEmpty,
                child: CustomTagHorizontalSelector(
                  tags: viewModel.utxoTagList.map((e) => e.name).toList(),
                  selectedName: viewModel.selectedUtxoTagName,
                  onSelectedTag: (tagName) {
                    viewModel.setSelectedUtxoTagName(tagName);
                  },
                ),
              ),
              CoconutLayout.spacing_400h,
            ],
          )
        ],
      ),
    );
  }
}
