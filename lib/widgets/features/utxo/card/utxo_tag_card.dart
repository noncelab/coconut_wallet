import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutUnderlinedButton;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:flutter/material.dart';

/// [UtxoTagCard] : UTXO 태그 관리 화면 - 태그 목록을 보여주고 선택할 수 있는 위젯
/// [tags] : 표시할 태그 목록
/// [onSelectedTag] : 태그 선택시 호출되는 콜백
/// [externalUpdatedTagName] : 선택된 태그명이 외부에서 변경되었을 때 선택 상태를 업데이트
class UtxoTagCard extends StatefulWidget {
  final List<UtxoTag> tags;
  final ValueChanged<UtxoTag?> onSelectedTag;
  final ValueChanged<UtxoTag>? onEditTag;
  final ValueChanged<UtxoTag>? onDeleteTag;
  final String? externalUpdatedTagName;

  const UtxoTagCard({
    super.key,
    required this.tags,
    required this.onSelectedTag,
    this.onEditTag,
    this.onDeleteTag,
    this.externalUpdatedTagName,
  });

  @override
  State<UtxoTagCard> createState() => _UtxoTagCardState();
}

class _UtxoTagCardState extends State<UtxoTagCard> {
  String _selectedTagName = '';
  int _selectedTagIndex = -1;
  String? _pressingTagId;

  @override
  void initState() {
    super.initState();
    _selectedTagName = widget.externalUpdatedTagName ?? '';
  }

  @override
  void didUpdateWidget(covariant UtxoTagCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalUpdatedTagName != oldWidget.externalUpdatedTagName &&
        widget.externalUpdatedTagName != _selectedTagName) {
      setState(() {
        _selectedTagName = widget.externalUpdatedTagName ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.tags.length,
      itemBuilder: (BuildContext context, int index) {
        final utxoTag = widget.tags[index];
        final isSelected = _selectedTagName == utxoTag.name && _selectedTagIndex == utxoTag.colorIndex;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            setState(() {
              _pressingTagId = utxoTag.id;
            });
          },
          onTapCancel: () {
            setState(() {
              _pressingTagId = null;
            });
          },
          onLongPressStart: (_) {
            setState(() {
              _pressingTagId = utxoTag.id;
            });
          },
          onLongPressEnd: (_) {
            setState(() {
              _pressingTagId = null;
            });
          },
          onTap: () {
            if (!isSelected) {
              _selectedTagName = utxoTag.name;
              _selectedTagIndex = utxoTag.colorIndex;
              widget.onSelectedTag(utxoTag);
            } else {
              _selectedTagName = '';
              _selectedTagIndex = -1;
              widget.onSelectedTag(null);
            }
            setState(() {
              _pressingTagId = null;
            });
          },
          child: UtxoTagItem(
            key: ValueKey(utxoTag.id),
            utxoTag: utxoTag,
            tag: utxoTag.name,
            colorIndex: utxoTag.colorIndex,
            usedCount: utxoTag.utxoIdList?.length ?? 0,
            isSelected: isSelected,
            isPressing: _pressingTagId == utxoTag.id,
            onEditTag: widget.onEditTag,
            onDeleteTag: widget.onDeleteTag,
          ),
        );
      },
    );
  }
}

class UtxoTagItem extends StatelessWidget {
  final UtxoTag utxoTag;
  final String tag;
  final int colorIndex;
  final int usedCount;
  final bool isSelected;
  final bool isPressing;
  final ValueChanged<UtxoTag>? onEditTag;
  final ValueChanged<UtxoTag>? onDeleteTag;

  const UtxoTagItem({
    super.key,
    required this.utxoTag,
    required this.tag,
    required this.colorIndex,
    required this.usedCount,
    required this.isSelected,
    required this.isPressing,
    this.onEditTag,
    this.onDeleteTag,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final borderColor = isSelected || isPressing ? colors.borderStrong : colors.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: WalletVisualStyleUtil.getColor(colorIndex).backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WalletVisualStyleUtil.getColor(colorIndex).color, width: 1),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '#',
                  style: CoconutTypography.body2_14.setColor(WalletVisualStyleUtil.getColor(colorIndex).color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#$tag',
                        style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (usedCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          t.apply_item(count: usedCount),
                          style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected && (onEditTag != null || onDeleteTag != null)) ...[
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEditTag != null)
                        CoconutUnderlinedButton(
                          text: t.edit,
                          textStyle: CoconutTypography.caption_10.setColor(colors.secondaryText),
                          onTap: () => onEditTag?.call(utxoTag),
                        ),
                      if (onEditTag != null && onDeleteTag != null) CoconutLayout.spacing_100w,
                      if (onDeleteTag != null)
                        CoconutUnderlinedButton(
                          text: t.delete,
                          textStyle: CoconutTypography.caption_10.setColor(colors.secondaryText),
                          onTap: () => onDeleteTag?.call(utxoTag),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
