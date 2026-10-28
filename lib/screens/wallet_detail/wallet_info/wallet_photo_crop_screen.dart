import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/widgets/features/home/span_size_option.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 고른 사진을 카드 모양 틀에 맞춰 옮기고 확대하는 단계. 완료하면 위치·배율을 담은 [WalletPhotoBackground]를 돌려준다.
class WalletPhotoCropScreen extends StatefulWidget {
  static const String routeName = '/wallet-photo-crop';

  final WalletPhotoBackground photo;
  final File file;
  final WalletCardSize initialSize;

  const WalletPhotoCropScreen({super.key, required this.photo, required this.file, required this.initialSize});

  /// 틀 크기. 4×2는 홈 그리드처럼 정사각형 두 칸과 간격을 합친 비율, 2×2는 정사각형.
  static Size frameSize(Size area, WalletCardSize size) {
    final width = area.width - 48;
    final maxHeight = area.height - 32;
    if (size == WalletCardSize.wide) {
      final wide = Size(width, (width - 12) / 2);
      return wide.height > maxHeight ? wide * (maxHeight / wide.height) : wide;
    }
    return Size.square((width * 0.75).clamp(0.0, maxHeight));
  }

  @override
  State<WalletPhotoCropScreen> createState() => _WalletPhotoCropScreenState();
}

class _WalletPhotoCropScreenState extends State<WalletPhotoCropScreen> {
  static final _darkThemeExtension = CoconutThemeExtension.dark();

  late WalletPhotoBackground _photo = widget.photo;
  late WalletCardSize _size = widget.initialSize;

  WalletPhotoBackground? _startPhoto;
  Rect? _startRect;
  Offset? _startFocal;

  Rect _rectOf(WalletPhotoBackground photo, Size frame) => WalletCardBackground.photoRect(
    frame,
    photo.aspectRatio,
    focusX: photo.focusX,
    focusY: photo.focusY,
    scale: photo.scale,
  );

  void _onScaleStart(ScaleStartDetails details, Rect frame) {
    _startPhoto = _photo;
    _startRect = _rectOf(_photo, frame.size);
    _startFocal = details.localFocalPoint - frame.topLeft;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Rect frame) {
    final startPhoto = _startPhoto;
    final startRect = _startRect;
    final startFocal = _startFocal;
    if (startPhoto == null || startRect == null || startFocal == null) return;
    final cover = WalletCardBackground.photoRect(frame.size, startPhoto.aspectRatio);
    final scale = (startPhoto.scale * details.scale).clamp(1.0, WalletPhotoBackground.maxScale);
    final size = cover.size * scale;
    final anchor = Offset(
      (startFocal.dx - startRect.left) / startRect.width,
      (startFocal.dy - startRect.top) / startRect.height,
    );
    final focal = details.localFocalPoint - frame.topLeft;
    final topLeft = Offset(focal.dx - anchor.dx * size.width, focal.dy - anchor.dy * size.height);
    setState(() => _photo = WalletCardBackground.framePhoto(startPhoto, frame.size, topLeft & size));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Theme(
        data: Theme.of(context).copyWith(brightness: Brightness.dark, extensions: [_darkThemeExtension]),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    t.wallet_appearance_screen.crop_title,
                    style: CoconutTypography.body1_16_Bold.copyWith(color: Colors.white),
                  ),
                ),
                Expanded(child: LayoutBuilder(builder: (context, constraints) => _cropArea(constraints.biggest))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final size in WalletCardSize.values)
                      SpanSizeOption(
                        key: Key('wallet-photo-crop-size-${size.name}'),
                        columns: size == WalletCardSize.wide ? 4 : 2,
                        rows: 2,
                        isSelected: _size == size,
                        onTap: () => setState(() => _size = size),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _textButton(
                        key: const Key('wallet-photo-crop-cancel'),
                        text: t.cancel,
                        onTap: () => Navigator.pop(context),
                      ),
                      _textButton(
                        key: const Key('wallet-photo-crop-done'),
                        text: t.done,
                        bold: true,
                        onTap: () => Navigator.pop(context, _photo),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cropArea(Size area) {
    final frameSize = WalletPhotoCropScreen.frameSize(area, _size);
    final frame = Alignment.center.inscribe(frameSize, Offset.zero & area);
    final imageRect = _rectOf(_photo, frame.size).shift(frame.topLeft);
    return GestureDetector(
      key: const Key('wallet-photo-crop-area'),
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) => _onScaleStart(details, frame),
      onScaleUpdate: (details) => _onScaleUpdate(details, frame),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: imageRect,
              child: Image.file(widget.file, fit: BoxFit.fill, gaplessPlayback: true),
            ),
            Positioned.fill(child: CustomPaint(painter: _FramePainter(frame, const Radius.circular(20)))),
          ],
        ),
      ),
    );
  }

  Widget _textButton({required Key key, required String text, required VoidCallback onTap, bool bold = false}) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: (bold ? CoconutTypography.body1_16_Bold : CoconutTypography.body1_16).copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// 틀 바깥을 어둡게 덮고 틀 테두리를 그린다.
class _FramePainter extends CustomPainter {
  final Rect frame;
  final Radius radius;

  const _FramePainter(this.frame, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(frame, radius);
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(hole)),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) => oldDelegate.frame != frame || oldDelegate.radius != radius;
}
