import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class LockedUtxoItemCard extends StatefulWidget {
  final UtxoState utxo;
  final List<UtxoTag>? utxoTags;
  final BitcoinUnit currentUnit;

  const LockedUtxoItemCard({super.key, required this.utxo, this.utxoTags, required this.currentUnit});

  @override
  State<LockedUtxoItemCard> createState() => _UtxoSelectableCardState();
}

class _UtxoSelectableCardState extends State<LockedUtxoItemCard> {
  late List<String> dateString;

  @override
  void initState() {
    super.initState();
    dateString = DateTimeUtil.formatTimestamp(widget.utxo.timestamp);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CoconutColors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(width: 1, color: MyColors.borderGrey),
      ),
      padding: const EdgeInsets.only(top: 23, bottom: 22, left: 18, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      widget.currentUnit.displayBitcoinAmount(widget.utxo.amount),
                      style: Styles.h2Number.setColor(CoconutColors.white.withValues(alpha: 0.3)),
                    ),
                    CoconutLayout.spacing_100w,
                    if (widget.utxo.status == UtxoStatus.incoming)
                      CoconutChip(
                        color: CoconutColors.gray500,
                        label: t.status_receiving,
                        labelColor: CoconutColors.black,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                      ),
                  ],
                ),
                CoconutLayout.spacing_200h,
                Row(
                  children: [
                    Text(dateString[0], style: Styles.caption.setColor(CoconutColors.white.withValues(alpha: 0.3))),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: CoconutColors.white.withValues(alpha: 0.3),
                      width: 1,
                      height: 10,
                    ),
                    Text(dateString[1], style: Styles.caption.setColor(CoconutColors.white.withValues(alpha: 0.3))),
                  ],
                ),
                Visibility(
                  visible: widget.utxoTags?.isNotEmpty == true,
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: List.generate(widget.utxoTags?.length ?? 0, (index) {
                        Color foregroundColor = tagColorPalette[widget.utxoTags?[index].colorIndex ?? 0];
                        return IntrinsicWidth(
                          child: CoconutChip(
                            minWidth: 40,
                            color: CoconutColors.backgroundColorPaletteDark[widget.utxoTags?[index].colorIndex ?? 0],
                            borderColor: foregroundColor,
                            label: '#${widget.utxoTags?[index].name ?? ''}',
                            labelSize: 12,
                            labelColor: foregroundColor,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SvgPicture.asset(
            'assets/svg/lock.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(CoconutColors.white.withValues(alpha: 0.3), BlendMode.srcIn),
          ),
        ],
      ),
    );
  }
}
