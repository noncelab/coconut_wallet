import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class TagSelectResult {
  final String? selectedTagName;

  const TagSelectResult({required this.selectedTagName});
}

class TagSelectBottomSheet extends StatefulWidget {
  final int walletId;
  final String? initialSelectedTagName;

  const TagSelectBottomSheet({super.key, required this.walletId, this.initialSelectedTagName});

  @override
  State<TagSelectBottomSheet> createState() => _TagSelectBottomSheetState();
}

class _TagSelectBottomSheetState extends State<TagSelectBottomSheet> {
  late final List<UtxoTag> _utxoTags;
  String? _selectedTagName;

  @override
  void initState() {
    super.initState();
    final utxoTagProvider = context.read<UtxoTagProvider>();
    final utxoRepository = context.read<UtxoRepository>();
    final currentUtxoIds = utxoRepository.getUtxoStateList(widget.walletId).map((utxo) => utxo.utxoId).toSet();

    _utxoTags =
        utxoTagProvider
            .getUtxoTagList(widget.walletId)
            .where((tag) => (tag.utxoIdList ?? []).where(currentUtxoIds.contains).length >= 2)
            .toList();
    _selectedTagName = widget.initialSelectedTagName;
  }

  void _dismiss() {
    Navigator.pop(context);
  }

  void _confirm() {
    Navigator.pop(context, TagSelectResult(selectedTagName: _selectedTagName));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _dismiss();
      },
      child: CoconutBottomSheet(
        useIntrinsicHeight: true,
        bottomMargin: 0,
        appBar: CoconutAppBar.build(
          isBottom: true,
          context: context,
          onBackPressed: _dismiss,
          title: t.merge_utxos_screen.select_tag,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: FixedBottomButton.fixedBottomButtonDefaultBottomPadding + 3),
            child: SizedBox(width: double.infinity, child: _buildContent()),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoconutLayout.spacing_400h,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          constraints: const BoxConstraints(minHeight: 30, maxHeight: 296),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _utxoTags.map((tag) {
                    return _SelectableTagChip(
                      tag: tag,
                      isSelected: _selectedTagName == tag.name,
                      onTap: () {
                        setState(() {
                          _selectedTagName = _selectedTagName == tag.name ? null : tag.name;
                        });
                      },
                    );
                  }).toList(),
            ),
          ),
        ),
        CoconutLayout.spacing_600h,
        SizedBox(
          height: 120,
          child: FixedBottomButton(
            text: t.complete,
            isActive: _selectedTagName != null,
            bottomPadding: 0,
            onButtonClicked: _confirm,
            backgroundColor: CoconutColors.white,
          ),
        ),
      ],
    );
  }
}

class _SelectableTagChip extends StatelessWidget {
  final UtxoTag tag;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableTagChip({required this.tag, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final foregroundColor = tagColorPalette[tag.colorIndex];
    final backgroundColor = foregroundColor.withOpacity(0.18);
    final style = _styleFor(foregroundColor);

    Widget chipForeground = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.borderColor, width: 0.5),
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: CoconutTypography.body3_12.copyWith(color: style.textColor, fontWeight: style.fontWeight),
        child: Text('#${tag.name}'),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(20)),
        child: chipForeground,
      ),
    );
  }

  _SelectableChipStyle _styleFor(Color foregroundColor) {
    if (isSelected) {
      return _SelectableChipStyle(
        borderColor: foregroundColor,
        textColor: foregroundColor,
        fontWeight: FontWeight.w700,
        icon: SvgPicture.asset(
          'assets/svg/circle-check.svg',
          key: const ValueKey('selected'),
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(foregroundColor, BlendMode.srcIn),
        ),
      );
    }

    final inactiveColor = foregroundColor.withOpacity(0.4);
    return _SelectableChipStyle(
      borderColor: inactiveColor,
      textColor: inactiveColor,
      icon: SvgPicture.asset(
        'assets/svg/circle.svg',
        key: const ValueKey('unselected'),
        width: 16,
        height: 16,
        colorFilter: ColorFilter.mode(inactiveColor, BlendMode.srcIn),
      ),
    );
  }
}

class _SelectableChipStyle {
  final Color borderColor;
  final Color textColor;
  final FontWeight fontWeight;
  final Widget icon;

  const _SelectableChipStyle({
    required this.borderColor,
    required this.textColor,
    this.fontWeight = FontWeight.normal,
    required this.icon,
  });
}
