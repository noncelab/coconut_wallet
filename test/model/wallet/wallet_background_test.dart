import 'package:coconut_wallet/constants/wallet_skins.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletBackground json', () {
    test('skin round-trips', () {
      const background = WalletSkinBackground('mint');
      expect(WalletBackground.fromJson(background.toJson()), background);
    });

    test('solid color round-trips', () {
      const background = WalletColorBackground(0xFFBFDFFF);
      expect(WalletBackground.fromJson(background.toJson()), background);
    });

    test('photo round-trips with framing', () {
      const background = WalletPhotoBackground(
        fileName: 'wallet_1_1.jpg',
        aspectRatio: 1.5,
        focusX: -0.4,
        focusY: 0.7,
        scale: 2,
      );
      expect(WalletBackground.fromJson(background.toJson()), background);
    });

    test('unknown or broken values → null', () {
      expect(WalletBackground.fromJson(null), isNull);
      expect(WalletBackground.fromJson({'type': 'gif'}), isNull);
      expect(WalletBackground.fromJson({'type': 'photo', 'fileName': 'a.jpg'}), isNull);
      expect(WalletBackground.fromJson({'type': 'photo', 'fileName': 'a.jpg', 'aspectRatio': 0}), isNull);
      expect(WalletBackground.fromJson({'type': 'photo', 'fileName': '../a.jpg', 'aspectRatio': 1}), isNull);
      expect(WalletBackground.fromJson({'type': 'photo', 'fileName': '/tmp/a.jpg', 'aspectRatio': 1}), isNull);
    });

    test('loaded photo framing is clamped into the model range', () {
      final loaded = WalletBackground.fromJson({
        'type': 'photo',
        'fileName': 'wallet_1_1.jpg',
        'aspectRatio': 1.5,
        'focusX': 8,
        'focusY': -4,
        'scale': -2,
      });

      expect(loaded, isA<WalletPhotoBackground>());
      final photo = loaded! as WalletPhotoBackground;
      expect(photo.focusX, 1);
      expect(photo.focusY, -1);
      expect(photo.scale, 1);
    });

    test('photo framing is clamped', () {
      const photo = WalletPhotoBackground(fileName: 'a.jpg', aspectRatio: 1);
      final moved = photo.copyWith(focusX: 3, focusY: -3, scale: 0.2);
      expect(moved.focusX, 1);
      expect(moved.focusY, -1);
      expect(moved.scale, 1);
      expect(photo.copyWith(scale: 99).scale, WalletPhotoBackground.maxScale);
    });
  });

  test('skin ids and palette colors are unique', () {
    final skinIds = walletSkins.map((skin) => skin.id).toList();
    final colors = walletPaletteColors.map((color) => color.toARGB32()).toList();
    expect(skinIds.toSet().length, skinIds.length);
    expect(colors.toSet().length, colors.length);
  });

  group('photoRect', () {
    test('wide photo in a square box fills the height and centers', () {
      final rect = WalletCardBackground.photoRect(const Size(100, 100), 2);
      expect(rect, const Rect.fromLTWH(-50, 0, 200, 100));
    });

    test('tall photo in a wide box fills the width', () {
      final rect = WalletCardBackground.photoRect(const Size(200, 100), 0.5);
      expect(rect.width, 200);
      expect(rect.height, 400);
      expect(rect.top, -150);
    });

    test('focus moves the photo to its edge', () {
      final left = WalletCardBackground.photoRect(const Size(100, 100), 2, focusX: -1);
      final right = WalletCardBackground.photoRect(const Size(100, 100), 2, focusX: 1);
      expect(left.left, 0);
      expect(right.right, 100);
    });

    test('scale enlarges around the focus', () {
      final rect = WalletCardBackground.photoRect(const Size(100, 100), 1, scale: 2);
      expect(rect, const Rect.fromLTWH(-50, -50, 200, 200));
    });
  });

  group('framePhoto', () {
    const photo = WalletPhotoBackground(fileName: 'a.jpg', aspectRatio: 2);
    const box = Size(100, 100);

    test('is the inverse of photoRect', () {
      final framed = photo.copyWith(focusX: 0.4, focusY: -0.3, scale: 1.8);
      final rect = WalletCardBackground.photoRect(
        box,
        framed.aspectRatio,
        focusX: framed.focusX,
        focusY: framed.focusY,
        scale: framed.scale,
      );
      final back = WalletCardBackground.framePhoto(photo, box, rect);
      expect(back.scale, closeTo(1.8, 1e-9));
      expect(back.focusX, closeTo(0.4, 1e-9));
      expect(back.focusY, closeTo(-0.3, 1e-9));
    });

    test('keeps the box covered when moved past an edge', () {
      final back = WalletCardBackground.framePhoto(photo, box, const Rect.fromLTWH(30, 0, 200, 100));
      expect(back.focusX, -1);
    });
  });
}
