import 'package:coconut_wallet/model/utxo.dart' as model;
import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/screens/utxo_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/bottom_sheet.dart';
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
    List<UtxoTag> utxoTags = [
      const UtxoTag(tag: 'THESE', colorIndex: 0),
      const UtxoTag(tag: 'ARE', colorIndex: 1),
      const UtxoTag(tag: 'TEST', colorIndex: 2),
      const UtxoTag(tag: 'DATA', colorIndex: 3),
      const UtxoTag(tag: 'SO', colorIndex: 4),
      const UtxoTag(tag: 'YOU', colorIndex: 5),
      const UtxoTag(tag: 'HAVE', colorIndex: 6),
      const UtxoTag(tag: 'TO', colorIndex: 7),
      const UtxoTag(tag: 'FIX', colorIndex: 8),
    ];

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        margin: const EdgeInsets.only(bottom: 12),
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
                      style: Styles.caption,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    const Text('|'),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      dateString[1],
                      style: Styles.caption,
                    ),
                  ],
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isChange) const CustomChip(text: '잔돈'),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        satoshiToBitcoinString(utxo.amount),
                        style: Styles.h3.merge(
                          TextStyle(
                            fontFamily: CustomFonts.number.getFontFamily,
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
              style: Styles.caption.merge(
                const TextStyle(
                  color: MyColors.transparentWhite_50,
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
                utxoTags.length,
                (index) => IntrinsicWidth(
                  child: CustomTagChip(
                    tag: utxoTags[index].tag,
                    colorIndex: utxoTags[index].colorIndex,
                    type: CustomTagChipType.fix,
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
