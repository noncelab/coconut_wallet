import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:flutter/material.dart';

/// 이 색상값은 의도적으로 theme-independent하다.
///
/// 지갑 태그 색은 사용자가 지갑을 시각적으로 구분하는 식별자라서, 앱 테마가 바뀌어도
/// 같은 지갑은 항상 같은 색으로 보여야 한다.
/// 따라서, `context.coconutColors` 토큰으로 옮기지 않는다
/// hardcoded color guardrail을 도입할 때 이 파일 전체를 exemption 목록에 포함해야 한다.
const defaultIconColor = Color.fromRGBO(218, 216, 228, 1);
const defaultBackgroundColor = Color.fromRGBO(255, 255, 255, 0.1);

// Internal value object. Prefer accessing it only through WalletVisualStyleUtil.
class WalletVisualColorSet {
  final Color color;
  final Color backgroundColor;

  const WalletVisualColorSet({required this.color, required this.backgroundColor});

  WalletVisualColorSet withOpacity(double opacity) {
    return WalletVisualColorSet(color: color, backgroundColor: backgroundColor.withValues(alpha: opacity));
  }
}

enum WalletVisualColor { purple, tangerine, yellow, green, blue, pink, red, orange, lightgrey, mint }

const List<Color> colorPalette = [
  CoconutColors.purple,
  CoconutColors.tangerine,
  CoconutColors.yellow,
  CoconutColors.green,
  CoconutColors.sky,
  CoconutColors.pink,
  CoconutColors.red,
  CoconutColors.orange,
  CoconutColors.gray600,
  CoconutColors.mint,
];

final List<Color> backgroundColorPalette = [
  CoconutColors.purple.withValues(alpha: 0.18),
  CoconutColors.tangerine.withValues(alpha: 0.18),
  CoconutColors.yellow.withValues(alpha: 0.18),
  CoconutColors.green.withValues(alpha: 0.18),
  CoconutColors.sky.withValues(alpha: 0.18),
  CoconutColors.pink.withValues(alpha: 0.18),
  CoconutColors.red.withValues(alpha: 0.18),
  CoconutColors.orange.withValues(alpha: 0.18),
  CoconutColors.gray600.withValues(alpha: 0.18),
  CoconutColors.mint.withValues(alpha: 0.18),
];

const List<Color> tagColorPalette = colorPalette;

class TaprootCardStyle {
  final Gradient borderGradient;
  final Gradient backgroundGradient;
  final List<Color> iconGradientColors;

  const TaprootCardStyle({
    required this.borderGradient,
    required this.backgroundGradient,
    required this.iconGradientColors,
  });

  static TaprootCardStyle? from(WalletItemBase wallet) {
    if (wallet is! TaprootWalletItem) return null;
    return TaprootCardStyle.fromKeyPath(wallet.canSpendViaKeyPath);
  }

  static TaprootCardStyle fromKeyPath(bool canSpendViaKeyPath) {
    final colors =
        canSpendViaKeyPath
            ? [CoconutColors.periwinkle, CoconutColors.lightSky]
            : [CoconutColors.lightSky, CoconutColors.periwinkle];

    const begin = Alignment(0.97, -0.25);
    const end = Alignment(-0.97, 0.25);
    const stops = [0.35, 0.75];

    return TaprootCardStyle(
      borderGradient: LinearGradient(begin: begin, end: end, colors: colors, stops: stops),
      backgroundGradient: LinearGradient(
        begin: begin,
        end: end,
        stops: stops,
        colors: [colors[0].withValues(alpha: 0.2), colors[1].withValues(alpha: 0.2)],
      ),
      iconGradientColors: colors,
    );
  }
}

class WalletVisualStyleUtil {
  static WalletVisualColorSet getColor(int index) {
    if (index < 0 || index >= colorPalette.length) {
      return const WalletVisualColorSet(color: defaultIconColor, backgroundColor: defaultBackgroundColor);
    }

    return WalletVisualColorSet(color: colorPalette[index], backgroundColor: backgroundColorPalette[index]);
  }

  static int getIntFromColor(WalletVisualColor color) {
    switch (color) {
      case WalletVisualColor.purple:
        return 0;
      case WalletVisualColor.tangerine:
        return 1;
      case WalletVisualColor.yellow:
        return 2;
      case WalletVisualColor.green:
        return 3;
      case WalletVisualColor.blue:
        return 4;
      case WalletVisualColor.pink:
        return 5;
      case WalletVisualColor.red:
        return 6;
      case WalletVisualColor.orange:
        return 7;
      case WalletVisualColor.lightgrey:
        return 8;
      case WalletVisualColor.mint:
        return 9;
    }
  }

  static Color getColorByIndex(int index) {
    if (index < 0 || index > 9) {
      return defaultIconColor;
    }

    return colorPalette[index % colorPalette.length];
  }

  static Color getBackgroundColorByIndex(int index) {
    if (index < 0 || index > 9) {
      return defaultBackgroundColor;
    }

    return backgroundColorPalette[index % colorPalette.length];
  }

  static Color lightenColor(Color color, {double factor = 0.5}) {
    return Color.lerp(color, Colors.white, factor)!;
  }

  static List<Color> getGradientColors(List<MultisigSigner> list, {bool lighten = false}) {
    if (list.isEmpty) {
      return [CoconutColors.gray300];
    }

    Color getColor(MultisigSigner item) {
      final base =
          item.innerVaultId != null
              ? WalletVisualStyleUtil.getColorByIndex(item.colorIndex ?? 0)
              : CoconutColors.gray300;
      return lighten ? lightenColor(base) : base;
    }

    if (list.length == 2) {
      return [getColor(list[0]), getColor(list[1])];
    }

    return [getColor(list[0]), getColor(list[1]), getColor(list[2])];
  }

  static LinearGradient getMultisigLinearGradient(List<Color> colors) {
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: const GradientRotation(math.pi / 10),
    );
  }
}
