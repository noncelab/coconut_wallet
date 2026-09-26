import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutPopup;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:flutter/material.dart';

class TagInheritanceDialog extends StatefulWidget {
  final List<UtxoTag> tags;
  final String languageCode;

  const TagInheritanceDialog({super.key, required this.tags, required this.languageCode});

  @override
  State<TagInheritanceDialog> createState() => _TagInheritanceDialogState();
}

class _TagInheritanceDialogState extends State<TagInheritanceDialog> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    String keepKoreanWordsTogether(String text) =>
        widget.languageCode == 'ko'
            ? text.replaceAllMapped(RegExp(r'\S+'), (match) => match[0]!.characters.join('\u2060'))
            : text;

    if (widget.tags.length <= 5) {
      return CoconutPopup(
        languageCode: widget.languageCode,
        title: t.alert.tag_apply.title,
        description: keepKoreanWordsTogether(t.alert.tag_apply.description),
        leftButtonText: t.alert.tag_apply.btn_without_tags,
        rightButtonText: t.alert.tag_apply.btn_apply,
        onTapLeft: () => Navigator.pop(context, <String>[]),
        onTapRight: () => Navigator.pop(context, widget.tags.map((tag) => tag.id).toList()),
      );
    }

    final colors = context.coconutColors;
    return Dialog(
      insetPadding: const EdgeInsets.all(CoconutLayout.defaultPadding),
      backgroundColor: colors.popupBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoconutStyles.radius_250)),
      child: Padding(
        padding: const EdgeInsets.all(CoconutLayout.defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.alert.tag_apply.title,
              textAlign: TextAlign.center,
              style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
            ),
            CoconutLayout.spacing_300h,
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      keepKoreanWordsTogether(t.alert.tag_apply.description),
                      semanticsLabel: t.alert.tag_apply.description,
                      textAlign: TextAlign.center,
                      style: CoconutTypography.body1_16.setColor(colors.primaryText),
                    ),
                    CoconutLayout.spacing_300h,
                    Text(
                      keepKoreanWordsTogether(t.tag_bottom_sheet.max_tag_count),
                      semanticsLabel: t.tag_bottom_sheet.max_tag_count,
                      textAlign: TextAlign.center,
                      style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                    ),
                    CoconutLayout.spacing_300h,
                    Wrap(
                      spacing: Sizes.size8,
                      runSpacing: Sizes.size8,
                      children:
                          widget.tags.map((tag) {
                            final selected = _selectedIds.contains(tag.id);
                            void toggleTag() => setState(() {
                              if (selected) {
                                _selectedIds.remove(tag.id);
                              } else if (_selectedIds.length < 5) {
                                _selectedIds.add(tag.id);
                              }
                            });

                            return Semantics(
                              button: true,
                              selected: selected,
                              label: '#${tag.name}',
                              excludeSemantics: true,
                              onTap: toggleTag,
                              child: CoconutChip(
                                key: ValueKey(tag.id),
                                label: keepKoreanWordsTogether('#${tag.name}'),
                                color: WalletVisualStyleUtil.getColor(tag.colorIndex).backgroundColor,
                                borderColor: selected ? colors.primaryText : colors.border,
                                labelColor: colors.primaryText,
                                isSelected: selected,
                                padding: const EdgeInsets.all(Sizes.size12),
                                onTap: toggleTag,
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            CoconutLayout.spacing_300h,
            Text('${_selectedIds.length} / 5', style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
            CoconutLayout.spacing_200h,
            OverflowBar(
              alignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, <String>[]),
                  child: Text(
                    t.alert.tag_apply.btn_without_tags,
                    style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText),
                  ),
                ),
                TextButton(
                  onPressed: _selectedIds.isEmpty ? null : () => Navigator.pop(context, _selectedIds.toList()),
                  child: Text(
                    t.alert.tag_apply.btn_apply,
                    style: CoconutTypography.body1_16_Bold.setColor(
                      _selectedIds.isEmpty ? colors.mutedText : colors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
