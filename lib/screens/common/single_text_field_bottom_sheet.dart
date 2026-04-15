import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/single_field_fixed_bottom_sheet_body.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    this.fieldBackgroundColor,
    this.errorColor,
    this.placeholderColor,
    this.activeColor,
    this.cursorColor,
    this.unfocusOnTapOutside = true,
    this.prefix,
    this.suffix,
    this.resultBuilder,
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

  final Color? fieldBackgroundColor;
  final Color? errorColor;
  final Color? placeholderColor;
  final Color? activeColor;
  final Color? cursorColor;

  /// 바깥 탭 시 포커스 해제
  final bool unfocusOnTapOutside;

  /// [CoconutTextField.prefix]
  final Widget? prefix;

  /// 텍스트 필드 오른쪽 suffix에 들어가는 추가 위젯(단위 등).
  /// suffix가 null이어도 X(클리어)는 항상 보입니다.
  final Widget? suffix;

  /// Done을 눌렀을 때 반환할 결과 빌더.
  final Object? Function(String currentText)? resultBuilder;

  /// 커스텀 child를 그대로 감싸 시트 띄우기(필요 시).
  static Future<T?> showBottomSheet<T>({required BuildContext context, required String title, required Widget child}) {
    return CommonBottomSheets.showBottomSheet<T>(
      context: context,
      title: title,
      showCloseButton: true,
      showDragHandle: true,
      titlePadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: child,
    );
  }

  /// Bip21AmountBottomSheet처럼 Done 클릭 시 결과를 반환하는 단일 입력 시트.
  static Future<R?> showWithResult<R>({
    required BuildContext context,
    required String title,
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
    Color? fieldBackgroundColor,
    Color? errorColor,
    Color? placeholderColor,
    Color? activeColor,
    Color? cursorColor,
    bool unfocusOnTapOutside = true,
    Widget? prefix,
    Widget? suffix,
    required R Function(String currentText, String originalText) resultBuilder,
  }) {
    final original = originalText ?? '';
    return CommonBottomSheets.showBottomSheet<R>(
      context: context,
      title: title,
      showCloseButton: true,
      showDragHandle: true,
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
        fieldBackgroundColor: fieldBackgroundColor,
        errorColor: errorColor,
        placeholderColor: placeholderColor,
        activeColor: activeColor,
        cursorColor: cursorColor,
        unfocusOnTapOutside: unfocusOnTapOutside,
        prefix: prefix,
        suffix: suffix,
        resultBuilder: (currentText) => resultBuilder(currentText, original),
      ),
    );
  }

  /// 단순 onComplete 기반으로 시트 띄우기
  static Future<void> show({
    required BuildContext context,
    required String title,
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
    Color? fieldBackgroundColor,
    Color? errorColor,
    Color? placeholderColor,
    Color? activeColor,
    Color? cursorColor,
    bool unfocusOnTapOutside = true,
    Widget? prefix,
    Widget? suffix,
  }) {
    return CommonBottomSheets.showBottomSheet<void>(
      context: context,
      title: title,
      showCloseButton: true,
      showDragHandle: true,
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
        fieldBackgroundColor: fieldBackgroundColor,
        errorColor: errorColor,
        placeholderColor: placeholderColor,
        activeColor: activeColor,
        cursorColor: cursorColor,
        unfocusOnTapOutside: unfocusOnTapOutside,
        prefix: prefix,
        suffix: suffix,
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

  bool get _isCompleteButtonEnabled {
    final original = widget.originalText ?? '';
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
    });
  }

  @override
  void initState() {
    super.initState();
    _updateText = widget.originalText ?? '';
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
    FocusScope.of(context).unfocus();
    final trimmed = _controller.text.trim();
    widget.onComplete(trimmed);
    final result = widget.resultBuilder?.call(trimmed);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final formatters = widget.textInputFormatters ?? _buildFormatters();

    final clearIcon = IconButton(
      iconSize: 14,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      splashRadius: 12,
      onPressed: _clearField,
      icon: SvgPicture.asset(
        'assets/svg/text-field-clear.svg',
        colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
      ),
    );

    Widget? composedSuffix;
    if (widget.suffix == null) {
      composedSuffix = clearIcon;
    } else {
      composedSuffix = Row(mainAxisSize: MainAxisSize.min, children: [widget.suffix!, clearIcon]);
    }

    final field = CoconutTextField(
      controller: _controller,
      focusNode: _focusNode,
      padding: EdgeInsets.only(left: widget.prefix != null ? 8 : 16, top: 16, bottom: 16),
      onChanged: (_) => setState(() => _updateText = _controller.text),
      textInputType: widget.keyboardType,
      textInputFormatter: formatters,
      placeholderText: widget.placeholder,
      isLengthVisible: widget.visibleTextLimit,
      maxLength: widget.maxLength ?? 30,
      maxLines: 1,
      backgroundColor: widget.fieldBackgroundColor,
      errorColor: widget.errorColor,
      placeholderColor: widget.placeholderColor,
      activeColor: widget.activeColor,
      cursorColor: widget.cursorColor,
      prefix: widget.prefix,
      suffix: composedSuffix,
    );

    final body = SingleFieldFixedBottomSheetBody(
      collapsedHeight: widget.collapsedHeight ?? 240,
      isCompleteEnabled: _isCompleteButtonEnabled,
      onComplete: _onComplete,
      completeLabel: widget.completeButtonText ?? t.complete,
      textField: field,
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
