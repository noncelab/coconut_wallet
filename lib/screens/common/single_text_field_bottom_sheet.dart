import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutTextField;
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/single_field_fixed_bottom_sheet_body.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 단일 줄 입력 + [SingleFieldFixedBottomSheetBody].
///
/// - Done을 누르면 입력값을 반환하거나(onComplete), 결과를 pop합니다.
/// - 텍스트 필드 suffix에 항상 X(클리어) 버튼이 표시됩니다.
/// - 필요 시 suffix에 추가로 [suffix]를 넣을 수 있습니다(단위 등).
class SingleTextFieldBottomSheet extends StatefulWidget {
  const SingleTextFieldBottomSheet({
    super.key,
    this.originalText = '',
    required this.onComplete,
    this.placeholder = '',
    this.completeButtonText,
    this.keyboardType = TextInputType.text,
    this.visibleTextLimit = true,
    this.formatInput,
    this.maxLength,
    this.collapsedHeight,
    this.textInputFormatters,
    this.completeEnabledWhen,
    this.focusOnlyWhenOriginalNotEmpty = false,
    this.unfocusOnTapOutside = true,
    this.prefix,
    this.suffix,
    this.resultBuilder,
    this.toggleLabel,
    this.toggleDescription,
    this.initiallyEnabled = true,
    this.submitValidator,
  });

  final String? originalText;
  final void Function(String) onComplete;
  final String placeholder;
  final String? completeButtonText;
  final TextInputType keyboardType;
  final bool visibleTextLimit;
  final String Function(String)? formatInput;
  final int? maxLength;

  /// 키보드 미표시 시 본문+하단 버튼 영역 최소 높이(미지정 시 240).
  final double? collapsedHeight;

  /// 지정 시 [formatInput] 대신 사용 (예: BTC [BtcAmountInputFormatter] 조합).
  final List<TextInputFormatter>? textInputFormatters;

  /// 완료 버튼 활성 조건. null이면 `입력값 != originalText`.
  final bool Function(String currentText, String originalText)? completeEnabledWhen;

  /// true면 초기 문자열이 비어 있지 않을 때만 포커스
  final bool focusOnlyWhenOriginalNotEmpty;

  /// 바깥 탭 시 포커스 해제
  final bool unfocusOnTapOutside;

  /// [CoconutTextField.prefix]
  final Widget? prefix;

  /// 텍스트 필드 오른쪽 suffix에 들어가는 추가 위젯(단위 등).
  /// suffix가 null이어도 X(클리어)는 항상 보입니다.
  final Widget? suffix;

  /// Done을 눌렀을 때 반환할 결과 빌더.
  final Object? Function(String currentText)? resultBuilder;

  /// 입력 필드 사용 여부를 변경하는 토글의 라벨. null이면 토글을 표시하지 않습니다.
  final String? toggleLabel;
  final String? toggleDescription;
  final bool initiallyEnabled;

  /// 완료 버튼을 눌렀을 때 실행할 검증 함수. 오류 문구를 반환하면 시트를 닫지 않고 입력창 아래에 표시합니다.
  final String? Function(String text)? submitValidator;

  /// 커스텀 child를 그대로 감싸 시트 띄우기(필요 시).
  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    required String screenName,
  }) {
    return CommonBottomSheets.showBottomSheet<T>(
      context: context,
      title: title,
      screenName: screenName,
      showCloseButton: true,
      showDragHandle: true,
      keyboardBottomPadding: 0,
      titlePadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: child,
    );
  }

  /// Bip21AmountBottomSheet처럼 Done 클릭 시 결과를 반환하는 단일 입력 시트.
  static Future<R?> showWithResult<R>({
    required BuildContext context,
    required String title,
    required String screenName,
    String? originalText,
    String placeholder = '',
    String? completeButtonText,
    TextInputType keyboardType = TextInputType.text,
    bool visibleTextLimit = true,
    String Function(String)? formatInput,
    int? maxLength,
    double? collapsedHeight,
    List<TextInputFormatter>? textInputFormatters,
    bool Function(String currentText, String originalText)? completeEnabledWhen,
    bool focusOnlyWhenOriginalNotEmpty = false,
    bool unfocusOnTapOutside = true,
    Widget? prefix,
    Widget? suffix,
    String? toggleLabel,
    String? toggleDescription,
    bool initiallyEnabled = true,
    String? Function(String text)? submitValidator,
    required R Function(String currentText, String originalText) resultBuilder,
  }) {
    final original = originalText ?? '';
    return CommonBottomSheets.showBottomSheet<R>(
      context: context,
      title: title,
      screenName: screenName,
      showCloseButton: true,
      showDragHandle: true,
      keyboardBottomPadding: 0,
      titlePadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: SingleTextFieldBottomSheet(
        originalText: original,
        onComplete: (_) {},
        placeholder: placeholder,
        completeButtonText: completeButtonText,
        keyboardType: keyboardType,
        visibleTextLimit: visibleTextLimit,
        formatInput: formatInput,
        maxLength: maxLength,
        collapsedHeight: collapsedHeight,
        textInputFormatters: textInputFormatters,
        completeEnabledWhen: completeEnabledWhen,
        focusOnlyWhenOriginalNotEmpty: focusOnlyWhenOriginalNotEmpty,
        unfocusOnTapOutside: unfocusOnTapOutside,
        prefix: prefix,
        suffix: suffix,
        toggleLabel: toggleLabel,
        toggleDescription: toggleDescription,
        initiallyEnabled: initiallyEnabled,
        submitValidator: submitValidator,
        resultBuilder: (currentText) => resultBuilder(currentText, original),
      ),
    );
  }

  /// 단순 onComplete 기반으로 시트 띄우기
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String screenName,
    String? originalText,
    required void Function(String) onComplete,
    String placeholder = '',
    String? completeButtonText,
    TextInputType keyboardType = TextInputType.text,
    bool visibleTextLimit = true,
    String Function(String)? formatInput,
    int? maxLength,
    double? collapsedHeight,
    List<TextInputFormatter>? textInputFormatters,
    bool Function(String currentText, String originalText)? completeEnabledWhen,
    bool focusOnlyWhenOriginalNotEmpty = false,
    bool unfocusOnTapOutside = true,
    Widget? prefix,
    Widget? suffix,
    String? toggleLabel,
    String? toggleDescription,
    bool initiallyEnabled = true,
    String? Function(String text)? submitValidator,
  }) {
    return CommonBottomSheets.showBottomSheet<void>(
      context: context,
      title: title,
      screenName: screenName,
      showCloseButton: true,
      showDragHandle: true,
      keyboardBottomPadding: 0,
      titlePadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: SingleTextFieldBottomSheet(
        originalText: originalText ?? '',
        onComplete: onComplete,
        placeholder: placeholder,
        completeButtonText: completeButtonText,
        keyboardType: keyboardType,
        visibleTextLimit: visibleTextLimit,
        formatInput: formatInput,
        maxLength: maxLength,
        collapsedHeight: collapsedHeight,
        textInputFormatters: textInputFormatters,
        completeEnabledWhen: completeEnabledWhen,
        focusOnlyWhenOriginalNotEmpty: focusOnlyWhenOriginalNotEmpty,
        unfocusOnTapOutside: unfocusOnTapOutside,
        prefix: prefix,
        suffix: suffix,
        toggleLabel: toggleLabel,
        toggleDescription: toggleDescription,
        initiallyEnabled: initiallyEnabled,
        submitValidator: submitValidator,
      ),
    );
  }

  @override
  State<SingleTextFieldBottomSheet> createState() => _SingleTextFieldBottomSheetState();
}

class _SingleTextFieldBottomSheetState extends State<SingleTextFieldBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _updateText = '';
  late bool _isEnabled;
  String? _errorText;

  bool get _isCompleteButtonEnabled {
    if (_errorText != null) return false;
    final original = widget.originalText ?? '';
    if (widget.toggleLabel != null && !_isEnabled) {
      return widget.initiallyEnabled;
    }
    if (widget.completeEnabledWhen != null) {
      return widget.completeEnabledWhen!(_controller.text, original);
    }
    return _updateText != original;
  }

  List<TextInputFormatter> _buildFormatters() {
    return [if (widget.formatInput != null) _CallbackTextInputFormatter(widget.formatInput!)];
  }

  void _clearField() {
    _controller.clear();
    setState(() {
      _updateText = '';
      _errorText = null;
    });
  }

  void _setEnabled(bool value) {
    if (value) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() {
      _isEnabled = value;
      _errorText = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _updateText = widget.originalText ?? '';
    _isEnabled = widget.initiallyEnabled;
    _controller.text = _updateText;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      if (widget.focusOnlyWhenOriginalNotEmpty) {
        if (_controller.text.trim().isNotEmpty) {
          _focusNode.requestFocus();
        }
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onComplete() {
    final trimmed = _isEnabled ? _controller.text.trim() : '';
    final errorText = widget.submitValidator?.call(trimmed);
    if (errorText != null) {
      setState(() => _errorText = errorText);
      return;
    }

    FocusScope.of(context).unfocus();
    widget.onComplete(trimmed);
    final result = widget.resultBuilder?.call(trimmed);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final formatters = widget.textInputFormatters ?? _buildFormatters();

    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;

    final field = CoconutTextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged:
          (_) => setState(() {
            _updateText = _controller.text;
            _errorText = null;
          }),
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textInputType: widget.keyboardType,
      textInputFormatter: formatters,
      placeholderText: widget.placeholder,
      backgroundColor: context.coconutColors.surfaceBottomSheet,
      isLengthVisible: widget.visibleTextLimit,
      maxLength: widget.maxLength ?? 30,
      maxLines: 1,
      enableSuggestions: isAndroid, // Required for Android emoji input
      clearButtonVisibility: CoconutTextFieldClearButtonVisibility.always,
      onClear: _clearField,
      prefix: widget.prefix,
      suffix: widget.suffix,
      isError: _errorText != null,
      errorText: _errorText,
      descriptionText: widget.submitValidator == null ? null : ' ',
    );

    final content = Column(
      children: [
        if (widget.toggleLabel != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.coconutColors.surfaceBottomSheetElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.toggleLabel!,
                        style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                      ),
                      if (widget.toggleDescription != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.toggleDescription!,
                          style: CoconutTypography.body3_12.setColor(context.coconutColors.mutedText),
                        ),
                      ],
                    ],
                  ),
                ),
                CoconutLayout.spacing_100w,
                CoconutSwitch(
                  isOn: _isEnabled,
                  scale: 0.75,
                  activeTrackColor: context.coconutColors.switchActiveTrack,
                  activeThumbColor: context.coconutColors.switchActiveThumb,
                  inactiveTrackColor: context.coconutColors.switchInactiveTrack,
                  inactiveThumbColor: context.coconutColors.switchInactiveThumb,
                  onChanged: _setEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        IgnorePointer(ignoring: !_isEnabled, child: Opacity(opacity: _isEnabled ? 1 : 0.4, child: field)),
      ],
    );

    final body = SingleFieldFixedBottomSheetBody(
      collapsedHeight: widget.collapsedHeight ?? 240,
      keyboardContentHeight:
          (widget.toggleLabel == null
              ? 120
              : widget.toggleDescription == null
              ? 150
              : 180) +
          (widget.submitValidator == null ? 0 : 24),
      isCompleteEnabled: _isCompleteButtonEnabled,
      onComplete: _onComplete,
      completeLabel: widget.completeButtonText ?? t.done,
      textField: content,
    );

    if (!widget.unfocusOnTapOutside) return body;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: body,
    );
  }
}

class _CallbackTextInputFormatter extends TextInputFormatter {
  _CallbackTextInputFormatter(this.format);
  final String Function(String) format;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length.clamp(0, formatted.length)),
    );
  }
}
