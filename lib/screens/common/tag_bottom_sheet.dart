import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/button/custom_tag_chip_color_button.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:uuid/uuid.dart';

/// [TagBottomSheetType]
/// - [select] : 태그 목록 선택 변경 및 새 태그 생성
/// - [create] : 새 태그 생성
/// - [update] : 선택된 태그 수정
enum TagBottomSheetType { select, create, update }

/// [TagBottomSheet] : 태그 선택 변경, 태그 수정, 태그 생성 BottomSheet
/// [type] : BottomSheet Type
/// [utxoTags] : 지갑에 생성된 UtxoTag 전체 목록
/// [selectedUtxoTagNames] : select type only, 선택된 UTXO name 목록
/// [updateUtxoTag] : update type only, 선택된 태그를 수정하기 위한 UtxoTag 객체
/// [onSelected] : select type only, 태그 목록 선택 변경 및 새태그 생성 완료 콜백
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
  /// UtxoTag 전체 목록 - select type 에서 변경될 수 있음
  List<UtxoTag> _utxoTags = [];

  /// UtxoTag 생성 목록 - select type 에서 변경될 수 있음
  final List<UtxoTag> _createdUtxoTags = [];

  /// 선택된 UTXO 의 UtxoTag name 목록 - select type 에서 변경될 수 있음
  List<String> _selectedUtxoTagNames = [];

  /// BottomSheet 상태 - select type 에서 create 로 변경될 수 있음
  TagBottomSheetType _type = TagBottomSheetType.select;

  /// [TagBottomSheetType.select] 에서 [TagBottomSheetType.create] 호출할 때 사용
  bool _isTwoDepth = false;

  /// select type 에서 완료 버튼 활성화 여부
  bool _isSelectButtonEnabled = false;

  /// 선택된 UtxoTag - update type 에서 변경될 수 있음
  UtxoTag? _updateUtxoTag;

  /// update type 에서 완료 버튼 활성화 여부
  bool _isUpdateButtonEnabled = false;

  /// [CoconutTextField] 에서 변경된 TagName
  String _updateTagName = '';

  /// [CustomTagChipColorButton] 에서 변경된 TagColorIndex
  int _updateTagColorIndex = 0;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _utxoTags = List.from(widget.utxoTags);

    if (widget.selectedUtxoTagNames != null) {
      _selectedUtxoTagNames = List.from(widget.selectedUtxoTagNames!);
    }

    if (widget.updateUtxoTag != null) {
      _updateTagName = widget.updateUtxoTag!.name;
      _updateTagColorIndex = widget.updateUtxoTag!.colorIndex;
      _updateUtxoTag = widget.updateUtxoTag;
    }
    _controller.text = _updateTagName;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    _focusNode.requestFocus();
  }

  _resetCreate() {
    setState(() {
      _isTwoDepth = false;
      _type = TagBottomSheetType.select;
      _controller.text = '';
      _updateTagName = '';
      _updateTagColorIndex = 0;
    });
  }

  /// select type 에서 완료 버튼 활성화 여부 업데이트 함수
  _checkSelectButtonEnabled() {
    if (widget.utxoTags.length != _utxoTags.length) return;
    final prevTags = widget.selectedUtxoTagNames ?? [];
    setState(() {
      _isSelectButtonEnabled =
          _selectedUtxoTagNames.length != prevTags.length ||
              _selectedUtxoTagNames.length == prevTags.length &&
                  !Set.from(prevTags).containsAll(_selectedUtxoTagNames);
    });
  }

  /// update type 에서 완료 버튼 활성화 여부 업데이트 함수
  _checkUpdateButtonEnabled() {
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

  bool _checkRightButtonActive() {
    if (_type == TagBottomSheetType.select) {
      return _isSelectButtonEnabled;
    } else if (_type == TagBottomSheetType.create) {
      return _controller.text.runes.length <= 30 &&
          _updateTagName.isNotEmpty &&
          !_utxoTags.any((tag) => tag.name == _updateTagName) &&
          !_controller.text.endsWith(' ');
    } else {
      return _isUpdateButtonEnabled;
    }
  }

  void _onNextPressed() {
    if (_type == TagBottomSheetType.select) {
      widget.onSelected?.call(_selectedUtxoTagNames, _createdUtxoTags);
      Navigator.pop(context);
    } else if (_type == TagBottomSheetType.create) {
      final id = const Uuid().v4();
      final createdUtxoTag = UtxoTag(
        id: id,
        walletId: 0,
        name: _updateTagName,
        colorIndex: _updateTagColorIndex,
      );

      setState(() {
        _utxoTags.insert(0, createdUtxoTag);
        _createdUtxoTags.add(createdUtxoTag);
        if (_selectedUtxoTagNames.length < 5) {
          _selectedUtxoTagNames.add(_updateTagName);
        }
        _isSelectButtonEnabled = true;
      });
      if (_isTwoDepth) {
        _resetCreate();
      } else {
        widget.onUpdated?.call(createdUtxoTag);
        Navigator.pop(context);
      }
    } else {
      if (widget.updateUtxoTag != null) {
        int tagIndex = _utxoTags.indexOf(widget.updateUtxoTag!);

        _utxoTags[tagIndex] = _utxoTags[tagIndex]
            .copyWith(name: _updateTagName, colorIndex: _updateTagColorIndex);

        final updateUtxoTag = _updateUtxoTag?.copyWith(
          name: _updateTagName,
          colorIndex: _updateTagColorIndex,
        );

        widget.onUpdated?.call(updateUtxoTag!);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CoconutBottomSheet(
          useIntrinsicHeight: true,
          bottomMargin: TagBottomSheetType.select == _type ? 84 : 8,
          appBar: CoconutAppBar.buildWithNext(
            title: TagBottomSheetType.create == _type
                ? t.tag_bottom_sheet.title_new_tag
                : t.tag_bottom_sheet.title_edit_tag,
            context: context,
            brightness: Brightness.dark,
            isBottom: true,
            isActive: _checkRightButtonActive(),
            nextButtonTitle: t.complete,
            onNextPressed: _onNextPressed,
            onBackPressed: () {
              if (_isTwoDepth) {
                _resetCreate();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          body: Container(
            padding: const EdgeInsets.all(16),
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_type == TagBottomSheetType.select) ...{
                  // Tags
                  Visibility(
                    visible: _utxoTags.isNotEmpty,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          _utxoTags.length,
                          (index) => IntrinsicWidth(
                            child: GestureDetector(
                              onTap: () {
                                final tag = _utxoTags[index].name;
                                setState(() {
                                  if (_selectedUtxoTagNames.contains(tag)) {
                                    _selectedUtxoTagNames.remove(tag);
                                  } else {
                                    if (_selectedUtxoTagNames.length == 5) {
                                      CustomToast.showToast(
                                          context: context,
                                          text:
                                              t.tag_bottom_sheet.max_tag_count,
                                          seconds: 2);
                                      return;
                                    }
                                    _selectedUtxoTagNames.add(tag);
                                  }
                                  _checkSelectButtonEnabled();
                                });
                              },
                              child: CoconutTagChip(
                                tag: _utxoTags[index].name,
                                color: CoconutColors.backgroundColorPaletteDark[
                                    _utxoTags[index].colorIndex],
                                status: _selectedUtxoTagNames
                                        .contains(_utxoTags[index].name)
                                    ? CoconutChipStatus.selected
                                    : CoconutChipStatus.unselected,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Create new tag button
                  CustomUnderlinedButton(
                    text: '새 태그 만들기',
                    fontSize: 14,
                    onTap: () {
                      setState(() {
                        _isTwoDepth = true;
                        _type = TagBottomSheetType.create;
                        _focusNode.requestFocus();
                      });
                    },
                  ),
                } else ...{
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 16, bottom: 16),
                        child: CustomTagChipColorButton(
                          colorIndex: widget.updateUtxoTag?.colorIndex ?? 0,
                          isCreate: widget.updateUtxoTag == null,
                          onTap: (index) {
                            _updateTagColorIndex = index;
                            _checkUpdateButtonEnabled();
                          },
                        ),
                      ),
                      Expanded(
                        child: CoconutTextField(
                          brightness: Brightness.dark,
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLength: 30,
                          maxLines: 1,
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Text(
                              "#",
                              style: Styles.body2,
                            ),
                          ),
                          suffix: GestureDetector(
                            onTap: () {
                              _controller.text = '';
                              _updateTagName = '';
                              _focusNode.requestFocus();
                              setState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 13),
                              child: SvgPicture.asset(
                                'assets/svg/text-field-clear.svg',
                                width: 16,
                                height: 16,
                                colorFilter: ColorFilter.mode(
                                  _updateTagName.isEmpty
                                      ? CoconutColors.onGray300(Brightness.dark)
                                      : _updateTagName.runes.length == 30
                                          ? CoconutColors.red
                                          : CoconutColors.onBlack(
                                              Brightness.dark),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          onChanged: (text) {
                            if (Platform.isIOS) {
                              if (text.startsWith(' ')) {
                                text = text.trim();
                              }

                              if (text.contains('#')) {
                                text = text.replaceAll('#', '');
                              }

                              if (text.endsWith(' ')) {
                                _updateTagName = text.trimRight();
                                _isSelectButtonEnabled = false;
                              } else {
                                _updateTagName = text;
                              }

                              _controller.text = text;
                            } else {
                              if (text.startsWith(' ')) {
                                _updateTagName = '';
                                _controller.text = _updateTagName;
                              } else if (text.contains('#')) {
                                _updateTagName = text.replaceAll('#', '');
                                _controller.text = _updateTagName;
                              } else if (text.runes.length > 30) {
                                _updateTagName =
                                    String.fromCharCodes(text.runes.take(30));
                                _controller.text = _updateTagName;
                              } else {
                                _updateTagName = text;
                              }

                              if (_updateTagName.endsWith(' ')) {
                                _updateTagName = _updateTagName.trimRight();
                                _isSelectButtonEnabled = false;
                              }
                            }

                            if (_type == TagBottomSheetType.update) {
                              _checkUpdateButtonEnabled();
                            }
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
