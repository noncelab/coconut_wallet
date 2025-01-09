import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/button/custom_appbar_button.dart';
import 'package:coconut_wallet/widgets/textfield/custom_limit_text_field.dart';
import 'package:flutter/material.dart';

/// [MemoBottomSheetContainer] : 트랜잭션 메모 등록/수정 BottomSheet
/// [originalMemo] : 변경할 트랜잭션 메모, default empty
/// [onComplete] : 수정/등록할 메모 반환 콜백
class MemoBottomSheetContainer extends StatefulWidget {
  final String originalMemo;
  final Function(String) onComplete;
  const MemoBottomSheetContainer({
    super.key,
    required this.originalMemo,
    required this.onComplete,
  });

  @override
  State<MemoBottomSheetContainer> createState() =>
      _MemoBottomSheetContainerState();
}

class _MemoBottomSheetContainerState extends State<MemoBottomSheetContainer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// [CustomLimitTextField]에서 입력된 메모
  String _updateMemo = '';

  bool get _isCompleteButtonEnabled {
    return _updateMemo != widget.originalMemo ||
        (widget.originalMemo.isNotEmpty && _updateMemo.isEmpty);
  }

  @override
  void initState() {
    super.initState();
    _updateMemo = widget.originalMemo;

    _controller.text = _updateMemo;
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
                    '거래 메모',
                    style: Styles.body2Bold.copyWith(
                      fontSize: 16,
                    ),
                  ),
                  CustomAppbarButton(
                    isActive: _isCompleteButtonEnabled,
                    isActivePrimaryColor: false,
                    text: '완료',
                    onPressed: () {
                      widget.onComplete(_updateMemo);
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
                    onChanged: (text) {
                      setState(() {
                        _updateMemo = text;
                      });
                    },
                    onClear: () {
                      setState(() {
                        _controller.clear();
                        _updateMemo = '';
                      });
                    },
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
