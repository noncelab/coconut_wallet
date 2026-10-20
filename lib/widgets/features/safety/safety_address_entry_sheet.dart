import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutTypography, TextColorExtension;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/safety/safety_assist.dart' show AssistAddress;
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/address_scan_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 받는 주소 직접 입력 시트(Assist·Rescue 공용, POLISH H6/I5). 붙여넣기·QR(BIP21) → 정규화한 주소로 닫힌다(취소면 null).
/// [validate]는 입력할 때마다(형식·제외 지갑, 오류 문구 또는 null), [confirm]은 누를 때 한 번(무거운 확인, 오류 문구 또는 null).
Future<String?> showSafetyAddressEntrySheet(
  BuildContext context, {
  required String screenName,
  required String actionText,
  required String? Function(String address) validate,
  required Future<String?> Function(String address) confirm,
  Key? fieldKey,
  Key? actionKey,
}) => CommonBottomSheets.showBottomSheet<String>(
  context: context,
  title: t.premium.destination.enter_address,
  screenName: screenName,
  showDragHandle: true,
  showCloseButton: true,
  child: SafetyAddressEntry(
    actionText: actionText,
    validate: validate,
    confirm: confirm,
    fieldKey: fieldKey,
    actionKey: actionKey,
  ),
);

class SafetyAddressEntry extends StatefulWidget {
  const SafetyAddressEntry({
    super.key,
    required this.actionText,
    required this.validate,
    required this.confirm,
    this.fieldKey,
    this.actionKey,
  });

  final String actionText;
  final String? Function(String address) validate;
  final Future<String?> Function(String address) confirm;
  final Key? fieldKey, actionKey;

  @override
  State<SafetyAddressEntry> createState() => _SafetyAddressEntryState();
}

class _SafetyAddressEntryState extends State<SafetyAddressEntry> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _checking = false;

  /// [SafetyAddressEntry.confirm]이 거절한 주소와 그 이유(그 주소가 입력돼 있는 동안 보인다)
  ({String address, String error})? _rejected;

  String get _address => AssistAddress.normalize(_controller.text);

  String? get _error {
    final address = _address;
    if (address.isEmpty) return null;
    if (address == _rejected?.address) return _rejected!.error;
    return widget.validate(address);
  }

  Future<void> _submit() async {
    final address = _address;
    setState(() => _checking = true);
    String? error;
    try {
      error = await widget.confirm(address);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (!mounted) return;
    if (error != null) {
      vibrateLightDouble();
      setState(() => _rejected = (address: address, error: error!));
      return;
    }
    Navigator.pop(context, address);
  }

  Future<void> _scan() async {
    final scanned = await showAddressScannerBottomSheet(context, title: t.premium.destination.enter_address);
    if (scanned == null || !mounted) return;
    _controller.text = AssistAddress.normalize(scanned); // bitcoin: URI면 주소만
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final error = _error;
    final canSubmit = _address.isNotEmpty && error == null && !_checking;
    // 키보드가 올라와 시트가 줄어도 넘치지 않게 스크롤(GPT M3)
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoconutTextField(
            key: widget.fieldKey,
            controller: _controller,
            focusNode: _focusNode,
            onChanged: (_) => setState(() {}),
            backgroundColor: colors.inputSurface,
            height: 52,
            padding: const EdgeInsets.only(left: 16),
            maxLines: 1,
            placeholderText: t.premium.destination.address_hint,
            clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
            onClear: () => setState(_controller.clear),
            suffixIconAsset: CommonActionIconPath.scan,
            suffixSemanticLabel: t.premium.destination.enter_address,
            suffixIconColor: colors.primaryText,
            onSuffixPressed: _scan,
            isError: error != null,
            errorText: error,
            isErrorTextMultiline: true,
          ),
          CoconutLayout.spacing_300h,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SvgPicture.asset(
                  CommonStateIconPath.circleInfo,
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                ),
              ),
              CoconutLayout.spacing_100w,
              Expanded(
                child: Text(
                  t.premium.destination.external_warning,
                  style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_600h,
          InlineActionButton(key: widget.actionKey, isActive: canSubmit, text: widget.actionText, onPressed: _submit),
        ],
      ),
    );
  }
}
