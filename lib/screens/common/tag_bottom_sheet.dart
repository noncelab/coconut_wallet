import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/button/custom_tag_chip_color_button.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/textfield/custom_limit_text_field.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// [TagBottomSheetType]
/// - [attach] : 태그 목록 선택 변경 및 새 태그 생성
/// - [create] : 새 태그 생성
/// - [update] : 선택된 태그 수정
enum TagBottomSheetType { attach, create, update }

// Usage:
// utxo_detail_screen.dart
// utxo_tag.screen.dart

/// [TagBottomSheet] : 태그 선택 변경, 태그 수정, 태그 생성 BottomSheet
/// [type] : BottomSheet Type
/// [utxoTags] : 지갑에 생성된 UtxoTag 전체 목록
/// [selectedUtxoTagNames] : select type only, 선택된 Utxo name 목록
/// [updateUtxoTag] : update type only, 선택된 태그를 수정하기 위한 UtxoTag 객체
/// [onSelected] : utxo detail에서 선택 또는 생성된 태그 목록 변경 완료 콜백
/// [onUpdated] : create type, update type 선택된 태그 편집 및 새 태그 생성 완료 콜백
class TagBottomSheet extends StatefulWidget {
  final TagBottomSheetType type;
  final List<UtxoTag> utxoTags;
  final List<String>? selectedUtxoTagNames;
  final UtxoTag? updateUtxoTag;
  final Function(List<String>, List<UtxoTag>)? onSelected;
  final Function(UtxoTag)? onUpdated;
  const TagBottomSheet({
    super.key,
    required this.type,
    required this.utxoTags,
    this.selectedUtxoTagNames,
    this.updateUtxoTag,
    this.onSelected,
    this.onUpdated,
  });

  @override
  State<TagBottomSheet> createState() => _TagBottomSheetState();
}

class _TagBottomSheetState extends State<TagBottomSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  late List<UtxoTag> _utxoTags;
  late List<UtxoTag> _createdUtxoTags;
  late List<String> _prevSelectedUtxoTagNames;

  // 바텀 시트를 호출한 컨텍스트
  // 1. select: utxo 상세 화면 utxo 태그 선택
  // 2. create: utxo 관리 화면 태그 생성
  // 3. update: utxo 관리 화면 태그 수정
  late final TagBottomSheetType _callContext;
  late TagBottomSheetType _bottomSheetViewType;

  bool _isNextButtonEnabled = false;
  bool _isUpdateButtonEnabled = false;

  // 변경된 태그 이름과 색상
  late String _updateTagName;
  late int _updateTagColorIndex;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();
    _focusNode = FocusNode();
    _utxoTags = [];
    _createdUtxoTags = [];
    _prevSelectedUtxoTagNames = [];
    _updateTagName = '';
    _updateTagColorIndex = 0;

    _callContext = widget.type;
    _bottomSheetViewType = widget.type;

    _utxoTags = List.from(widget.utxoTags);

    if (widget.selectedUtxoTagNames != null) {
      _prevSelectedUtxoTagNames = List.from(widget.selectedUtxoTagNames!);
    }

    if (widget.updateUtxoTag != null) {
      _updateTagName = widget.updateUtxoTag!.name;
      _updateTagColorIndex = widget.updateUtxoTag!.colorIndex;
    }
    _controller.text = _updateTagName;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    _focusNode.requestFocus();
  }

  void _resetTagCreation() {
    setState(() {
      _bottomSheetViewType = TagBottomSheetType.attach;
      _controller.text = '';
      _updateTagName = '';
      _updateTagColorIndex = 0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoconutBottomSheet(
      useIntrinsicHeight: true,
      appBar: CoconutAppBar.buildWithNext(
          isBottom: true,
          context: context,
          onBackPressed: () {
            if (_bottomSheetViewType == TagBottomSheetType.create) {
              _resetTagCreation();
              return;
            }
            Navigator.pop(context);
          },
          onNextPressed: _complete,
          title: TagBottomSheetType.create == _bottomSheetViewType
              ? t.tag_bottom_sheet.title_new_tag
              : t.tag_bottom_sheet.title_edit_tag,
          isActive: _bottomSheetViewType == TagBottomSheetType.create
              ? _controller.text.runes.length <= 30 &&
                  _updateTagName.isNotEmpty &&
                  !_utxoTags.any((tag) => tag.name == _updateTagName) &&
                  !_controller.text.endsWith(' ')
              : _bottomSheetViewType == TagBottomSheetType.attach
                  ? _isNextButtonEnabled
                  : _isUpdateButtonEnabled,
          nextButtonTitle: t.complete),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // 키보드 높이만큼 패딩
            left: 16,
            right: 16,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                _bottomSheetViewType == TagBottomSheetType.attach
                    ? _buildTagSelectionView()
                    : _buildTagCreationView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagSelectionView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Visibility(
          visible: _utxoTags.isNotEmpty,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            constraints: const BoxConstraints(
              minHeight: 30,
              maxHeight: 296,
            ),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  _utxoTags.length,
                  (index) {
                    bool isSelected = _prevSelectedUtxoTagNames.contains(_utxoTags[index].name);
                    Color foregroundColor = tagColorPalette[_utxoTags[index]
                        .colorIndex]; // colorIndex == 8(gray)일 때 화면상으로 잘 보이지 않기 때문에 gray400으로 설정
                    return IntrinsicWidth(
                      child: CoconutChip(
                        minWidth: 40,
                        color:
                            CoconutColors.backgroundColorPaletteDark[_utxoTags[index].colorIndex],
                        hasOpacity: true,
                        borderColor: foregroundColor,
                        label: '#${_utxoTags[index].name}',
                        labelSize: 12,
                        labelColor: foregroundColor,
                        isSelected: isSelected,
                        onTap: () {
                          final tag = _utxoTags[index].name;
                          setState(() {
                            if (_prevSelectedUtxoTagNames.contains(tag)) {
                              _prevSelectedUtxoTagNames.remove(tag);
                            } else {
                              if (_prevSelectedUtxoTagNames.length == 5) {
                                CoconutToast.showToast(
                                  context: context,
                                  isVisibleIcon: true,
                                  text: t.tag_bottom_sheet.max_tag_count,
                                  seconds: 2,
                                );
                                return;
                              }
                              _prevSelectedUtxoTagNames.add(tag);
                            }
                            _checkNextButtonEnabled();
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        // Create new tag button
        CustomUnderlinedButton(
          text: t.tag_bottom_sheet.add_new_tag,
          fontSize: 14,
          onTap: () {
            setState(() {
              _bottomSheetViewType = TagBottomSheetType.create;
              _focusNode.requestFocus();
            });
          },
        ),
      ],
    );
  }

  Widget _buildTagCreationView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: CustomTagChipColorButton(
                colorIndex: widget.updateUtxoTag?.colorIndex ?? 0,
                isCreate: widget.updateUtxoTag == null,
                onTap: (index) {
                  _updateTagColorIndex = index;
                  _checkUpdateButtonEnabled();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomLimitTextField(
                controller: _controller,
                focusNode: _focusNode,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text(
                    "#",
                    style: CoconutTypography.body3_12,
                  ),
                ),
                onChanged: (text) => _onTextChanged(text),
                onClear: () {
                  setState(() {
                    _controller.clear();
                    _updateTagName = '';
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onTextChanged(text) {
    {
      String updatedText = text;

      if (Platform.isIOS) {
        if (text.startsWith(' ')) {
          updatedText = text.trimLeft();
        }
        if (text.contains('#')) {
          updatedText = updatedText.replaceAll('#', '');
        }
      } else {
        if (text.startsWith(' ')) {
          updatedText = '';
        } else if (text.contains('#')) {
          updatedText = updatedText.replaceAll('#', '');
        }
      }

      // 글자 수 제한
      if (updatedText.runes.length > 30) {
        updatedText = String.fromCharCodes(updatedText.runes.take(30));
      }

      if (updatedText.endsWith(' ')) {
        updatedText = updatedText.trimRight();
      }

      // TextEditingController의 값을 안전하게 업데이트
      if (_controller.text != updatedText) {
        _controller.value = TextEditingValue(
          text: updatedText,
          selection: TextSelection.collapsed(offset: updatedText.length),
        );
      }

      setState(() {
        _updateTagName = updatedText;
      });

      if (_callContext == TagBottomSheetType.update) {
        _checkUpdateButtonEnabled();
      }
    }
  }

  void _checkNextButtonEnabled() {
    if (widget.utxoTags.length != _utxoTags.length) return;
    final prevTags = widget.selectedUtxoTagNames ?? [];
    setState(() {
      _isNextButtonEnabled = _prevSelectedUtxoTagNames.length != prevTags.length ||
          _prevSelectedUtxoTagNames.length == prevTags.length &&
              !Set.from(prevTags).containsAll(_prevSelectedUtxoTagNames);
    });
  }

  /// update type 에서 완료 버튼 활성화 여부 업데이트 함수
  void _checkUpdateButtonEnabled() {
    final prevTag = widget.updateUtxoTag?.name ?? '';
    final prevColorIndex = widget.updateUtxoTag?.colorIndex ?? 0;
    setState(() {
      _isUpdateButtonEnabled = _controller.text.runes.length <= 30 &&
              _updateTagName.isNotEmpty &&
              !_controller.text.endsWith(' ') &&
              _updateTagName != prevTag &&
              !_utxoTags.any((tag) => tag.name == _updateTagName) ||
          _updateTagName == prevTag && _updateTagColorIndex != prevColorIndex;
    });
  }

  void _complete() {
    switch (_callContext) {
      case TagBottomSheetType.attach:
        if (_bottomSheetViewType == TagBottomSheetType.create) {
          _handleCreateTag();
          _bottomSheetViewType = TagBottomSheetType.attach;
          _isNextButtonEnabled = true;
        } else if (_bottomSheetViewType == TagBottomSheetType.attach) {
          widget.onSelected?.call(_prevSelectedUtxoTagNames, _createdUtxoTags);
          Navigator.pop(context);
        }
        break;
      case TagBottomSheetType.create:
        _handleCreateTag();
        widget.onUpdated?.call(_createdUtxoTags.first);
        Navigator.pop(context);
        break;
      case TagBottomSheetType.update:
        _handleUpdateTag();
        break;
      default:
        break;
    }
  }

  void _handleCreateTag() {
    final createdUtxoTag = UtxoTag(
      id: const Uuid().v4(),
      walletId: 0,
      name: _updateTagName,
      colorIndex: _updateTagColorIndex,
    );

    setState(() {
      _utxoTags.insert(0, createdUtxoTag);
      _createdUtxoTags.add(createdUtxoTag);
      if (_prevSelectedUtxoTagNames.length < 5) {
        _prevSelectedUtxoTagNames.add(_updateTagName);
      }
    });
  }

  void _handleUpdateTag() {
    if (widget.updateUtxoTag != null) {
      final updateUtxoTag = widget.updateUtxoTag?.copyWith(
        name: _updateTagName,
        colorIndex: _updateTagColorIndex,
      );
      widget.onUpdated?.call(updateUtxoTag!);
      Navigator.pop(context);
    }
  }
}
