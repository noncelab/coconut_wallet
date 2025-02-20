import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// [MemoBottomSheet] : 트랜잭션 메모 등록/수정 BottomSheet
/// [originalMemo] : 변경할 트랜잭션 메모, default empty
/// [onComplete] : 수정/등록할 메모 반환 콜백
class MemoBottomSheet extends StatefulWidget {
  final String originalMemo;
  final Function(String) onComplete;
  const MemoBottomSheet({
    super.key,
    required this.originalMemo,
    required this.onComplete,
  });

  @override
  State<MemoBottomSheet> createState() => _MemoBottomSheetState();
}

class _MemoBottomSheetState extends State<MemoBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// [CoconutTextField]에서 입력된 메모
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
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: CoconutBottomSheet(
        useIntrinsicHeight: true,
        bottomMargin: 16,
        appBar: CoconutAppBar.buildWithNext(
          title: t.tx_memo,
          context: context,
          isBottom: true,
          isActive: _isCompleteButtonEnabled,
          nextButtonTitle: t.complete,
          onNextPressed: () {
            widget.onComplete(_updateMemo);
            Navigator.pop(context);
          },
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: CoconutTextField(
            brightness: Brightness.dark,
            controller: _controller,
            focusNode: _focusNode,
            maxLength: 30,
            maxLines: 1,
            suffix: GestureDetector(
              onTap: () {
                _controller.clear();
                _updateMemo = '';
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
                    _updateMemo.runes.length == 30
                        ? CoconutColors.red
                        : CoconutColors.onBlack(Brightness.dark),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            onChanged: (text) {
              _updateMemo = text;
              setState(() {});
            },
          ),
        ),
      ),
    );
  }
}
