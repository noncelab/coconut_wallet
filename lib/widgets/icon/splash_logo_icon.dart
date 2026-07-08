import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class SplashLogoIcon extends StatelessWidget {
  final double size;

  const SplashLogoIcon({super.key, this.size = Sizes.size60});

  @override
  Widget build(BuildContext context) {
    final isMainnet = !NetworkType.currentNetworkType.isTestnet;
    return Image.asset(
      'assets/images/splash_logo_${isMainnet ? "mainnet" : "regtest"}.png',
      width: size,
      colorBlendMode: BlendMode.modulate,
      color: isMainnet ? null : context.coconutColors.iconDefault,
    );
  }
}
