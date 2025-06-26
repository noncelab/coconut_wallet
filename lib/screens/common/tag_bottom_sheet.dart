import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_tag_crud_view_model.dart';
import 'package:coconut_wallet/screens/common/tag_edit_bottom_sheet.dart';
import 'package:coconut_wallet/utils/colors_util.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum UtxoTagEditMode { add, delete, changAppliedTags, update }

/// [TagBottomSheet] : Utxo Detail 화면에서 '태그 편집' 클릭 시 노출
/// [utxoTags] : 지갑의 UtxoTag 전체 목록
/// [selectedTagNames] : select type only, 선택된 Utxo name 목록
/// [updateUtxoTag] : update type only, 선택된 태그를 수정하기 위한 UtxoTag 객체
/// [onUpdate] : utxo detail에서 선택 또는 생성된 태그 목록 변경 완료 콜백
class TagBottomSheet extends StatefulWidget {
  final int walletId;
  final List<UtxoTag> utxoTags;
  final List<String>? selectedTagNames;
  final Function(List<String>, List<UtxoTag>, UtxoTagEditMode)? onUpdate;

  const TagBottomSheet({
    super.key,
    required this.walletId,
    required this.utxoTags,
    this.selectedTagNames,
    this.onUpdate,
  });

  @override
  State<TagBottomSheet> createState() => _TagBottomSheetState();
}

class _TagBottomSheetState extends State<TagBottomSheet> {
  late final UtxoTagCrudViewModel _viewModel;

  late List<UtxoTag> _utxoTags;
  late List<String> _prevSelectedTagNames;
  late List<String> _tagNamesToDelete;

  bool _isButtonActive = false;
  bool _isDeletionMode = false;

  // 삭제 가능한 태그들
  List<UtxoTag> get _deletableTags {
    return _utxoTags.where((tag) => tag.utxoIdList == null || tag.utxoIdList!.isEmpty).toList();
  }

  // 현재 보여줄 태그 목록
  List<UtxoTag> get _displayedTags {
    return _isDeletionMode ? _deletableTags : _utxoTags;
  }

  @override
  void initState() {
    super.initState();

    _viewModel = UtxoTagCrudViewModel(
      context.read<UtxoTagProvider>(),
      widget.walletId,
    );

    _prevSelectedTagNames = [];
    _tagNamesToDelete = [];

    _utxoTags = List.from(_viewModel.utxoTagList);

    if (widget.selectedTagNames != null) {
      _prevSelectedTagNames = List.from(widget.selectedTagNames!);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UtxoTagCrudViewModel>.value(
      value: _viewModel,
      child: Consumer<UtxoTagCrudViewModel>(builder: (context, model, child) {
        return CoconutBottomSheet(
          useIntrinsicHeight: true,
          appBar: CoconutAppBar.buildWithNext(
              isBottom: true,
              context: context,
              onBackPressed: () {
                Navigator.pop(context);
              },
              onNextPressed: () {
                widget.onUpdate
                    ?.call(_prevSelectedTagNames, _utxoTags, UtxoTagEditMode.changAppliedTags);
                Navigator.pop(context);
              },
              title: t.tag_bottom_sheet.title_edit_tag,
              isActive: !_isDeletionMode && _isButtonActive,
              nextButtonTitle: t.complete),
          body: Consumer<UtxoTagCrudViewModel>(builder: (context, viewModel, child) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: _buildUpdateView(),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildUpdateView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTagList(),
        _buildTagAdditionMenu(),
        _buildTagDeletionMenu(),
      ],
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
                  final isSelected = _prevSelectedTagNames.contains(tag.name);

                  return TagChip(
                    tag: tag,
                    isSelected: isSelected,
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
    final tag = currentTagList[index].name;

    if (_isDeletionMode) {
      _tagNamesToDelete.add(tag);
      _prevSelectedTagNames.remove(tag);
      _utxoTags.removeWhere((t) => t.id == currentTagList[index].id);
      setState(() {});

      _checkButtonEnabled();
      // 삭제 시 바로 db에서 삭제
      widget.onUpdate?.call(_prevSelectedTagNames, _utxoTags, UtxoTagEditMode.delete);

      if (_deletableTags.isEmpty) {
        _toggleDeletionMode();
      }

      return;
    }

    // 적용 태그 선택 변경되는 경우, 완료 버튼 누르면 업데이트
    setState(() {
      if (_prevSelectedTagNames.contains(tag)) {
        _prevSelectedTagNames.remove(tag);
      } else {
        if (_prevSelectedTagNames.length == 5) {
          CoconutToast.showToast(
            context: context,
            isVisibleIcon: true,
            text: t.tag_bottom_sheet.max_tag_count,
            seconds: 2,
          );
          return;
        }
        _prevSelectedTagNames.add(tag);
      }

      _checkButtonEnabled();
    });
  }

  void _handleTagChipLongPress(BuildContext context, UtxoTag selectedUtxoTag) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagEditBottomSheet(
        walletId: widget.walletId,
        existingTags: _utxoTags,
        updateUtxoTag: selectedUtxoTag,
        onTagCreated: (updatedTag) {
          setState(() {
            final originalIndex =
                _utxoTags.indexWhere((utxoTag) => utxoTag.id == selectedUtxoTag.id);
            if (originalIndex != -1) {
              _utxoTags.removeAt(originalIndex);
              _utxoTags.insert(originalIndex, updatedTag);
            }

            if (selectedUtxoTag.name != updatedTag.name) {
              final selectedTagIndex = _prevSelectedTagNames.indexOf(selectedUtxoTag.name);
              if (selectedTagIndex != -1) {
                _prevSelectedTagNames[selectedTagIndex] = updatedTag.name;
              }
            }

            widget.onUpdate?.call(_prevSelectedTagNames, _utxoTags, UtxoTagEditMode.update);

            if (selectedUtxoTag.name != updatedTag.name ||
                selectedUtxoTag.colorIndex != updatedTag.colorIndex) {
              widget.onUpdate
                  ?.call(_prevSelectedTagNames, _utxoTags, UtxoTagEditMode.changAppliedTags);
            }
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
        ));
  }

  void _showTagAdditionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagEditBottomSheet(
        walletId: widget.walletId,
        existingTags: _utxoTags,
        onTagCreated: (newTag) {
          setState(() {
            // 완료 버튼 클릭 시, 바로 db에 추가
            _utxoTags.insert(0, newTag);
            widget.onUpdate?.call(_prevSelectedTagNames, _utxoTags, UtxoTagEditMode.add);
            // 화면에 선택 상태로 보이기
            _prevSelectedTagNames.add(newTag.name);
          });
          _checkButtonEnabled();
        },
      ),
    );
  }

  Widget _buildTagDeletionMenu() {
    return Visibility(
      visible: _deletableTags.isNotEmpty,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: CoconutColors.white.withOpacity(0.12),
            height: 1,
          ),
          _buildMenuItem(
              _isDeletionMode ? t.tag_bottom_sheet.exit_deletion : t.tag_bottom_sheet.delete_tag,
              () {
            _toggleDeletionMode();
          }),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, VoidCallback onPress,
      {EdgeInsets padding = const EdgeInsets.symmetric(vertical: Sizes.size20)}) {
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

  void _checkButtonEnabled() {
    final prevSelectedTagIds = _convertTagNamesToIds(widget.selectedTagNames ?? []);
    final currentSelectedIds = _convertTagNamesToIds(_prevSelectedTagNames);

    final currentSet = currentSelectedIds.toSet();
    final selectedSet = prevSelectedTagIds.toSet();

    final isUpdated = !currentSet.containsAll(selectedSet) || !selectedSet.containsAll(currentSet);

    setState(() {
      _isButtonActive = isUpdated;
    });
  }

  List<String> _convertTagNamesToIds(List<String> tagNames) {
    return tagNames
        .map((name) => _utxoTags
            .firstWhere(
              (tag) => tag.name == name,
              orElse: () => UtxoTag(id: '', walletId: 0, name: name, colorIndex: 0),
            )
            .id)
        .where((id) => id.isNotEmpty)
        .toList();
  }
}

class TagChip extends StatelessWidget {
  final UtxoTag tag;
  final bool isSelected;
  final bool isDeletionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TagChip({
    super.key,
    required this.tag,
    required this.isSelected,
    required this.isDeletionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = tagColorPalette[tag.colorIndex];
    final backgroundColor = isDeletionMode
        ? CoconutColors.gray800
        : isSelected
            ? CoconutColors.backgroundColorPaletteDark[tag.colorIndex]
            : CoconutColors.gray800;

    final borderColor = isDeletionMode
        ? CoconutColors.gray600
        : isSelected
            ? foregroundColor
            : CoconutColors.gray600;

    final borderWidth = isDeletionMode
        ? 0.5
        : isSelected
            ? 1.0
            : 0.5;

    final textColor = isDeletionMode
        ? CoconutColors.gray300
        : isSelected
            ? foregroundColor
            : CoconutColors.gray600;

    final fontWeight = isDeletionMode || !isSelected ? FontWeight.normal : FontWeight.w600;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isDeletionMode
                ? const Padding(
                    padding: EdgeInsets.only(right: 4.0),
                    child: Icon(Icons.close,
                        key: ValueKey('delete'), size: 16, color: CoconutColors.white),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Icon(Icons.check,
                                key: const ValueKey('check'), size: 16, color: foregroundColor),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),
            // const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: CoconutTypography.body3_12.copyWith(color: textColor, fontWeight: fontWeight),
              child: Text('#${tag.name}'),
            ),
          ],
        ),
      ),
    );
  }
}
