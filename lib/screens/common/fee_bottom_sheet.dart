import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

class FeeBottomSheet extends StatefulWidget {
  final int? fee;
  final Function(int) onComplete;
  const FeeBottomSheet({
    super.key,
    required this.fee,
    required this.onComplete,
  });

  @override
  State<FeeBottomSheet> createState() => _FeeBottomSheetState();
}

class _FeeBottomSheetState extends State<FeeBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// [CoconutTextField]에서 입력된 메모
  int _updateFee = 0;

  @override
  void initState() {
    super.initState();
    _updateFee = widget.fee ?? 0;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    _controller.text = _updateFee > 0 ? _updateFee.toString() : '';
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
          title: t.fee,
          context: context,
          brightness: Brightness.dark,
          isBottom: true,
          isActive: _updateFee > 0,
          nextButtonTitle: t.complete,
          onNextPressed: () {
            widget.onComplete(_updateFee);
            Navigator.pop(context);
          },
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: CoconutTextField(
            brightness: Brightness.dark,
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 1,
            textInputType: TextInputType.number,
            descriptionText: t.text_field.enter_fee_as_natural_number,
            onChanged: (text) {
              try {
                _updateFee = int.parse(text);
                setState(() {});
              } catch (_) {}
            },
          ),
        ),
      ),
    );
  }
}
