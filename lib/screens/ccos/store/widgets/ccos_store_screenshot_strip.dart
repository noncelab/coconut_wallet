import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

/// 기능 상세 FEATURE 장의 스틸 사진 가로 목록. 사진 아래 한 줄 설명
class CcosStoreScreenshotStrip extends StatelessWidget {
  const CcosStoreScreenshotStrip({super.key, required this.screenshots});

  static const double _width = 180;
  static const double _imageHeight = 352;

  final List<CcosFeatureScreenshot> screenshots;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final locale = LocaleSettings.currentLocale;
    const captionStyle = CoconutTypography.body3_12;
    final captionLineHeight =
        MediaQuery.textScalerOf(context).scale(captionStyle.fontSize!) * (captionStyle.height ?? 1.5);
    return SizedBox(
      height: _imageHeight + 8 + captionLineHeight * 2 + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: screenshots.length,
        separatorBuilder: (_, __) => CoconutLayout.spacing_300w,
        itemBuilder: (context, index) {
          final shot = screenshots[index];
          return SizedBox(
            width: _width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: _width,
                  height: _imageHeight,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Image.asset(shot.assetPathFor(locale), fit: BoxFit.cover, alignment: Alignment.topCenter),
                ),
                CoconutLayout.spacing_200h,
                Text(
                  shot.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: captionStyle.setColor(colors.secondaryText),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
