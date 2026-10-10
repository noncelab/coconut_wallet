import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

/// A selectable receive address with horizontal scrolling and edge fades.
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
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateEdges);
    _scheduleEdgeUpdate();
  }

  @override
  void didUpdateWidget(covariant VaultReceivingAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
        _updateEdges();
      });
    }
  }

  void _scheduleEdgeUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateEdges();
    });
  }

  void _updateEdges() {
    if (!_scrollController.hasClients || !_scrollController.position.hasContentDimensions) return;
    final position = _scrollController.position;
    final left = position.pixels > position.minScrollExtent + 0.5;
    final right = position.pixels < position.maxScrollExtent - 0.5;
    if (left == _canScrollLeft && right == _canScrollRight) return;
    setState(() {
      _canScrollLeft = left;
      _canScrollRight = right;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: widget.isError ? colors.danger : colors.inputBorderUnfocused),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _scheduleEdgeUpdate();
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.address.isEmpty ? widget.placeholder : widget.address,
                      style: CoconutTypography.body2_14.copyWith(
                        height: 1,
                        color: widget.address.isEmpty ? colors.inputPlaceholder : colors.primaryText,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
            if (_canScrollLeft) _edgeFade(left: true),
            if (_canScrollRight) _edgeFade(left: false),
          ],
        ),
      ),
    );
  }

  Widget _edgeFade({required bool left}) {
    return Positioned(
      key: ValueKey(left ? 'vault-address-left-fade' : 'vault-address-right-fade'),
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 0,
      width: 20,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
              begin: left ? Alignment.centerLeft : Alignment.centerRight,
              end: left ? Alignment.centerRight : Alignment.centerLeft,
            ),
          ),
        ),
      ),
    );
  }
}
