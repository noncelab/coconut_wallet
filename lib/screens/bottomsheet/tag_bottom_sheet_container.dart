import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/button/custom_appbar_button.dart';
import 'package:coconut_wallet/widgets/custom_tag_chip.dart';
import 'package:coconut_wallet/widgets/button/custom_tag_chip_color_button.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/textfield/custom_limit_text_field.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/model/utxo.dart';

enum TagBottomSheetType { select, create, manage }

class TagBottomSheetContainer extends StatefulWidget {
  final TagBottomSheetType type;
  final Function(List<UtxoTag>?, UtxoTag?, UTXO?) onComplete;
  final List<UtxoTag> utxoTags;
  final UTXO? selectUtxo;
  final UtxoTag? manageUtxoTag;
  const TagBottomSheetContainer({
    super.key,
    required this.type,
    required this.onComplete,
    required this.utxoTags,
    this.selectUtxo,
    this.manageUtxoTag,
  });

  @override
  State<TagBottomSheetContainer> createState() =>
      _TagBottomSheetContainerState();
}

class _TagBottomSheetContainerState extends State<TagBottomSheetContainer> {
  List<UtxoTag> _updateUtxoTags = [];
  UtxoTag? _manageUtxoTag;
  UTXO? _selectUtxo;
  List<String> _selectedTags = [];

  TagBottomSheetType _type = TagBottomSheetType.select;
  bool _isSelectButtonEnabled = false;
  bool _isManageButtonEnabled = false;

  /// [TagBottomSheetType.select] 에서 [TagBottomSheetType.create] 호출할 때 사용
  bool _isTwoDepth = false;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _updateTagName = '';
  int _updateTagColorIndex = 0;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _updateUtxoTags = List.from(widget.utxoTags);

    if (widget.selectUtxo != null) {
      _selectUtxo = widget.selectUtxo!;
      if (widget.selectUtxo!.tags != null) {
        _selectedTags = List.from(widget.selectUtxo!.tags!);
      }
    }

    if (widget.manageUtxoTag != null) {
      _updateTagName = widget.manageUtxoTag!.name;
      _updateTagColorIndex = widget.manageUtxoTag!.colorIndex;
      _manageUtxoTag = widget.manageUtxoTag;
    }
    _controller.text = '#$_updateTagName';
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  _resetCreate() {
    setState(() {
      _isTwoDepth = false;
      _type = TagBottomSheetType.select;
      _controller.text = '#';
      _updateTagName = '';
      _updateTagColorIndex = 0;
    });
  }

  _checkSelectButtonEnabled() {
    if (widget.utxoTags.length != _updateUtxoTags.length) return;
    final prevTags = widget.selectUtxo?.tags ?? [];
    setState(() {
      _isSelectButtonEnabled = _selectedTags.length != prevTags.length ||
          _selectedTags.length == prevTags.length &&
              !Set.from(prevTags).containsAll(_selectedTags);
    });
  }

  _checkManageButtonEnabled() {
    final prevTag = widget.manageUtxoTag?.name ?? '';
    final prevColorIndex = widget.manageUtxoTag?.colorIndex ?? 0;
    setState(() {
      _isManageButtonEnabled = _updateTagName.isNotEmpty &&
              _updateTagName != prevTag &&
              !_updateUtxoTags.any((tag) => tag.name == _updateTagName) ||
          _updateTagName == prevTag && _updateTagColorIndex != prevColorIndex;
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
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 184,
          maxHeight: 278,
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: const BoxDecoration(
          color: MyColors.bottomSheetBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close, Title, Complete Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isTwoDepth) {
                        _resetCreate();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      color: MyColors.white,
                      size: 22,
                    ),
                  ),
                  Text(
                    TagBottomSheetType.create == _type ? '새 태그' : '태그 편집',
                    style: Styles.body2Bold,
                  ),
                  if (_type == TagBottomSheetType.select) ...{
                    CustomAppbarButton(
                      isActive: _isSelectButtonEnabled,
                      isActivePrimaryColor: false,
                      text: '완료',
                      onPressed: () {
                        _selectUtxo?.tags = _selectedTags;
                        widget.onComplete
                            .call(_updateUtxoTags, _manageUtxoTag, _selectUtxo);
                        Navigator.pop(context);
                      },
                    ),
                  } else if (_type == TagBottomSheetType.create) ...{
                    CustomAppbarButton(
                      isActive: _updateTagName.isNotEmpty &&
                          !_updateUtxoTags
                              .any((tag) => tag.name == _updateTagName),
                      isActivePrimaryColor: false,
                      text: '완료',
                      onPressed: () {
                        final createUtxoTag = UtxoTag(
                          id: '',
                          walletId: 0,
                          name: _updateTagName,
                          colorIndex: _updateTagColorIndex,
                        );

                        setState(() {
                          _updateUtxoTags.insert(0, createUtxoTag);
                          _isSelectButtonEnabled = true;
                        });
                        if (_isTwoDepth) {
                          _resetCreate();
                        } else {
                          widget.onComplete(
                              _updateUtxoTags, createUtxoTag, _selectUtxo);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  } else ...{
                    CustomAppbarButton(
                      isActive: _isManageButtonEnabled,
                      isActivePrimaryColor: false,
                      text: '완료',
                      onPressed: () {
                        if (widget.manageUtxoTag != null) {
                          int tagIndex =
                              _updateUtxoTags.indexOf(widget.manageUtxoTag!);

                          _updateUtxoTags[tagIndex] = _updateUtxoTags[tagIndex]
                              .copyWith(
                                  name: _updateTagName,
                                  colorIndex: _updateTagColorIndex);

                          final updateUtxoTag = _manageUtxoTag?.copyWith(
                            name: _updateTagName,
                            colorIndex: _updateTagColorIndex,
                          );

                          widget.onComplete(
                              _updateUtxoTags, updateUtxoTag, _selectUtxo);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  },
                ],
              ),
              const SizedBox(height: 24),
              if (_type == TagBottomSheetType.select) ...{
                // Tags
                Container(
                  constraints: const BoxConstraints(
                    minHeight: 30,
                    maxHeight: 124,
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        _updateUtxoTags.length,
                        (index) => IntrinsicWidth(
                          child: GestureDetector(
                            onTap: () {
                              final tag = _updateUtxoTags[index].name;
                              setState(() {
                                if (_selectedTags.contains(tag)) {
                                  _selectedTags.remove(tag);
                                } else {
                                  if (_selectedTags.length == 5) {
                                    CustomToast.showToast(
                                        context: context,
                                        text: "태그는 최대 5개 지정할 수 있어요",
                                        seconds: 2);
                                    return;
                                  }
                                  _selectedTags.add(tag);
                                }
                                _checkSelectButtonEnabled();
                              });
                            },
                            child: CustomTagChip(
                              tag: _updateUtxoTags[index].name,
                              colorIndex: _updateUtxoTags[index].colorIndex,
                              type: _selectedTags
                                      .contains(_updateUtxoTags[index].name)
                                  ? CustomTagChipType.select
                                  : CustomTagChipType.disable,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Create new tag button
                CustomUnderlinedButton(
                  text: '새 태그 만들기',
                  onTap: () {
                    setState(() {
                      _isTwoDepth = true;
                      _type = TagBottomSheetType.create;
                      _focusNode.requestFocus();
                    });
                  },
                ),
              } else ...{
                // TextField
                Column(
                  mainAxisSize: MainAxisSize.min, // 컨텐츠 크기에 맞추기
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Color Selector, TextField
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: CustomTagChipColorButton(
                            colorIndex: widget.manageUtxoTag?.colorIndex ?? 0,
                            onTap: (index) {
                              _updateTagColorIndex = index;
                              _checkManageButtonEnabled();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomLimitTextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: (text) {
                              _updateTagName =
                                  text.replaceAll('#', '').replaceAll(' ', '');
                              if (text.isEmpty) {
                                _controller.text = '#';
                              } else if (text.substring(1).contains('#') ||
                                  text.substring(1).contains(' ')) {
                                _controller.text = '#$_updateTagName';
                              }

                              if (_type == TagBottomSheetType.manage) {
                                _checkManageButtonEnabled();
                              }

                              setState(() {});
                            },
                            onClear: () {
                              setState(() {
                                _updateTagName = '';
                                _controller.text = '#';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}
