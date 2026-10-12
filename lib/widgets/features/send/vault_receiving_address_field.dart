import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:flutter/material.dart';

/// A read-only address that opens the vault's receive address selection.
class VaultReceivingAddressField extends StatefulWidget {
  final String address;
  final String placeholder;
  final bool isError;
  final VoidCallback onTap;

  const VaultReceivingAddressField({
    super.key,
    required this.address,
    required this.placeholder,
    required this.onTap,
    this.isError = false,
  });

  @override
  State<VaultReceivingAddressField> createState() => _VaultReceivingAddressFieldState();
}

class _VaultReceivingAddressFieldState extends State<VaultReceivingAddressField> {
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  late final TextEditingController _textController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.address);
  }

  @override
  void didUpdateWidget(covariant VaultReceivingAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address) {
      _textController.text = widget.address;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: Semantics(
        button: true,
        label: widget.address.isEmpty ? widget.placeholder : widget.address,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: ExcludeFocus(
          child: CoconutTextField(
            controller: _textController,
            focusNode: _focusNode,
            scrollController: _scrollController,
            scrollPhysics: const ClampingScrollPhysics(),
            showScrollFades: true,
            readOnly: true,
            enableInteractiveSelection: false,
            onChanged: (_) {},
            onTap: widget.onTap,
            height: 52,
            fontHeight: 1,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: colors.background,
            textColor: _isPressed ? colors.secondaryText : colors.primaryText,
            placeholderColor: _isPressed ? colors.secondaryText : colors.inputPlaceholder,
            placeholderText: widget.placeholder,
            maxLines: 1,
            isError: widget.isError,
          ),
        ),
      ),
    );
  }
}
