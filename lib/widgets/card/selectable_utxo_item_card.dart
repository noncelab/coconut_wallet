import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SelectableUtxoItemCard extends StatefulWidget {
  final UtxoState utxo;
  final bool isSelectable;
  final bool isSelected;
  final List<UtxoTag>? utxoTags;
  final Function(UtxoState) onSelected;
  final BitcoinUnit currentUnit;

  const SelectableUtxoItemCard({
    super.key,
    required this.isSelectable,
    required this.utxo,
    required this.isSelected,
    required this.onSelected,
    required this.currentUnit,
    this.utxoTags,
  });

  @override
  State<SelectableUtxoItemCard> createState() => _UtxoSelectableCardState();
}

class _UtxoSelectableCardState extends State<SelectableUtxoItemCard> {
  late bool _isPressing;
  late List<String> dateString;

  @override
  void initState() {
    super.initState();
    _isPressing = false;
    dateString = DateTimeUtil.formatTimestamp(widget.utxo.timestamp);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (!widget.isSelectable) return;
        setState(() {
          _isPressing = true;
        });
      },
      onTapCancel: () {
        if (!widget.isSelectable) return;
        setState(() {
          _isPressing = false;
        });
      },
      onTap: () {
        if (!widget.isSelectable) return;
        setState(() {
          _isPressing = false;
        });
        widget.onSelected(widget.utxo);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _isPressing ? MyColors.transparentWhite_10 : CoconutColors.black,
          borderRadius: BorderRadius.circular(
            20,
          ),
          border: Border.all(
            width: 1,
            color: widget.isSelected ? CoconutColors.primary : MyColors.borderGrey,
          ),
        ),
        padding: const EdgeInsets.only(
          top: 23,
          bottom: 22,
          left: 18,
          right: 23,
        ),
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
                        formatBitcoinBalance(widget.utxo.amount, widget.currentUnit),
                        style: Styles.h2Number,
                      ),
                      CoconutLayout.spacing_100w,
                      if (widget.utxo.status == UtxoStatus.incoming)
                        CoconutChip(
                          color: CoconutColors.gray500,
                          label: t.status_receiving,
                          labelColor: CoconutColors.black,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                        )
                    ],
                  ),
                  CoconutLayout.spacing_200h,
                  Row(
                    children: [
                      Text(
                        dateString[0],
                        style: Styles.caption,
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: MyColors.transparentWhite_40,
                        width: 1,
                        height: 10,
                      ),
                      Text(
                        dateString[1],
                        style: Styles.caption,
                      ),
                    ],
                  ),
                  Visibility(
                    visible: widget.utxoTags?.isNotEmpty == true,
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: List.generate(
                          widget.utxoTags?.length ?? 0,
                          (index) {
                            Color foregroundColor =
                                tagColorPalette[widget.utxoTags?[index].colorIndex ?? 0];
                            return IntrinsicWidth(
                              child: CoconutChip(
                                minWidth: 40,
                                color: CoconutColors.backgroundColorPaletteDark[
                                    widget.utxoTags?[index].colorIndex ?? 0],
                                borderColor: foregroundColor,
                                label: '#${widget.utxoTags?[index].name ?? ''}',
                                labelSize: 12,
                                labelColor: foregroundColor,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              'assets/svg/circle-check.svg',
              colorFilter: ColorFilter.mode(
                  widget.isSelected ? CoconutColors.primary : MyColors.transparentWhite_40,
                  BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}
