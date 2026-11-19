import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutTextField;
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_move_parts.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/single_field_fixed_bottom_sheet_body.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ArkReceiveAmountResult {
  final bool didEdit;
  final int? amountInSats;
  final String memo;

  const ArkReceiveAmountResult({required this.didEdit, required this.amountInSats, this.memo = ''});
}

/// 아크 받기 금액과 라이트닝 메모(인보이스에 담겨 보내는 사람에게 보임). feat/ark에서 가져옴
class ArkReceiveAmountSheet {
  static Future<ArkReceiveAmountResult?> show({
    required BuildContext context,
    required int? initialAmountSats,
    required String initialMemo,
    required String screenName,
  }) {
    return CommonBottomSheets.showBottomSheet<ArkReceiveAmountResult>(
      context: context,
      title: t.ark_wallet.set_amount,
      screenName: screenName,
      showCloseButton: true,
      showDragHandle: true,
      keyboardBottomPadding: 0,
      titlePadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: _ReceiveAmountSheet(initialAmountSats: initialAmountSats, initialMemo: initialMemo),
    );
  }
}

class _ReceiveAmountSheet extends StatefulWidget {
  const _ReceiveAmountSheet({required this.initialAmountSats, required this.initialMemo});

  final int? initialAmountSats;
  final String initialMemo;

  @override
  State<_ReceiveAmountSheet> createState() => _ReceiveAmountSheetState();
}

class _ReceiveAmountSheetState extends State<_ReceiveAmountSheet> {
  late int? _amountSats = widget.initialAmountSats;
  late final TextEditingController _memoController = TextEditingController(text: widget.initialMemo);
  final FocusNode _memoFocusNode = FocusNode();

  String get _memo => _memoController.text.trim();

  bool get _isChanged => _amountSats != widget.initialAmountSats || _memo != widget.initialMemo;

  @override
  void dispose() {
    _memoController.dispose();
    _memoFocusNode.dispose();
    super.dispose();
  }

  void _onComplete() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, ArkReceiveAmountResult(didEdit: _isChanged, amountInSats: _amountSats, memo: _memo));
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final amountField = ArkMoveAmountBox(
      amountSats: _amountSats,
      onAmount: (sats) => setState(() => _amountSats = sats),
      autofocus: true,
      backgroundColor: context.coconutColors.surfaceBottomSheet,
    );

    final content = Column(
      children: [
        amountField,
        CoconutLayout.spacing_200h,
        CoconutTextField(
          controller: _memoController,
          focusNode: _memoFocusNode,
          onChanged: (_) => setState(() {}),
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          placeholderText: t.ark_wallet.lightning_memo_hint,
          backgroundColor: context.coconutColors.surfaceBottomSheet,
          isLengthVisible: false,
          maxLength: 100,
          maxLines: 1,
          enableSuggestions: isAndroid,
          clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
          onClear: () => setState(_memoController.clear),
        ),
        CoconutLayout.spacing_200h,
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              t.ark_wallet.lightning_memo_note,
              style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
            ),
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleFieldFixedBottomSheetBody(
        collapsedHeight: 328,
        keyboardContentHeight: 208,
        isCompleteEnabled: _isChanged,
        onComplete: _onComplete,
        completeLabel: t.done,
        textField: content,
      ),
    );
  }
}
