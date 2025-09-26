
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SelectedUtxosBottomSheet extends StatelessWidget {
  final VoidCallback onLock;
  final VoidCallback onUnlock;

  const SelectedUtxosBottomSheet({
    super.key,
    required this.onLock,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 1,
      heightFactor: 0.175,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: const BoxDecoration(
            color: CoconutColors.gray900,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
              top: BorderSide(color: CoconutColors.gray750, width: 2),
              left: BorderSide(color: CoconutColors.gray750, width: 2),
              right: BorderSide(color: CoconutColors.gray750, width: 2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildButton('assets/svg/lock.svg', CoconutColors.primary, onLock),
                  _buildButton('assets/svg/unlock.svg', CoconutColors.red, onUnlock),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildButton(String? iconPath, Color? iconColor, VoidCallback onPressed, {Widget? child}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: CoconutColors.gray900,
            elevation: 0,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(8),
          ),
          child: child ??
              SvgPicture.asset(iconPath!, width: 70, height: 70, color: iconColor),
        ),
      ),
    );
  }
}