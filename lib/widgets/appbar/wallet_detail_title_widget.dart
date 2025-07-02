import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class WalletDetailTitleWidget extends StatefulWidget {
  final String walletName;
  final VoidCallback onTap;

  const WalletDetailTitleWidget({
    super.key,
    required this.walletName,
    required this.onTap,
  });

  @override
  State<WalletDetailTitleWidget> createState() => _WalletDetailTitleWidgetState();
}

class _WalletDetailTitleWidgetState extends State<WalletDetailTitleWidget> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.9);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            transform: Matrix4.identity()..scale(_scale),
            transformAlignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TextUtils.ellipsisIfLonger(widget.walletName, maxLength: 15),
                  style: CoconutTypography.heading4_18.setColor(CoconutColors.white),
                ),
                SvgPicture.asset('assets/svg/arrow-right-md.svg'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
