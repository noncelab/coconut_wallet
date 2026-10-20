import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/utils/mfp_format.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show kHomeWidgetHeaderHeight;
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon_small.dart';
import 'package:flutter/material.dart';

enum WalletCardSize { small, wide }

/// 지갑 배경 위에 얹는 글자·아이콘의 테마. 스킨·단색은 테마와 상관없이 그리므로 배경 밝기에 맞는 테마 색을 쓴다.
/// 기본·사진 배경은 앱 테마를 그대로 쓴다. 지갑 카드와 지갑 상세 화면이 함께 쓴다.
class WalletContentTheme extends StatelessWidget {
  final WalletBackground? background;
  final Widget child;

  const WalletContentTheme({super.key, required this.background, required this.child});

  static final _light = CoconutThemeExtension.light();
  static final _dark = CoconutThemeExtension.dark();

  static Brightness? brightnessOf(WalletBackground? background) => switch (background) {
    WalletSkinBackground() => Brightness.light,
    WalletColorBackground(:final color) => color.computeLuminance() > 0.35 ? Brightness.light : Brightness.dark,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final brightness = brightnessOf(background);
    if (brightness == null) return child;
    return Theme(
      data: Theme.of(
        context,
      ).copyWith(brightness: brightness, extensions: [brightness == Brightness.light ? _light : _dark]),
      child: child,
    );
  }
}

class WalletCard extends StatelessWidget {
  final WalletItemBase wallet;
  final WalletAppearance appearance;
  final WalletCardSize size;
  final String? balanceDisplay;
  final String? secondaryText;
  final Widget? statusBadge;
  final VoidCallback? onPressed;

  /// [appearance]의 배경이 사진일 때 그 파일. [WalletAppearanceProvider.photoFileFor]로 구한다.
  final File? backgroundPhoto;

  /// 저장 전 이름을 미리 보여 줄 때 쓴다. 없으면 [wallet]의 이름.
  final String? displayName;

  const WalletCard({
    super.key,
    required this.wallet,
    required this.appearance,
    required this.size,
    this.balanceDisplay,
    this.secondaryText,
    this.statusBadge,
    this.onPressed,
    this.backgroundPhoto,
    this.displayName,
  });

  /// 카드가 같은 색 바탕 위에 놓일 때(지갑 정보·배경화면 화면) 경계를 보이게 하는 그림자.
  static List<BoxShadow> elevationOf(BuildContext context) => [
    BoxShadow(color: context.coconutColors.shadowSubtle, blurRadius: 6, spreadRadius: 1),
    BoxShadow(color: context.coconutColors.shadowSubtle, blurRadius: 16, offset: const Offset(0, 6)),
  ];

  /// 지갑 카드의 아이콘. 다중서명·탭루트는 서명자 색 그라데이션을 쓴다. 지갑 상세 카드도 같은 아이콘을 쓴다.
  static Widget iconOf(WalletItemBase wallet, WalletAppearance appearance) {
    final gradientColors = switch (wallet.walletType) {
      WalletType.multiSignature => WalletVisualStyleUtil.getGradientColors((wallet as MultisigWalletItem).signers),
      WalletType.taproot => TaprootCardStyle.from(wallet)?.iconGradientColors,
      _ => null,
    };
    return WalletIconSmall(
      walletImportSource: wallet.walletImportSource,
      colorIndex: appearance.colorIndex,
      iconIndex: appearance.iconIndex,
      gradientColors: gradientColors,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final background = appearance.background;
    Widget content = Padding(
      padding: const EdgeInsets.all(16),
      child: Builder(builder: (context) => size == WalletCardSize.wide ? _buildWide(context) : _buildSmall(context)),
    );
    content = WalletContentTheme(background: background, child: content);
    final hasBackground = appearance.background != null;
    Widget withBackground(Widget child) =>
        hasBackground
            ? Stack(
              fit: StackFit.expand,
              children: [WalletCardBackground(background: appearance.background, photoFile: backgroundPhoto), child],
            )
            : child;
    if (onPressed == null) {
      return DecoratedBox(
        decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox.expand(child: withBackground(content)),
        ),
      );
    }
    return ShrinkAnimationButton(
      defaultColor: colors.homeSurface,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 20,
      onPressed: onPressed!,
      childBuilder:
          (context, isPressed) => SizedBox.expand(
            child: withBackground(
              hasBackground && isPressed
                  ? ColoredBox(
                    color: colors.homeSurfacePressOverlay.withValues(alpha: colors.homeSurfacePressOverlayOpacity),
                    child: content,
                  )
                  : content,
            ),
          ),
    );
  }

  Widget _buildIcon() => iconOf(wallet, appearance);

  /// 이름 아래 줄(MFP나 정족수). 좁으면 줄어든다.
  Widget _buildSubtitleRow(BuildContext context, ({String text, Key key})? subtitle) {
    if (subtitle == null) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        subtitle.text,
        key: subtitle.key,
        maxLines: 1,
        style: CoconutTypography.body3_12_Number.copyWith(color: context.coconutColors.secondaryTextStrong),
      ),
    );
  }

  /// 카드에 찍힌 각인처럼 보이는 유형 표시. 글자 면은 칠하지 않고 안쪽 그림자 두 개로 표현한다(Figma 기준).
  Widget _buildGlyph(BuildContext context) => typeLabelOf(wallet);

  /// 지갑 유형 각인(WATCH-ONLY / HOT). 지갑 상세 카드도 같은 각인을 쓴다.
  static Widget typeLabelOf(WalletItemBase wallet) {
    final isHot = wallet.hasLocalKey;
    return _EmbossedText(
      key: Key(isHot ? 'wallet-card-glyph-hot' : 'wallet-card-glyph-watch-only'),
      text: isHot ? 'HOT' : 'WATCH-ONLY',
      style: CoconutTypography.caption_10_NumberBold.copyWith(fontSize: 12, height: 1, letterSpacing: 1.2),
    );
  }

  Widget _buildName(BuildContext context) {
    return Text(
      displayName ?? wallet.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: CoconutTypography.body2_14_Bold.copyWith(color: context.coconutColors.primaryText),
    );
  }

  /// 이름 아래 줄. 단일서명은 MFP, 다중서명은 정족수(m/n).
  ({String text, Key key})? _subtitle() {
    final current = wallet;
    if (current is MultisigWalletItem) {
      return (
        text: '${current.requiredSignatureCount}/${current.signers.length}',
        key: const Key('wallet-card-quorum'),
      );
    }
    final mfp = walletMasterFingerprint(current);
    return mfp == null ? null : (text: formatMfp(mfp), key: const Key('wallet-card-mfp'));
  }

  Widget _buildWide(BuildContext context) {
    final colors = context.coconutColors;
    final subtitle = _subtitle();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(),
            CoconutLayout.spacing_200w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_buildName(context), _buildSubtitleRow(context, subtitle)],
              ),
            ),
            if (statusBadge != null) statusBadge!,
            CoconutLayout.spacing_200w,
            Flexible(
              child: Container(
                constraints: const BoxConstraints(minHeight: kHomeWidgetHeaderHeight),
                alignment: Alignment.centerRight,
                child: FittedBox(fit: BoxFit.scaleDown, child: _buildGlyph(context)),
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child:
                  balanceDisplay == null
                      ? const SizedBox.shrink()
                      : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          balanceDisplay!,
                          key: const Key('wallet-card-balance'),
                          style: CoconutTypography.heading4_18_NumberBold.copyWith(color: colors.primaryText),
                        ),
                      ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmall(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: kHomeWidgetHeaderHeight),
                    alignment: Alignment.centerRight,
                    child: FittedBox(fit: BoxFit.scaleDown, child: _buildGlyph(context)),
                  ),
                  if (secondaryText != null) ...[
                    Text(
                      secondaryText!,
                      key: const Key('wallet-card-secondary'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: CoconutTypography.body3_12_Bold.copyWith(
                        color: context.coconutColors.primaryText,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (statusBadge != null) ...[const SizedBox(width: 4), statusBadge!],
          ],
        ),
        if (balanceDisplay != null) ...[
          Expanded(
            child: Align(
              // Preserve the original 3:2 spacing while letting enlarged text fit vertically.
              alignment: const Alignment(-1, 0.2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  balanceDisplay!,
                  key: const Key('wallet-card-balance'),
                  style: CoconutTypography.heading4_18_NumberBold.copyWith(color: context.coconutColors.primaryText),
                ),
              ),
            ),
          ),
        ] else
          const Spacer(),
        _buildName(context),
        _buildSubtitleRow(context, _subtitle()),
      ],
    );
  }
}

/// 글자 모양 안쪽에만 그림자를 그리는 양각 글자. 글자 면은 투명해 배경이 그대로 보인다.
class _EmbossedText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _EmbossedText({super.key, required this.text, required this.style});

  /// 글자 안쪽 바탕과 (색, 그림자 방향). 카드 바탕색에서 밝기만 바꿔 써서 어느 테마에서도 같은 색 계열로 파여 보인다.
  static (Color, List<(Color, Offset)>) _toneOf(Color surface) => (
    Color.lerp(surface, const Color(0xFF000000), 0.07)!,
    [
      (Color.lerp(surface, const Color(0xFFFFFFFF), 0.7)!, const Offset(1, 1)),
      (Color.lerp(surface, const Color(0xFF000000), 0.42)!, const Offset(-1, -1)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return Semantics(
      label: text,
      child: CustomPaint(
        size: size,
        painter: _EmbossedTextPainter(text, style, Directionality.of(context), context.coconutColors.homeSurface),
      ),
    );
  }
}

class _EmbossedTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final TextDirection textDirection;
  final Color surface;

  _EmbossedTextPainter(this.text, this.style, this.textDirection, this.surface);

  TextPainter _layout(Paint paint) => TextPainter(
    text: TextSpan(text: text, style: style.copyWith(foreground: paint)),
    textDirection: textDirection,
    textScaler: TextScaler.noScaling,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).inflate(4);
    final (fill, shadows) = _EmbossedText._toneOf(surface);
    final base = _layout(Paint()..color = fill);
    base.paint(canvas, Offset.zero);
    base.dispose();
    for (final (color, offset) in shadows) {
      canvas.saveLayer(bounds, Paint());
      final glyph = _layout(Paint()..color = color);
      glyph.paint(canvas, Offset.zero);
      final cutout = _layout(
        Paint()
          ..color = const Color(0xFF000000)
          ..blendMode = BlendMode.dstOut
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5),
      );
      cutout.paint(canvas, offset);
      canvas.restore();
      glyph.dispose();
      cutout.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _EmbossedTextPainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.surface != surface;
}
