import 'package:coconut_wallet/model/utxo.dart' as model;
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/custom_tag_chip.dart';
import 'package:coconut_wallet/widgets/custom_chip.dart';
import 'package:flutter/material.dart';

class UTXOItemCard extends StatelessWidget {
  final model.UTXO utxo;

  const UTXOItemCard({
    super.key,
    required this.utxo,
  });

  @override
  Widget build(BuildContext context) {
    List<String> dateString =
        DateTimeUtil.formatDatetime(utxo.timestamp).split('|');
    bool isChange = utxo.derivationPath.split('/')[4] == '1';
    bool isConfirmed = int.parse(utxo.blockHeight) != 0;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: MyColors.transparentWhite_12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  children: [
                    Text(
                      dateString[0],
                      style: isConfirmed
                          ? Styles.caption
                          : Styles.caption.merge(const TextStyle(
                              color: MyColors.transparentWhite_20)),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      '|',
                      style: Styles.caption.merge(
                        TextStyle(
                          color: isConfirmed
                              ? MyColors.transparentWhite_40
                              : MyColors.transparentWhite_20,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      dateString[1],
                      style: isConfirmed
                          ? Styles.caption
                          : Styles.caption.merge(
                              const TextStyle(
                                color: MyColors.transparentWhite_20,
                              ),
                            ),
                    ),
                  ],
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isChange)
                        CustomChip(
                          text: '잔돈',
                          borderColor:
                              isConfirmed ? null : MyColors.transparentWhite_20,
                          textStyle: isConfirmed
                              ? null
                              : Styles.caption2.copyWith(
                                  color: MyColors.transparentWhite_20,
                                  height: 1.0,
                                ),
                        ),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        satoshiToBitcoinString(utxo.amount),
                        style: Styles.body1Number.merge(
                          TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 24 / 16,
                            letterSpacing: 16 * 0.01,
                            color: isConfirmed
                                ? MyColors.white
                                : MyColors.transparentWhite_20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              utxo.to,
              style: Styles.body2Number.merge(
                TextStyle(
                  color: isConfirmed
                      ? MyColors.transparentWhite_50
                      : MyColors.transparentWhite_20,
                ),
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(
                utxo.tags?.length ?? 0,
                (index) => IntrinsicWidth(
                  child: CustomTagChip(
                    tag: utxo.tags?[index].name ?? '',
                    colorIndex: utxo.tags?[index].colorIndex ?? 0,
                    type: CustomTagChipType.fix,
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
