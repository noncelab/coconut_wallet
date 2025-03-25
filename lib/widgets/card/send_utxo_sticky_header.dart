import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/send/send_utxo_selection_view_model.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SendUtxoStickyHeader extends StatelessWidget {
  final ErrorState? errorState;
  final RecommendedFeeFetchStatus recommendedFeeFetchStatus;
  final TransactionFeeLevel? selectedLevel;
  final VoidCallback onTapFeeButton;
  final bool isMaxMode;
  final bool customFeeSelected;
  final int sendAmount;
  final int? estimatedFee;
  final int? satsPerVb;
  final int? change;

  const SendUtxoStickyHeader({
    super.key,
    required this.errorState,
    required this.recommendedFeeFetchStatus,
    this.selectedLevel = TransactionFeeLevel.halfhour,
    required this.onTapFeeButton,
    required this.isMaxMode,
    required this.customFeeSelected,
    required this.sendAmount,
    required this.estimatedFee,
    required this.satsPerVb,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAmountRow(context),
        _divider(),
        _buildFeeRow(),
        _divider(),
        _buildChangeRow(),
      ],
    );
    // return Column(
    //   children: [
    //     Row(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         Text(
    //           t.send_amount,
    //           style: CoconutTypography.body2_14_Bold,
    //         ),
    //         Expanded(
    //           child: Row(
    //             mainAxisAlignment: MainAxisAlignment.end,
    //             children: [
    //               Visibility(
    //                 visible: isMaxMode,
    //                 child: Container(
    //                   padding: const EdgeInsets.only(bottom: 2),
    //                   margin: const EdgeInsets.only(right: 4, bottom: 16),
    //                   height: 24,
    //                   width: 34,
    //                   decoration: BoxDecoration(
    //                     color: CoconutColors.gray700,
    //                     borderRadius: BorderRadius.circular(16),
    //                   ),
    //                   child: Center(
    //                     child: Text(t.max, style: CoconutTypography.caption_10),
    //                   ),
    //                 ),
    //               ),
    //               Column(
    //                 crossAxisAlignment: CrossAxisAlignment.end,
    //                 children: [
    //                   Text(
    //                     '${satoshiToBitcoinString(sendAmount).normalizeToFullCharacters()} BTC',
    //                     style: CoconutTypography.body2_14_Number,
    //                   ),
    //                   Consumer<UpbitConnectModel>(
    //                       builder: (context, viewModel, child) {
    //                     return Text(
    //                         viewModel.getFiatPrice(
    //                             sendAmount, CurrencyCode.KRW),
    //                         style: CoconutTypography.body3_12_Number
    //                             .setColor(CoconutColors.gray400));
    //                   }),
    //                 ],
    //               ),
    //             ],
    //           ),
    //         ),
    //       ],
    //     ),
    //     divider(
    //         padding: const EdgeInsets.only(
    //       top: 12,
    //       bottom: 16,
    //     )),
    //     Row(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         Row(
    //           crossAxisAlignment: CrossAxisAlignment.start,
    //           children: [
    //             Text(t.fee, style: CoconutTypography.body2_14_Bold),
    //             CustomUnderlinedButton(
    //               text: t.modify,
    //               padding: const EdgeInsets.only(
    //                 left: 8,
    //                 top: 4,
    //                 bottom: 8,
    //                 right: 8,
    //               ),
    //               isEnable: recommendedFeeFetchStatus !=
    //                   RecommendedFeeFetchStatus.fetching,
    //               onTap: () {
    //                 onTapFeeButton();
    //               },
    //             ),
    //           ],
    //         ),
    //         Expanded(
    //             child: recommendedFeeFetchStatus ==
    //                         RecommendedFeeFetchStatus.failed &&
    //                     !customFeeSelected
    //                 ? Row(
    //                     mainAxisAlignment: MainAxisAlignment.end,
    //                     children: [
    //                       Text(
    //                         '- ',
    //                         style: Styles.body2Bold.merge(const TextStyle(
    //                             color: MyColors.transparentWhite_40)),
    //                       ),
    //                       Text(
    //                         'BTC',
    //                         style: Styles.body2Number.merge(
    //                           const TextStyle(
    //                             color: MyColors.transparentWhite_40,
    //                           ),
    //                         ),
    //                       ),
    //                     ],
    //                   )
    //                 : recommendedFeeFetchStatus ==
    //                             RecommendedFeeFetchStatus.succeed ||
    //                         customFeeSelected
    //                     ? Column(
    //                         crossAxisAlignment: CrossAxisAlignment.end,
    //                         children: [
    //                           Text(
    //                             estimatedFee != null
    //                                 ? '${satoshiToBitcoinString(estimatedFee!).toString()} BTC'
    //                                 : '0 BTC',
    //                             style: Styles.body2Number,
    //                           ),
    //                           if (satsPerVb != null) ...{
    //                             Text(
    //                               '${selectedLevel?.expectedTime ?? ''} ($satsPerVb sats/vb)',
    //                               style: Styles.caption,
    //                             ),
    //                           },
    //                         ],
    //                       )
    //                     : const Row(
    //                         mainAxisAlignment: MainAxisAlignment.end,
    //                         children: [
    //                           SizedBox(
    //                             width: 15,
    //                             height: 15,
    //                             child: CircularProgressIndicator(
    //                               color: MyColors.white,
    //                               strokeWidth: 2,
    //                             ),
    //                           ),
    //                         ],
    //                       )),
    //       ],
    //     ),
    //     divider(
    //       padding: const EdgeInsets.only(
    //         top: 10,
    //         bottom: 16,
    //       ),
    //     ),
    //     Row(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         Text(
    //           t.change,
    //           style: change != null
    //               ? (change! >= 0
    //                   ? CoconutTypography.body2_14_Bold
    //                   : CoconutTypography.body2_14_Bold
    //                       .setColor(CoconutColors.hotPink))
    //               : CoconutTypography.body2_14_Bold
    //                   .setColor(CoconutColors.gray500),
    //         ),
    //         Expanded(
    //           child: Column(
    //             crossAxisAlignment: CrossAxisAlignment.end,
    //             children: [
    //               Text(
    //                 change != null
    //                     ? '${satoshiToBitcoinString(change!)} BTC'
    //                     : '- BTC',
    //                 style: change != null
    //                     ? (change! >= 0
    //                         ? CoconutTypography.body2_14_Number
    //                         : CoconutTypography.body2_14_Number
    //                             .setColor(CoconutColors.hotPink))
    //                     : CoconutTypography.body2_14_Number
    //                         .setColor(CoconutColors.gray500),
    //               ),
    //             ],
    //           ),
    //         ),
    //       ],
    //     ),
    //   ],
    // );
  }

  Widget _buildAmountRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.send_amount, style: CoconutTypography.body2_14_Bold),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isMaxMode) _buildMaxBadge(),
              _buildAmountText(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaxBadge() {
    return Container(
      padding: const EdgeInsets.only(bottom: 2),
      margin: const EdgeInsets.only(right: 4, bottom: 16),
      height: 24,
      width: 34,
      decoration: BoxDecoration(
        color: CoconutColors.gray700,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(t.max, style: CoconutTypography.caption_10),
      ),
    );
  }

  Widget _buildAmountText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
            '${satoshiToBitcoinString(sendAmount).normalizeToFullCharacters()} BTC',
            style: CoconutTypography.body2_14_Number),
        Consumer<UpbitConnectModel>(
          builder: (context, viewModel, child) {
            return Text(
              viewModel.getFiatPrice(sendAmount, CurrencyCode.KRW),
              style: CoconutTypography.body3_12_Number
                  .setColor(CoconutColors.gray400),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.fee, style: CoconutTypography.body2_14_Bold),
            _buildModifyButton(),
          ],
        ),
        Expanded(child: _buildFeeInfo()),
      ],
    );
  }

  Widget _buildModifyButton() {
    return CustomUnderlinedButton(
      text: t.modify,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      isEnable: recommendedFeeFetchStatus != RecommendedFeeFetchStatus.fetching,
      onTap: onTapFeeButton,
    );
  }

  Widget _buildFeeInfo() {
    if (recommendedFeeFetchStatus == RecommendedFeeFetchStatus.failed &&
        !customFeeSelected) {
      return _buildPlaceholderFee();
    } else if (recommendedFeeFetchStatus == RecommendedFeeFetchStatus.succeed ||
        customFeeSelected) {
      return _buildEstimatedFee();
    } else {
      return _buildLoadingIndicator();
    }
  }

  Widget _buildEstimatedFee() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          estimatedFee != null
              ? '${satoshiToBitcoinString(estimatedFee!)} BTC'
              : '0 BTC',
          style: CoconutTypography.body2_14_Number,
        ),
        if (satsPerVb != null)
          Text(
              '${selectedLevel?.expectedTime ?? ''} ($satsPerVb ${satsPerVb == 1 ? 'sat' : 'sats'}/vb)',
              style: CoconutTypography.body3_12_Number
                  .setColor(CoconutColors.gray400)),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            color: CoconutColors.white,
            strokeWidth: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderFee() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('- BTC',
            style: CoconutTypography.body2_14_Number
                .setColor(CoconutColors.gray400)),
      ],
    );
  }

  Widget _buildChangeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.change,
          style: CoconutTypography.body2_14_Bold.setColor(
            change != null
                ? (change! >= 0 ? CoconutColors.white : CoconutColors.hotPink)
                : CoconutColors.gray400,
          ),
        ),
        Expanded(
          child: Text(
            change != null ? '${satoshiToBitcoinString(change!)} BTC' : '- BTC',
            textAlign: TextAlign.end,
            style: CoconutTypography.body2_14_Number.setColor(
              change != null
                  ? (change! >= 0 ? CoconutColors.white : CoconutColors.hotPink)
                  : CoconutColors.gray400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider(
          {EdgeInsets padding = const EdgeInsets.symmetric(vertical: 12)}) =>
      Container(
        padding: padding,
        child: const Divider(
          height: 1,
          color: CoconutColors.gray700,
        ),
      );
}
