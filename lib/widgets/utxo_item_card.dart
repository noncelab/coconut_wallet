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
      const UtxoTag(name: 'THESE', colorIndex: 0),
      const UtxoTag(name: 'ARE', colorIndex: 1),
      const UtxoTag(name: 'TEST', colorIndex: 2),
      const UtxoTag(name: 'DATA', colorIndex: 3),
      const UtxoTag(name: 'SO', colorIndex: 4),
      const UtxoTag(name: 'YOU', colorIndex: 5),
      const UtxoTag(name: 'HAVE', colorIndex: 6),
      const UtxoTag(name: 'TO', colorIndex: 7),
      const UtxoTag(name: 'FIX', colorIndex: 8),
    ];

    return GestureDetector(
        onTap: () {
          MyBottomSheet.showBottomSheet_90(
            context: context,
            child: UtxoDetailScreen(
              utxo: utxo,
            ),
          );
          // showModalBottomSheet(
          //   context: context,
          //   backgroundColor: MyColors.black,
          //   builder: (context) => TagBottomSheetContainer(
          //     type: TagBottomSheetType.select,
          //     onComplete: (_, utxo) => debugPrint(utxo.toString()),
          //     utxoTags: const [
          // UtxoTag(tag: 'kyc', colorIndex: 0),
          // UtxoTag(tag: 'coconut', colorIndex: 2),
          // UtxoTag(tag: 'strike', colorIndex: 7),
          // UtxoTag(tag: '1', colorIndex: 7),
          // UtxoTag(tag: '2', colorIndex: 7),
          // UtxoTag(tag: '3', colorIndex: 7),
          // UtxoTag(tag: '4', colorIndex: 7),
          // UtxoTag(tag: '5', colorIndex: 7),
          //     ],
          //   ),
          // );
        },
        child: Container(
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
                        tag: utxoTags[index].name,
                        colorIndex: utxoTags[index].colorIndex,
                        type: CustomTagChipType.fix,
                      ),
                    ),
                  ),
                ),
              ],
            )));
  }
}
