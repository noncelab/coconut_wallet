import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';

class ExpandableInfo {
  final String titleText;
  final List<String> descriptionList;
  final String? addressText;

  const ExpandableInfo({required this.titleText, required this.descriptionList, this.addressText});
}

class ExpandableInfoCard extends StatefulWidget {
  final String descriptionText;
  final List<ExpandableInfo> sections;
  final String collapsedIconAsset;
  final String expandedIconAsset;

  const ExpandableInfoCard({
    super.key,
    required this.descriptionText,
    required this.sections,
    this.collapsedIconAsset = CommonStateIconPath.circleHelp,
    this.expandedIconAsset = CommonStateIconPath.circleWarning,
  });

  @override
  State<ExpandableInfoCard> createState() => _ExpandableInfoCardState();
}

class _ExpandableInfoCardState extends State<ExpandableInfoCard> {
  bool _isExpanded = false;

  TextPainter _buildDescriptionTextPainter(
    BuildContext context, {
    required String text,
    required TextStyle style,
    required double maxWidth,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final descriptionText = widget.descriptionText;
    final descriptionStyle = CoconutTypography.body2_14.setColor(colors.primaryText);

    return Container(
      padding: const EdgeInsets.all(CoconutLayout.defaultPadding),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(CoconutStyles.radius_200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              color: Colors.transparent,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textPainter = _buildDescriptionTextPainter(
                    context,
                    text: descriptionText,
                    style: descriptionStyle,
                    maxWidth: constraints.maxWidth - 24,
                  );
                  final isSingleLine = textPainter.computeLineMetrics().length == 1;
                  final firstLineCenterOffset = ((textPainter.preferredLineHeight - 20) / 2).clamp(
                    0.0,
                    double.infinity,
                  );

                  return Row(
                    crossAxisAlignment: isSingleLine ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: isSingleLine ? 0 : firstLineCenterOffset),
                        child: SvgPicture.asset(
                          _isExpanded ? widget.expandedIconAsset : widget.collapsedIconAsset,
                          width: 20,
                          colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                        ),
                      ),
                      CoconutLayout.spacing_100w,
                      Expanded(child: Text(descriptionText, style: descriptionStyle)),
                    ],
                  );
                },
              ),
            ),
          ),
          if (_isExpanded) ...[
            for (int i = 0; i < widget.sections.length; i++) ...[
              if (i > 0) CoconutLayout.spacing_200h,
              _buildWalletInfoSection(
                context: context,
                titleText: widget.sections[i].titleText,
                descriptionList: widget.sections[i].descriptionList,
                addressText: widget.sections[i].addressText,
              ),
            ],
            CoconutLayout.spacing_200h,
          ],
        ],
      ),
    );
  }

  Widget _buildWalletInfoSection({
    required BuildContext context,
    required String titleText,
    required List<String> descriptionList,
    String? addressText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titleText, style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sizes.size12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...descriptionList.map(
                (desc) => Text(desc, style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText)),
              ),
              if (addressText != null) ...[
                CoconutLayout.spacing_200h,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sizes.size8),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.coconutColors.background,
                      borderRadius: const BorderRadius.all(Radius.circular(CoconutStyles.radius_100)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: Sizes.size12, vertical: Sizes.size8),
                    child: RichText(
                      text: TextSpan(
                        text: addressText.substring(0, 4),
                        style:
                            addressText.startsWith("zpub")
                                ? CoconutTypography.body3_12_NumberBold.setColor(context.coconutColors.primaryText)
                                : CoconutTypography.body3_12_Number.setColor(context.coconutColors.primaryText),
                        children: [
                          TextSpan(
                            text: addressText.substring(4),
                            style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.primaryText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
