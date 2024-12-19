import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/button/custom_appbar_button.dart';
import 'package:coconut_wallet/widgets/textfield/custom_limit_text_field.dart';
import 'package:flutter/material.dart';

class MemoBottomSheetContainer extends StatefulWidget {
  final String updateMemo;
  final Function(String) onComplete;
  const MemoBottomSheetContainer({
    super.key,
    required this.updateMemo,
    required this.onComplete,
  });

  @override
  State<MemoBottomSheetContainer> createState() =>
      _MemoBottomSheetContainerState();
}

class _MemoBottomSheetContainerState extends State<MemoBottomSheetContainer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _updateMemo = '';

  bool _isCompleteButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _updateMemo = widget.updateMemo;

    _controller.text = _updateMemo;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
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
                  const Text(
                    '거래 메모',
                    style: Styles.body2Bold,
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
                    onChanged: (text) {
                      setState(() {
                        _updateMemo = text;
                        _isCompleteButtonEnabled = _updateMemo.isNotEmpty &&
                            _updateMemo != widget.updateMemo;
                      });
                    },
                    onClear: () {
                      setState(() {
                        _controller.clear();
                        _updateMemo = '';
                        _isCompleteButtonEnabled = false;
                      });
                    },
                  ),

                  // 글자 수 표시
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 4),
                      child: Text(
                        '${_updateMemo.length}/30',
                        style: TextStyle(
                          color: _updateMemo.length == 30
                              ? MyColors.white
                              : MyColors.transparentWhite_50,
                          fontSize: 12,
                          fontFamily: CustomFonts.text.getFontFamily,
                        ),
                      ),
                    ),
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
