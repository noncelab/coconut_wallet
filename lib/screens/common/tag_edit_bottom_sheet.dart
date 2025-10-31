import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/widgets/button/custom_tag_chip_color_button.dart';
import 'package:coconut_wallet/widgets/textfield/custom_limit_text_field.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class TagEditBottomSheet extends StatefulWidget {
  final int walletId;
  final List<UtxoTag> existingTags;
  final UtxoTag? updateUtxoTag; // 수정 모드일 때 사용
  final Function(UtxoTag) onTagCreated;

  const TagEditBottomSheet({
    super.key,
    required this.walletId,
    required this.existingTags,
    this.updateUtxoTag,
    required this.onTagCreated,
  });

  @override
  State<TagEditBottomSheet> createState() => _TagEditBottomSheetState();
}

class _TagEditBottomSheetState extends State<TagEditBottomSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  String _tagName = '';
  int _tagColorIndex = 0;
  bool _isButtonActive = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    // 수정 모드인 경우 기존 값으로 초기화
    if (widget.updateUtxoTag != null) {
      _tagName = widget.updateUtxoTag!.name;
      _tagColorIndex = widget.updateUtxoTag!.colorIndex;
      _controller.text = _tagName;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    }

    // 포커스 요청
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      _focusNode.requestFocus();
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
    final isUpdateMode = widget.updateUtxoTag != null;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return CoconutBottomSheet(
      useIntrinsicHeight: true,
      appBar: CoconutAppBar.build(
        isBottom: true,
        context: context,
        onBackPressed: () => Navigator.pop(context),
        title: isUpdateMode ? t.tag_bottom_sheet.title_edit_tag : t.tag_bottom_sheet.title_new_tag,
      ),
      bottomMargin: 20,
      body: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? keyboardHeight : 0, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: CustomTagChipColorButton(
                    colorIndex: _tagColorIndex,
                    isCreate: !isUpdateMode,
                    onTap: (index) {
                      setState(() {
                        _tagColorIndex = index;
                      });
                      _checkButtonEnabled();
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
                      child: Text("#", style: CoconutTypography.body3_12),
                    ),
                    onChanged: _onTextChanged,
                    onClear: () {
                      setState(() {
                        _controller.clear();
                        _tagName = '';
                      });
                      _checkButtonEnabled();
                    },
                  ),
                ),
              ],
            ),
            CoconutLayout.spacing_800h,
            CoconutButton(
              onPressed: _createTag,
              text: t.complete,
              isActive: _isButtonActive,
              backgroundColor: CoconutColors.white,
            ),
          ],
        ),
      ),
    );
  }

  void _onTextChanged(String text) {
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
      _tagName = updatedText;
    });

    _checkButtonEnabled();
  }

  void _checkButtonEnabled() {
    final isUpdateMode = widget.updateUtxoTag != null;

    bool isActive = false;

    if (isUpdateMode) {
      // 수정 모드: 기존 값과 다르면 활성화
      final originalTag = widget.updateUtxoTag!;
      isActive =
          _tagName.isNotEmpty &&
          (_tagName != originalTag.name || _tagColorIndex != originalTag.colorIndex) &&
          !widget.existingTags.any((tag) => tag.name == _tagName && tag.id != originalTag.id);
    } else {
      // 생성 모드: 유효한 이름이고 중복되지 않으면 활성화
      isActive =
          _tagName.isNotEmpty &&
          !_controller.text.endsWith(' ') &&
          !widget.existingTags.any((tag) => tag.name == _tagName);
    }

    setState(() {
      _isButtonActive = isActive;
    });
  }

  void _createTag() {
    final isUpdateMode = widget.updateUtxoTag != null;

    final tag =
        isUpdateMode
            ? widget.updateUtxoTag!.copyWith(name: _tagName, colorIndex: _tagColorIndex)
            : UtxoTag(id: const Uuid().v4(), walletId: widget.walletId, name: _tagName, colorIndex: _tagColorIndex);

    widget.onTagCreated(tag);
    Navigator.pop(context);
  }
}
