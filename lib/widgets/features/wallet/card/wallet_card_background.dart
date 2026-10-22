import 'dart:io';

import 'package:coconut_wallet/constants/wallet_skins.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:flutter/material.dart';

/// 지갑 카드 배경을 칸 전체에 채워 그린다. 모서리 자르기는 감싸는 쪽이 한다.
///
/// - 스킨·단색: 테마와 상관없이 고른 색 그대로 그린다. 위에 얹는 글자색은 [WalletCard]가 배경 밝기에 맞춘다.
/// - 사진: [photoRect] 위치에 그리고, 위에 테마 바탕색 반투명 막을 깔아 테마 글자색이 잘 보이게 한다.
/// - 사진 파일이 없거나 읽지 못하면 테마 바탕만 그린다.
class WalletCardBackground extends StatelessWidget {
  final WalletBackground? background;
  final File? photoFile;
  final bool resizePhotoToDisplaySize;

  const WalletCardBackground({
    super.key,
    required this.background,
    this.photoFile,
    this.resizePhotoToDisplaySize = false,
  });

  /// 한 가지 색으로만 칠할 수 있는 곳(도넛 차트 등)에서 배경을 대신하는 색. 사진은 대표 색이 없어 null.
  static Color? representativeColorOf(WalletBackground? background) => switch (background) {
    WalletSkinBackground(:final skinId) => WalletSkin.byId(skinId)?.base,
    WalletColorBackground(:final color) => color,
    _ => null,
  };

  static const double lightPhotoScrimOpacity = 0.4;
  static const double darkPhotoScrimOpacity = 0.5;

  /// [box] 칸을 `cover`로 채운 뒤 [scale]만큼 키운 사진의 위치. 남는 부분은 [focusX], [focusY]로 나눈다.
  static Rect photoRect(Size box, double aspectRatio, {double focusX = 0, double focusY = 0, double scale = 1}) {
    final coverWidth = box.width / box.height > aspectRatio ? box.width : box.height * aspectRatio;
    final width = coverWidth * scale;
    final height = width / aspectRatio;
    return Rect.fromLTWH(
      (box.width - width) * (focusX + 1) / 2,
      (box.height - height) * (focusY + 1) / 2,
      width,
      height,
    );
  }

  /// [photoRect]의 역. [box] 안에서 사진이 [rect] 자리에 오도록 하는 위치·배율. 칸이 빈틈없이 덮이도록 맞춘다.
  static WalletPhotoBackground framePhoto(WalletPhotoBackground photo, Size box, Rect rect) {
    final cover = photoRect(box, photo.aspectRatio);
    double focusOf(double offset, double boxExtent, double extent) {
      final slack = boxExtent - extent;
      return slack.abs() < 0.5 ? 0 : 2 * offset / slack - 1;
    }

    return photo.copyWith(
      scale: rect.width / cover.width,
      focusX: focusOf(rect.left, box.width, rect.width),
      focusY: focusOf(rect.top, box.height, rect.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.coconutColors.homeSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = this.background;
    return switch (background) {
      WalletSkinBackground(:final skinId) => _skin(WalletSkin.byId(skinId), surface),
      WalletColorBackground(:final color) => ColoredBox(color: color),
      WalletPhotoBackground() => _photo(background, surface, isDark),
      null => ColoredBox(color: surface),
    };
  }

  Widget _skin(WalletSkin? skin, Color surface) {
    if (skin == null) return ColoredBox(color: surface);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: skin.base),
        for (final blob in skin.blobs)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: blob.center,
                radius: 0.8,
                colors: [blob.color.withValues(alpha: 0.8), blob.color.withValues(alpha: 0)],
              ),
            ),
          ),
      ],
    );
  }

  Widget _photo(WalletPhotoBackground background, Color surface, bool isDark) {
    final file = photoFile;
    if (file == null) return ColoredBox(color: surface);
    return ColoredBox(
      color: surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rect = photoRect(
            constraints.biggest,
            background.aspectRatio,
            focusX: background.focusX,
            focusY: background.focusY,
            scale: background.scale,
          );
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fromRect(
                rect: rect,
                child: Image.file(
                  file,
                  cacheWidth:
                      resizePhotoToDisplaySize
                          ? (rect.width * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(1, 4096)
                          : null,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              ColoredBox(color: surface.withValues(alpha: isDark ? darkPhotoScrimOpacity : lightPhotoScrimOpacity)),
            ],
          );
        },
      ),
    );
  }
}
