import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_feature_icon.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_scope.dart';
import 'package:flutter/material.dart';

/// 스토어 카드의 썸네일. 코코넛 테마는 소개 화면의 이미지 조각, 나머지는 새 이미지가 오기 전까지 아이콘
class CcosStoreFeatureThumbnail extends StatelessWidget {
  const CcosStoreFeatureThumbnail({super.key, required this.listing});

  static const double height = 200;

  final CcosFeatureListing listing;

  static const List<_Piece> _themePieces = [
    _Piece('assets/images/ccos/preview_transaction_card.png', Alignment(0.0, 0.1), 200, -0.035),
    _Piece('assets/images/ccos/preview_address_bar.png', Alignment(-0.22, 0.86), 204, 0.02),
    _Piece('assets/images/ccos/preview_arrow_up.png', Alignment(0.84, 0.8), 62, -0.06),
    _Piece('assets/images/ccos/preview_wallet_icon.png', Alignment(0.64, -0.72), 70, 0.08),
    _Piece('assets/images/ccos/preview_arrow_down.png', Alignment(-0.8, -0.64), 64, -0.09),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(color: CcosStoreScope.thumbnailColor),
      child:
          listing.id == CoconutThemeFeature.id
              ? Stack(
                children: [
                  for (final piece in _themePieces)
                    Align(
                      alignment: piece.alignment,
                      child: Transform.rotate(angle: piece.angle, child: Image.asset(piece.path, width: piece.width)),
                    ),
                ],
              )
              : Center(child: CcosStoreFeatureIcon(iconPath: listing.iconPath, size: 96, onSurface: true)),
    );
  }
}

class _Piece {
  const _Piece(this.path, this.alignment, this.width, this.angle);

  final String path;
  final Alignment alignment;
  final double width;
  final double angle;
}
