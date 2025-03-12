import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/button/custom_appbar_button.dart';
import 'package:coconut_wallet/widgets/textfield/custom_limit_text_field.dart';
import 'package:flutter/material.dart';

/// [TextFieldBottomSheet] : 트랜잭션 메모 등록/수정, 수수료 직접 입력 등
/// [originalText] : 변경할 트랜잭션 메모, default empty
/// [onComplete] : 수정/등록할 메모 반환 콜백
class TextFieldBottomSheet extends StatefulWidget {
  final String? originalText;
  final Function(String) onComplete;
  final String title;
  final String placeholder;
  final String? completeButtonText;
  final TextInputType keyboardType;
  final bool visibleTextLimit;

  const TextFieldBottomSheet(
      {super.key,
      this.originalText = '',
      required this.onComplete,
      this.title = '',
      this.placeholder = '',
      this.completeButtonText,
      this.keyboardType = TextInputType.text,
      this.visibleTextLimit = true});

  @override
  State<TextFieldBottomSheet> createState() => _TextFieldBottomSheetState();
}

class _TextFieldBottomSheetState extends State<TextFieldBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// [CustomLimitTextField]에서 입력된 메모
  String _updateText = '';

  bool get _isCompleteButtonEnabled {
    return _updateText != widget.originalText || _updateText.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _updateText = widget.originalText ?? '';

    _controller.text = _updateText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    _focusNode.requestFocus();
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
                      Navigator.pop(context);
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      color: MyColors.white,
                      size: 22,
                    ),
                  ),
                  Text(
                    widget.title,
                    style: Styles.body2Bold.copyWith(
                      fontSize: 16,
                    ),
                  ),
                  CustomAppbarButton(
                    isActive: _isCompleteButtonEnabled,
                    isActivePrimaryColor: false,
                    text: widget.completeButtonText ?? t.complete,
                    onPressed: () {
                      widget.onComplete(_updateText);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // TextField
              Column(
                mainAxisSize: MainAxisSize.min, // 컨텐츠 크기에 맞추기
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // TextField
                  CustomLimitTextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: widget.keyboardType,
                    onChanged: (text) {
                      setState(() {
                        _updateText = text;
                      });
                    },
                    onClear: () {
                      setState(() {
                        _controller.clear();
                        _updateText = '';
                      });
                    },
                    placeholder: widget.placeholder,
                    visibleTextLimit: widget.visibleTextLimit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
