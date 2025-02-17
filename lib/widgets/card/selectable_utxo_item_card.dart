import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SelectableUtxoItemCard extends StatefulWidget {
  final UTXO utxo;
  final bool isSelected;
  final List<UtxoTag>? utxoTags;
  final Function(UTXO) onSelected;

  const SelectableUtxoItemCard({
    super.key,
    required this.utxo,
    required this.isSelected,
    required this.onSelected,
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
    dateString = DateTimeUtil.formatDatetime(widget.utxo.timestamp.toString())
        .split('|');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _isPressing = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _isPressing = false;
        });
      },
      onTap: () {
        setState(() {
          _isPressing = false;
        });
        widget.onSelected(widget.utxo);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _isPressing ? MyColors.transparentWhite_10 : MyColors.black,
          borderRadius: BorderRadius.circular(
            20,
          ),
          border: Border.all(
            width: 1,
            color: widget.isSelected ? MyColors.primary : MyColors.borderGrey,
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
                  Text(
                    satoshiToBitcoinString(widget.utxo.amount),
                    style: Styles.h2Number,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
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
                          (index) => IntrinsicWidth(
                            child: CoconutTagChip(
                              tag: widget.utxoTags?[index].name ?? '',
                              color: CoconutColors.backgroundColorPaletteDark[
                                  widget.utxoTags?[index].colorIndex ?? 0],
                              status: CoconutChipStatus.none,
                            ),
                          ),
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
                  widget.isSelected
                      ? MyColors.primary
                      : MyColors.transparentWhite_40,
                  BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}
