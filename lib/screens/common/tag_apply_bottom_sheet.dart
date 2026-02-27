import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_tag_crud_view_model.dart';
import 'package:coconut_wallet/screens/common/tag_edit_bottom_sheet.dart';
import 'package:coconut_wallet/utils/colors_util.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

enum UtxoTagApplyEditMode { add, delete, changeAppliedTags, update }

enum TagApplyState { original, checked, unchecked }

class TagApplyResult {
  final UtxoTagApplyEditMode mode;
  final Map<String, TagApplyState> tagStates;
  final List<String> updatedTags;

  const TagApplyResult({required this.mode, required this.tagStates, this.updatedTags = const []});
}

/// [TagApplyBottomSheet] : Utxo Detail 화면에서 '태그 편집' 클릭 시 노출
class TagApplyBottomSheet extends StatefulWidget {
  final int walletId;
  final List<String> selectedUtxoIds;

  const TagApplyBottomSheet({super.key, required this.walletId, required this.selectedUtxoIds});

  @override
  State<TagApplyBottomSheet> createState() => _TagApplyBottomSheetState();
}

class _TagApplyBottomSheetState extends State<TagApplyBottomSheet> {
  late final UtxoTagCrudViewModel _viewModel;

  late List<UtxoTag> _utxoTags;
  late Map<String, TagApplyState> _tagStates;
  late List<String> _tagNamesToDelete;

  bool _isDeletionMode = false;
  bool _isTagListModified = false;

  List<UtxoTag> get _deletableTags {
    return _utxoTags.where((tag) => tag.utxoIdList == null || tag.utxoIdList!.isEmpty).toList();
  }

  List<UtxoTag> get _displayedTags {
    return _isDeletionMode ? _deletableTags : _utxoTags;
  }

  @override
  void initState() {
    super.initState();

    _viewModel = UtxoTagCrudViewModel(context.read<UtxoTagProvider>(), widget.walletId);

    _tagNamesToDelete = [];
    _utxoTags = List.from(_viewModel.utxoTagList);

    _tagStates = {};
    for (var tag in _utxoTags) {
      int matchCount = widget.selectedUtxoIds.where((id) => tag.utxoIdList?.contains(id) ?? false).length;

      if (matchCount == 0) {
        _tagStates[tag.name] = TagApplyState.unchecked;
      } else if (matchCount == widget.selectedUtxoIds.length) {
        _tagStates[tag.name] = TagApplyState.checked;
      } else {
        _tagStates[tag.name] = TagApplyState.original;
      }
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _handlePop() {
    if (_isTagListModified) {
      Navigator.pop(context, TagApplyResult(mode: UtxoTagApplyEditMode.update, tagStates: _tagStates));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, dynamic result) {
        if (didPop) return;
        _handlePop();
      },
      child: ChangeNotifierProvider<UtxoTagCrudViewModel>.value(
        value: _viewModel,
        child: Consumer<UtxoTagCrudViewModel>(
          builder: (context, model, child) {
            return CoconutBottomSheet(
              useIntrinsicHeight: true,
              appBar: CoconutAppBar.buildWithNext(
                isBottom: true,
                context: context,
                onBackPressed: _handlePop,
                onNextPressed: () {
                  Navigator.pop(
                    context,
                    TagApplyResult(mode: UtxoTagApplyEditMode.changeAppliedTags, tagStates: _tagStates),
                  );
                },
                title: t.tag_bottom_sheet.title_apply_tag,
                isActive: !_isDeletionMode,
                nextButtonTitle: t.complete,
              ),
              body: Consumer<UtxoTagCrudViewModel>(
                builder: (context, viewModel, child) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(width: double.infinity, child: _buildUpdateView()),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUpdateView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [_buildTagList(), _buildTagAdditionMenu(), _buildTagDeletionMenu()],
    );
  }

  void _toggleDeletionMode() {
    setState(() {
      _isDeletionMode = !_isDeletionMode;
      if (!_isDeletionMode) {
        _tagNamesToDelete.clear();
      }
    });
  }

  Widget _buildTagList() {
    final tagsToShow = _displayedTags;

    return Visibility(
      visible: tagsToShow.isNotEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoconutLayout.spacing_400h,
          Container(
            constraints: const BoxConstraints(minHeight: 30, maxHeight: 296),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(tagsToShow.length, (index) {
                  final tag = tagsToShow[index];
                  final applyState = _tagStates[tag.name] ?? TagApplyState.original;

                  return TagChip(
                    tag: tag,
                    applyState: applyState,
                    isDeletionMode: _isDeletionMode,
                    onTap: () => _handleTagChipTap(context, index, tagsToShow),
                    onLongPress: () => _handleTagChipLongPress(context, tagsToShow[index]),
                  );
                }),
              ),
            ),
          ),
          CoconutLayout.spacing_500h,
          Divider(color: CoconutColors.white.withOpacity(0.12), height: 1),
        ],
      ),
    );
  }

  void _handleTagChipTap(BuildContext context, int index, List<UtxoTag> currentTagList) {
    final tagToDelete = currentTagList[index];
    final tag = tagToDelete.name;

    if (_isDeletionMode) {
      _tagNamesToDelete.add(tag);
      _tagStates.remove(tag);
      _viewModel.deleteUtxoTag(tagToDelete);

      setState(() {
        _utxoTags = List.from(_viewModel.utxoTagList);
        _isTagListModified = true;
      });

      if (_deletableTags.isEmpty) {
        _toggleDeletionMode();
      }
      return;
    }

    setState(() {
      final currentState = _tagStates[tag] ?? TagApplyState.original;
      TagApplyState nextState;

      switch (currentState) {
        case TagApplyState.original:
          nextState = TagApplyState.checked;
          break;
        case TagApplyState.checked:
          nextState = TagApplyState.unchecked;
          break;
        case TagApplyState.unchecked:
          nextState = TagApplyState.checked;
          break;
      }

      if (nextState == TagApplyState.checked) {
        final checkedCount = _tagStates.values.where((state) => state == TagApplyState.checked).length;
        if (checkedCount >= 5) {
          CoconutToast.showToast(
            context: context,
            isVisibleIcon: true,
            text: t.tag_bottom_sheet.max_tag_count,
            seconds: 2,
          );
          return;
        }
      }

      _tagStates[tag] = nextState;
    });
  }

  void _handleTagChipLongPress(BuildContext context, UtxoTag selectedUtxoTag) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TagEditBottomSheet(
            walletId: widget.walletId,
            existingTags: _utxoTags,
            updateUtxoTag: selectedUtxoTag,
            onTagCreated: (updatedTag) {
              _viewModel.toggleUtxoTag(selectedUtxoTag);
              _viewModel.updateUtxoTag(updatedTag);
              setState(() {
                _utxoTags = List.from(_viewModel.utxoTagList);

                if (selectedUtxoTag.name != updatedTag.name) {
                  final previousState = _tagStates.remove(selectedUtxoTag.name);
                  if (previousState != null) {
                    _tagStates[updatedTag.name] = previousState;
                  }
                }
                _isTagListModified = true;
              });
            },
          ),
    );
  }

  Widget _buildTagAdditionMenu() {
    return Visibility(
      visible: !_isDeletionMode || _utxoTags.isEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMenuItem(t.tag_bottom_sheet.add_new_tag, () {
            _showTagAdditionBottomSheet();
          }),
        ],
      ),
    );
  }

  void _showTagAdditionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TagEditBottomSheet(
            walletId: widget.walletId,
            existingTags: _utxoTags,
            onTagCreated: (newTag) async {
              _viewModel.addUtxoTag(newTag);

              setState(() {
                _utxoTags = List.from(_viewModel.utxoTagList);
                _tagStates[newTag.name] = TagApplyState.checked;
                _isTagListModified = true;
              });
            },
          ),
    );
  }

  Widget _buildTagDeletionMenu() {
    return Visibility(
      visible: _deletableTags.isNotEmpty || _isDeletionMode,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: CoconutColors.white.withOpacity(0.12), height: 1),
          _buildMenuItem(_isDeletionMode ? t.tag_bottom_sheet.exit_deletion : t.tag_bottom_sheet.delete_tag, () {
            _toggleDeletionMode();
          }),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    String title,
    VoidCallback onPress, {
    EdgeInsets padding = const EdgeInsets.symmetric(vertical: Sizes.size20),
  }) {
    return GestureDetector(
      onTap: onPress,
      behavior: HitTestBehavior.translucent,
      child: Container(
        width: double.infinity,
        color: Colors.transparent,
        padding: padding,
        child: Text(title, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  final UtxoTag tag;
  final TagApplyState applyState;
  final bool isDeletionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TagChip({
    super.key,
    required this.tag,
    required this.applyState,
    required this.isDeletionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = tagColorPalette[tag.colorIndex];
    final backgroundColor = foregroundColor.withOpacity(0.18);

    final style = _getStyle(foregroundColor);

    Widget innerContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Padding(padding: const EdgeInsets.only(right: 4.0), child: style.icon),
        ),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: CoconutTypography.body3_12.copyWith(color: style.textColor, fontWeight: style.fontWeight),
          child: Text('#${tag.name}'),
        ),
      ],
    );

    Widget chipForeground = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.borderColor, width: 0.5),
      ),
      child: innerContent,
    );

    if (style.gradient != null) {
      chipForeground = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => style.gradient!.createShader(bounds),
        child: chipForeground,
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(20)),
        child: chipForeground,
      ),
    );
  }

  _ChipStyle _getStyle(Color foregroundColor) {
    if (isDeletionMode) {
      return _ChipStyle(
        borderColor: foregroundColor,
        textColor: foregroundColor,
        icon: const Icon(Icons.close, key: ValueKey('delete'), size: 16, color: CoconutColors.white),
      );
    }

    switch (applyState) {
      case TagApplyState.original:
        return _ChipStyle(
          borderColor: Colors.white,
          textColor: Colors.white,
          icon: SvgPicture.asset(
            'assets/svg/circle-minus.svg',
            key: const ValueKey('original'),
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(foregroundColor.withOpacity(0.6), BlendMode.srcIn),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [CoconutColors.backgroundColorPaletteDark[tag.colorIndex], foregroundColor],
          ),
        );
      case TagApplyState.checked:
        return _ChipStyle(
          borderColor: foregroundColor,
          textColor: foregroundColor,
          fontWeight: FontWeight.w600,
          icon: SvgPicture.asset(
            'assets/svg/circle-check.svg',
            key: const ValueKey('check'),
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(foregroundColor, BlendMode.srcIn),
          ),
        );
      case TagApplyState.unchecked:
        final opacColor = foregroundColor.withOpacity(0.4);
        return _ChipStyle(
          borderColor: opacColor,
          textColor: opacColor,
          icon: SvgPicture.asset(
            'assets/svg/circle.svg',
            key: const ValueKey('unchecked'),
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(opacColor, BlendMode.srcIn),
          ),
        );
    }
  }
}

class _ChipStyle {
  final Color borderColor;
  final Color textColor;
  final FontWeight fontWeight;
  final Widget icon;
  final Gradient? gradient;

  _ChipStyle({
    required this.borderColor,
    required this.textColor,
    this.fontWeight = FontWeight.normal,
    required this.icon,
    this.gradient,
  });
}
