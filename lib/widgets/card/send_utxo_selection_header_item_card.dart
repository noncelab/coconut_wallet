import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:flutter/material.dart';

class SendUtxoSelectionHeaderItemCard extends StatelessWidget {
  final ErrorState? errorState;
  final RecommendedFeeFetchStatus recommendedFeeFetchStatus;
  final TransactionFeeLevel? selectedLevel;
  final VoidCallback updateFeeInfoEstimatedFee;
  final VoidCallback onTapFeeButton;
  final bool isMaxMode;
  final bool customFeeSelected;
  final int sendAmount;
  final int? bitcoinPriceKrw;
  final int? estimatedFee;
  final int? satsPerVb;
  final int? change;

  const SendUtxoSelectionHeaderItemCard({
    super.key,
    required this.errorState,
    required this.recommendedFeeFetchStatus,
    this.selectedLevel = TransactionFeeLevel.halfhour,
    required this.updateFeeInfoEstimatedFee,
    required this.onTapFeeButton,
    required this.isMaxMode,
    required this.customFeeSelected,
    required this.sendAmount,
    required this.bitcoinPriceKrw,
    required this.estimatedFee,
    required this.satsPerVb,
    required this.change,
  });

  Widget divider(
          {EdgeInsets padding = const EdgeInsets.symmetric(vertical: 12)}) =>
      Container(
        padding: padding,
        child: const Divider(
          height: 1,
          color: MyColors.transparentWhite_10,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '보낼 수량',
              style: Styles.body2Bold,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Visibility(
                    visible: isMaxMode,
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 2),
                      margin: const EdgeInsets.only(right: 4, bottom: 16),
                      height: 24,
                      width: 34,
                      decoration: BoxDecoration(
                        color: MyColors.defaultBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          '최대',
                          style: Styles.caption2.copyWith(
                            color: MyColors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${satoshiToBitcoinString(sendAmount).normalizeToFullCharacters()} BTC',
                        style: Styles.body2Number,
                      ),
                      Text(
                          bitcoinPriceKrw != null
                              ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(sendAmount, bitcoinPriceKrw!).toDouble())} ${CurrencyCode.KRW.code}'
                              : '',
                          style: Styles.caption),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        divider(
            padding: const EdgeInsets.only(
          top: 12,
          bottom: 16,
        )),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '수수료',
                  style: recommendedFeeFetchStatus ==
                              RecommendedFeeFetchStatus.failed &&
                          !customFeeSelected
                      ? Styles.body2Bold.merge(
                          const TextStyle(
                            color: MyColors.transparentWhite_40,
                          ),
                        )
                      : Styles.body2Bold,
                ),
                CustomUnderlinedButton(
                  text: '변경',
                  padding: const EdgeInsets.only(
                    left: 8,
                    top: 4,
                    bottom: 8,
                    right: 8,
                  ),
                  isEnable: recommendedFeeFetchStatus !=
                      RecommendedFeeFetchStatus.fetching,
                  onTap: () {
                    onTapFeeButton();
                  },
                ),
              ],
            ),
            Expanded(
                child: recommendedFeeFetchStatus ==
                            RecommendedFeeFetchStatus.failed &&
                        !customFeeSelected
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '- ',
                            style: Styles.body2Bold.merge(const TextStyle(
                                color: MyColors.transparentWhite_40)),
                          ),
                          Text(
                            'BTC',
                            style: Styles.body2Number.merge(
                              const TextStyle(
                                color: MyColors.transparentWhite_40,
                              ),
                            ),
                          ),
                        ],
                      )
                    : recommendedFeeFetchStatus ==
                                RecommendedFeeFetchStatus.succeed ||
                            customFeeSelected
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${satoshiToBitcoinString(estimatedFee ?? 0).toString()} BTC',
                                style: Styles.body2Number,
                              ),
                              if (satsPerVb != null) ...{
                                Text(
                                  '${selectedLevel?.expectedTime ?? ''} ($satsPerVb sats/vb)',
                                  style: Styles.caption,
                                ),
                              },
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  color: MyColors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          )),
          ],
        ),
        divider(
          padding: const EdgeInsets.only(
            top: 10,
            bottom: 16,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '잔돈',
              style: change != null
                  ? (change! >= 0
                      ? Styles.body2Bold
                      : Styles.body2Bold
                          .merge(const TextStyle(color: MyColors.warningRed)))
                  : Styles.body2Bold.merge(
                      const TextStyle(
                        color: MyColors.transparentWhite_40,
                      ),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    change != null
                        ? '${satoshiToBitcoinString(change!)} BTC'
                        : '- BTC',
                    style: change != null
                        ? (change! >= 0
                            ? Styles.body2Number
                            : Styles.body2Number.merge(
                                const TextStyle(color: MyColors.warningRed)))
                        : Styles.body2Number.merge(const TextStyle(
                            color: MyColors.transparentWhite_40,
                          )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
