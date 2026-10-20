import 'package:flutter/painting.dart';

/// 지갑 카드에 고를 수 있는 그라데이션 스킨
///
/// - [base] 위에 [blobs]를 퍼지는 원형 그라데이션으로 겹쳐 그린다.
/// - 테마와 상관없이 같은 색으로 그린다.
/// - [id]는 저장 값이므로 바꾸지 않는다. 순서는 화면에 보이는 순서다.
class WalletSkin {
  final String id;
  final Color base;
  final List<WalletSkinBlob> blobs;

  const WalletSkin({required this.id, required this.base, required this.blobs});

  static WalletSkin? byId(String id) {
    for (final skin in walletSkins) {
      if (skin.id == id) return skin;
    }
    return null;
  }
}

class WalletSkinBlob {
  final Alignment center;
  final Color color;

  const WalletSkinBlob(this.center, this.color);
}

const List<WalletSkin> walletSkins = [
  WalletSkin(id: 'mint', base: Color(0xFFEAF9F3), blobs: [WalletSkinBlob(Alignment(0.55, -0.6), Color(0xFFC3CEFF))]),
  WalletSkin(id: 'lemon', base: Color(0xFFF6F9E8), blobs: [WalletSkinBlob(Alignment(0.55, -0.6), Color(0xFFDCEFAE))]),
  WalletSkin(
    id: 'lavender',
    base: Color(0xFFF1EEFC),
    blobs: [WalletSkinBlob(Alignment(0.55, -0.6), Color(0xFFD2C6FF))],
  ),
  WalletSkin(id: 'peach', base: Color(0xFFFDF1EC), blobs: [WalletSkinBlob(Alignment(0.55, -0.6), Color(0xFFFFCDBE))]),
  WalletSkin(id: 'sky', base: Color(0xFFEBF3FC), blobs: [WalletSkinBlob(Alignment(0.55, -0.6), Color(0xFFBCD5FF))]),
  WalletSkin(id: 'rose', base: Color(0xFFFCEFF4), blobs: [WalletSkinBlob(Alignment(0.55, -0.6), Color(0xFFF7C6D8))]),
  WalletSkin(id: 'sand', base: Color(0xFFF8F3EA), blobs: [WalletSkinBlob(Alignment(0.55, -0.6), Color(0xFFE9D5B4))]),
  WalletSkin(id: 'aurora', base: Color(0xFFECF8F6), blobs: [WalletSkinBlob(Alignment(0.55, -0.6), Color(0xFFD5CBFF))]),
];

/// 단색 탭의 빠른 선택 견본. 색상환으로 다른 색도 고를 수 있다.
const List<Color> walletPaletteColors = [
  Color(0xFFE6E9ED),
  Color(0xFFEADBC3),
  Color(0xFFFFEBA8),
  Color(0xFFDDF2A6),
  Color(0xFFBDEFD9),
  Color(0xFFB5E8E8),
  Color(0xFFBFDFFF),
  Color(0xFFD6CCFF),
  Color(0xFFFFC9DC),
  Color(0xFFFFD2BF),
];
