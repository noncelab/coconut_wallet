import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
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
          color: _isPressing ? context.coconutColors.surfacePressed : context.coconutColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            width: 1,
            color: widget.isSelected ? context.coconutColors.borderStrong : context.coconutColors.border,
          ),
        ),
        padding: const EdgeInsets.only(top: 23, bottom: 22, left: 18, right: 23),
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
                        style: CoconutTypography.heading4_18_NumberBold.setColor(context.coconutColors.primaryText),
                      ),
                      CoconutLayout.spacing_100w,
                      if (widget.utxo.status == UtxoStatus.incoming)
                        CoconutChip(
                          color: context.coconutColors.infoChipBackground,
                          label: t.status_receiving,
                          labelColor: context.coconutColors.receivingColor,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                        ),
                    ],
                  ),
                  CoconutLayout.spacing_200h,
                  Row(
                    children: [
                      Text(
                        dateString[0],
                        style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: context.coconutColors.secondaryText,
                        width: 1,
                        height: 10,
                      ),
                      Text(
                        dateString[1],
                        style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText),
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
              'assets/svg/circle-check.svg',
              colorFilter: ColorFilter.mode(
                widget.isSelected ? context.coconutColors.primaryText : context.coconutColors.primaryText.withAlpha(40),
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
