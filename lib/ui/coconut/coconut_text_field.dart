import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

enum CoconutTextFieldStyle { bordered, underline }

enum CoconutTextFieldClearButtonVisibility { never, whenNotEmpty, always }

enum CoconutTextFieldSize { standard, compact, search }

enum CoconutTextFieldUnderlineSpacing { standard, compact }

class CoconutTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final VoidCallback? onEditingComplete;
  final EdgeInsets? padding;
  final Color? activeColor;
  final Color? cursorColor;
  final Color? placeholderColor;
  final Color? errorColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final int? maxLength;
  final int? maxLines;
  final Widget? prefix;
  final Widget? suffix;
  final String? suffixIconAsset;
  final VoidCallback? onSuffixPressed;
  final Color? suffixIconColor;
  final double suffixIconSize;
  final CoconutTextFieldClearButtonVisibility clearButtonVisibility;
  final VoidCallback? onClear;
  final String? placeholderText;
  final String? errorText;
  final String? descriptionText;
  final bool isErrorTextMultiline;
  final bool isError;
  final TextInputType? textInputType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? textInputFormatter;
  final bool obscureText;
  final bool isVisibleBorder;
  final double borderRadius;
  final double? height;
  final double fontSize;
  final String fontFamily;
  final FontWeight fontWeight;
  final TextAlign? textAlign;
  final bool isLengthVisible;
  final bool? enableInteractiveSelection;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool enabled;
  final bool unfocusOnTapOutside;
  final TextOverflow? textOverflow;
  final double fontHeight;
  final CoconutTextFieldStyle style;
  final CoconutTextFieldSize size;
  final CoconutTextFieldUnderlineSpacing underlineSpacing;

  const CoconutTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onEditingComplete,
    this.padding,
    this.activeColor,
    this.cursorColor,
    this.placeholderColor,
    this.errorColor,
    this.borderColor,
    this.backgroundColor,
    this.maxLength,
    this.maxLines,
    this.prefix,
    this.suffix,
    this.suffixIconAsset,
    this.onSuffixPressed,
    this.suffixIconColor,
    this.suffixIconSize = 16,
    this.clearButtonVisibility = CoconutTextFieldClearButtonVisibility.never,
    this.onClear,
    this.placeholderText,
    this.errorText,
    this.descriptionText,
    this.isErrorTextMultiline = false,
    this.isError = false,
    this.textInputType,
    this.textInputAction,
    this.textInputFormatter,
    this.obscureText = false,
    this.isVisibleBorder = true,
    this.borderRadius = 12,
    this.height,
    this.fontSize = 14,
    this.fontFamily = 'Pretendard',
    this.fontWeight = FontWeight.normal,
    this.textAlign,
    this.isLengthVisible = true,
    this.enableInteractiveSelection,
    this.autocorrect = false,
    this.enableSuggestions = false,
    this.enabled = true,
    this.unfocusOnTapOutside = false,
    this.textOverflow = TextOverflow.ellipsis,
    this.fontHeight = 1.4,
    this.style = CoconutTextFieldStyle.bordered,
    this.size = CoconutTextFieldSize.standard,
    this.underlineSpacing = CoconutTextFieldUnderlineSpacing.standard,
  });

  @override
  State<CoconutTextField> createState() => _CoconutTextFieldState();
}

class _CoconutTextFieldState extends State<CoconutTextField> {
  final GlobalKey _prefixGlobalKey = GlobalKey();
  final GlobalKey _suffixGlobalKey = GlobalKey();

  Size _prefixSize = const Size(0, 0);
  Size _suffixSize = const Size(0, 0);
  String _text = '';
  String _placeholderText = '';
  bool _isFocus = false;

  late Color _activeColor;
  late Color _cursorColor;
  late Color _placeholderColor;
  late Color _errorColor;
  late Color _borderColor;
  late Color _focusedBorderColor;
  late Color _backgroundColor;

  @override
  void initState() {
    super.initState();
    _placeholderText = widget.placeholderText ?? '';
    widget.controller.addListener(_controllerListener);
    widget.focusNode.addListener(_focusNodeListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAffixes());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateResolvedColors();
  }

  @override
  void didUpdateWidget(covariant CoconutTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _placeholderText = widget.placeholderText ?? '';
    _updateResolvedColors();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAffixes());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerListener);
    widget.focusNode.removeListener(_focusNodeListener);
    super.dispose();
  }

  void _controllerListener() {
    var text = widget.controller.text;
    if (widget.maxLength != null && text.runes.length > widget.maxLength!) {
      text = String.fromCharCodes(text.runes.take(widget.maxLength!));
      widget.controller.text = text;
      return;
    }
    if (text == _text) return;
    _text = text;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAffixes());
    widget.onChanged(_text);
  }

  void _focusNodeListener() {
    _isFocus = widget.focusNode.hasFocus;
    setState(() {});
  }

  void _updateResolvedColors() {
    final colors = context.coconutColors;
    _activeColor = widget.activeColor ?? colors.primaryText;
    _cursorColor = widget.cursorColor ?? colors.primaryText;
    _placeholderColor = widget.placeholderColor ?? colors.inputPlaceholder;
    _errorColor = widget.errorColor ?? colors.danger;
    _borderColor = widget.borderColor ?? colors.inputBorderUnfocused;
    _focusedBorderColor = widget.activeColor ?? colors.inputBorderFocused;
    _backgroundColor = widget.backgroundColor ?? colors.inputSurface;
    _text = widget.controller.text;
  }

  void _measureAffixes() {
    Size nextPrefixSize = const Size(0, 0);
    Size nextSuffixSize = const Size(0, 0);

    if (_prefixGlobalKey.currentContext != null) {
      nextPrefixSize = (_prefixGlobalKey.currentContext!.findRenderObject() as RenderBox).size;
    }
    if (_suffixGlobalKey.currentContext != null) {
      nextSuffixSize = (_suffixGlobalKey.currentContext!.findRenderObject() as RenderBox).size;
    }
    if (nextPrefixSize != _prefixSize || nextSuffixSize != _suffixSize) {
      setState(() {
        _prefixSize = nextPrefixSize;
        _suffixSize = nextSuffixSize;
      });
    }
  }

  bool get _showClearButton {
    if (_text.isEmpty) {
      return false;
    }
    switch (widget.clearButtonVisibility) {
      case CoconutTextFieldClearButtonVisibility.never:
        return false;
      case CoconutTextFieldClearButtonVisibility.whenNotEmpty:
        return _text.isNotEmpty;
      case CoconutTextFieldClearButtonVisibility.always:
        return true;
    }
  }

  Color _resolvedClearButtonColor(BuildContext context) {
    final colors = context.coconutColors;
    if (widget.isError) {
      return _errorColor;
    }
    return colors.inputPlaceholder;
  }

  Widget _buildClearButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 6, right: _hasTrailingSuffix ? 4 : 0),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 16,
        onPressed: widget.onClear,
        child: SizedBox(
          width: 16,
          height: 16,
          child: Center(
            child: SvgPicture.asset(
              CommonFormIconPath.textFieldClear,
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(_resolvedClearButtonColor(context), BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasTrailingSuffix => widget.suffixIconAsset != null || widget.suffix != null;

  Widget _buildSuffixIconButton(BuildContext context) {
    final colors = context.coconutColors;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 20,
      onPressed: widget.onSuffixPressed,
      child: SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: SvgPicture.asset(
            widget.suffixIconAsset!,
            width: widget.suffixIconSize,
            height: widget.suffixIconSize,
            colorFilter: ColorFilter.mode(widget.suffixIconColor ?? colors.iconPrimary, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget? _buildResolvedSuffix(BuildContext context) {
    final children = <Widget>[];

    if (_showClearButton && widget.onClear != null) {
      children.add(_buildClearButton(context));
    }

    if (widget.suffixIconAsset != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 4));
      }
      children.add(_buildSuffixIconButton(context));
    }

    if (widget.suffix != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 4));
      }
      children.add(widget.suffix!);
    }

    if (children.isEmpty) {
      return null;
    }

    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: children);
  }

  EdgeInsets _resolvedDefaultPadding(bool isUnderline) {
    if (isUnderline) {
      switch (widget.underlineSpacing) {
        case CoconutTextFieldUnderlineSpacing.standard:
          return const EdgeInsets.only(left: 4, right: 4, top: 6, bottom: 6);
        case CoconutTextFieldUnderlineSpacing.compact:
          return const EdgeInsets.only(left: 4, right: 4, top: 4, bottom: 4);
      }
    }

    switch (widget.size) {
      case CoconutTextFieldSize.standard:
        return EdgeInsets.fromLTRB(widget.prefix != null ? 0 : 16, 16, 16, 16);
      case CoconutTextFieldSize.compact:
        return EdgeInsets.fromLTRB(widget.prefix != null ? 0 : 5, 7, 5, 7);
      case CoconutTextFieldSize.search:
        return EdgeInsets.zero;
    }
  }

  double _resolvedSuffixEdgePadding(bool isUnderline) {
    if (widget.suffixIconAsset != null) {
      return 16;
    }

    if (widget.padding != null) {
      return widget.padding!.right;
    }

    if (widget.size == CoconutTextFieldSize.search) {
      return 12;
    }

    return _resolvedDefaultPadding(isUnderline).right;
  }

  double? _resolvedDefaultHeight(bool isUnderline) {
    if (isUnderline) {
      return null;
    }

    switch (widget.size) {
      case CoconutTextFieldSize.standard:
        return 52;
      case CoconutTextFieldSize.compact:
        return 30;
      case CoconutTextFieldSize.search:
        return 40;
    }
  }

  double _resolvedTextHeight(int? resolvedMaxLines) {
    final isSingleLine = resolvedMaxLines == null || resolvedMaxLines == 1;
    return isSingleLine ? 1.0 : widget.fontHeight;
  }

  double _resolvedClearFadeWidth() {
    if (!_showClearButton || widget.onClear == null) {
      return 0;
    }

    return 20;
  }

  double _resolvedSuffixBackgroundWidth(double resolvedSuffixEdgePadding) {
    if (_suffixSize.width == 0) {
      return 0;
    }

    return _suffixSize.width + resolvedSuffixEdgePadding;
  }

  @override
  Widget build(BuildContext context) {
    final isUnderline = widget.style == CoconutTextFieldStyle.underline;
    final resolvedSuffix = _buildResolvedSuffix(context);
    final resolvedPadding = widget.padding ?? _resolvedDefaultPadding(isUnderline);
    final resolvedHeight = widget.height ?? _resolvedDefaultHeight(isUnderline);
    final resolvedSuffixEdgePadding = _resolvedSuffixEdgePadding(isUnderline);
    final resolvedMaxLines = widget.obscureText ? 1 : widget.maxLines;
    final resolvedTextHeight = _resolvedTextHeight(resolvedMaxLines);

    final resolvedBorderColor =
        widget.isError
            ? _errorColor
            : _isFocus
            ? (widget.maxLength != null && _text.runes.length > widget.maxLength! ? _errorColor : _focusedBorderColor)
            : _borderColor;

    final resolvedTextColor = widget.enabled ? context.coconutColors.primaryText : context.coconutColors.secondaryText;
    final placeholderLeftInset = widget.prefix == null ? resolvedPadding.left : _prefixSize.width;
    final placeholderRightInset =
        resolvedSuffix != null ? _suffixSize.width + resolvedSuffixEdgePadding : resolvedPadding.right;
    final clearFadeWidth = _resolvedClearFadeWidth();
    final suffixBackgroundWidth = _resolvedSuffixBackgroundWidth(resolvedSuffixEdgePadding);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: resolvedHeight,
          decoration: BoxDecoration(
            border:
                widget.isVisibleBorder
                    ? isUnderline
                        ? Border(bottom: BorderSide(color: resolvedBorderColor, width: 1))
                        : Border.all(color: resolvedBorderColor)
                    : null,
            borderRadius: isUnderline ? null : BorderRadius.circular(widget.borderRadius),
            color: _backgroundColor,
          ),
          child: Stack(
            children: [
              CupertinoTextField(
                focusNode: widget.focusNode,
                controller: widget.controller,
                inputFormatters: widget.textInputFormatter,
                obscureText: widget.obscureText,
                textAlign: widget.textAlign ?? TextAlign.start,
                padding: resolvedPadding.copyWith(right: resolvedPadding.right + _suffixSize.width),
                style: CoconutTypography.body2_14.copyWith(
                  color: resolvedTextColor,
                  fontSize: widget.fontSize,
                  fontFamily: widget.fontFamily,
                  fontWeight: widget.fontWeight,
                  height: resolvedTextHeight,
                ),
                strutStyle: StrutStyle(
                  fontSize: widget.fontSize,
                  height: resolvedTextHeight,
                  fontFamily: widget.fontFamily,
                  fontWeight: widget.fontWeight,
                  forceStrutHeight: true,
                ),
                cursorColor: _cursorColor,
                decoration: const BoxDecoration(color: Colors.transparent),
                maxLength: widget.maxLength,
                maxLines: resolvedMaxLines,
                prefix: Container(key: _prefixGlobalKey, alignment: Alignment.center, child: widget.prefix),
                suffix: null,
                keyboardType: widget.textInputType,
                textInputAction: widget.textInputAction,
                textAlignVertical: TextAlignVertical.center,
                enableInteractiveSelection: widget.enableInteractiveSelection,
                autocorrect: widget.autocorrect,
                enableSuggestions: widget.enableSuggestions,
                onEditingComplete: widget.onEditingComplete,
                onTapOutside: widget.unfocusOnTapOutside ? (_) => widget.focusNode.unfocus() : null,
                enabled: widget.enabled,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: placeholderLeftInset,
                      right: placeholderRightInset,
                      top: resolvedPadding.top,
                      bottom: resolvedPadding.bottom,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child:
                          widget.placeholderText == null || _isFocus || _text.isNotEmpty
                              ? Text(
                                '',
                                style: CoconutTypography.body2_14.copyWith(
                                  color: _placeholderColor,
                                  fontSize: widget.fontSize,
                                  fontWeight: widget.fontWeight,
                                  height: resolvedTextHeight,
                                ),
                              )
                              : FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _placeholderText,
                                  style: CoconutTypography.body2_14.copyWith(
                                    color: _placeholderColor,
                                    fontSize: widget.fontSize,
                                    fontWeight: widget.fontWeight,
                                    height: resolvedTextHeight,
                                  ),
                                ),
                              ),
                    ),
                  ),
                ),
              ),
              if (resolvedSuffix != null && suffixBackgroundWidth > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: suffixBackgroundWidth,
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: isUnderline ? null : BorderRadius.circular(widget.borderRadius),
                      ),
                    ),
                  ),
                ),
              if (resolvedSuffix != null && clearFadeWidth > 0)
                Positioned(
                  top: 0,
                  right: suffixBackgroundWidth,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: clearFadeWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            _backgroundColor.withValues(alpha: 0),
                            _backgroundColor.withValues(alpha: 0.78),
                            _backgroundColor,
                          ],
                          stops: const [0, 0.55, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              if (resolvedSuffix != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: Padding(
                      padding: EdgeInsets.only(right: resolvedSuffixEdgePadding),
                      child: KeyedSubtree(key: _suffixGlobalKey, child: resolvedSuffix),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.errorText != null && widget.isError)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.errorText ?? '',
                    maxLines: widget.isErrorTextMultiline ? null : 1,
                    overflow: widget.isErrorTextMultiline ? null : (widget.textOverflow ?? TextOverflow.ellipsis),
                    style: CoconutTypography.body3_12.copyWith(color: _errorColor),
                  ),
                ),
              )
            else if (widget.descriptionText != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.descriptionText ?? '',
                    style: CoconutTypography.body3_12.copyWith(color: _isFocus ? _activeColor : _placeholderColor),
                    textScaler: const TextScaler.linear(1),
                  ),
                ),
              ),
            if (widget.maxLength != null && widget.isLengthVisible) ...[
              Container(),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_text.runes.length}/${widget.maxLength}',
                  style: CoconutTypography.body3_12_Number.copyWith(color: _isFocus ? _activeColor : _placeholderColor),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
