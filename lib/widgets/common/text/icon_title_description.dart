import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class IconTitleDescription extends StatelessWidget {
  final String svgIconPath;
  final String title;
  final String description;

  const IconTitleDescription({super.key, required this.svgIconPath, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    const iconSize = 18.0;
    const iconTextGap = 8.0;
    final titleStyle = CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText);
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: DefaultTextStyle.of(context).style.merge(titleStyle)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final firstLineHeight = titlePainter.preferredLineHeight;
    titlePainter.dispose();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: iconSize,
              height: firstLineHeight,
              child: Center(
                child: SvgPicture.asset(svgIconPath, width: iconSize, height: iconSize, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: iconTextGap),
            Expanded(child: Text(title, style: titleStyle)),
          ],
        ),
        CoconutLayout.spacing_200h,
        Padding(
          padding: const EdgeInsetsDirectional.only(start: iconSize + iconTextGap),
          child: Text(
            description,
            style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText).copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
