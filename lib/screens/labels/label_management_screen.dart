import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/labels/label_import_file_picker_screen.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LabelManagementScreen extends StatefulWidget {
  final String importDescription;
  final String exportDescription;
  final ValueChanged<String> onImport;
  final VoidCallback onExport;

  const LabelManagementScreen({
    super.key,
    required this.importDescription,
    required this.exportDescription,
    required this.onImport,
    required this.onExport,
  });

  @override
  State<LabelManagementScreen> createState() => _LabelManagementScreenState();
}

class _LabelManagementScreenState extends State<LabelManagementScreen> {
  final GlobalKey _tooltipIconKey = GlobalKey();
  Size? _tooltipIconSize;
  Offset? _tooltipIconPosition;
  bool _isTooltipVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTooltipPosition();
    });
  }

  void _updateTooltipPosition() {
    final renderBox = _tooltipIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _tooltipIconPosition = renderBox.localToGlobal(Offset.zero);
        _tooltipIconSize = renderBox.size;
      });
    }
  }

  void _toggleTooltip() {
    setState(() {
      _isTooltipVisible = !_isTooltipVisible;
    });
  }

  void _removeTooltip() {
    if (_isTooltipVisible) {
      setState(() {
        _isTooltipVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _removeTooltip,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: context.coconutColors.background,
            appBar: CoconutAppBar.build(
              title: t.labels_management_screen.title,
              context: context,
              actionButtonList: [
                IconButton(
                  key: _tooltipIconKey,
                  icon: SvgPicture.asset(
                    'assets/svg/question-mark.svg',
                    colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                  ),
                  onPressed: _toggleTooltip,
                ),
              ],
            ),
            body: _buildMenuView(context),
          ),
          if (_isTooltipVisible && _tooltipIconPosition != null && _tooltipIconSize != null) _buildTooltip(context),
        ],
      ),
    );
  }

  Widget _buildMenuView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          _buildInfoTooltip(context),
          CoconutLayout.spacing_1000h,
          ButtonGroup(
            buttons: [
              SingleButton(
                title: t.labels_management_screen.import_title,
                subtitle: t.labels_management_screen.import_description,
                onPressed: () => _navigateToImportFilePicker(context),
                isVerticalSubtitle: true,
              ),
              SingleButton(
                title: t.labels_management_screen.export_title,
                subtitle: t.labels_management_screen.export_description,
                onPressed:
                    () => _navigateToActionScreen(
                      context: context,
                      title: t.labels_management_screen.export_title,
                      description: widget.exportDescription,
                      iconPath: 'assets/svg/file.svg',
                      actionButtonText: t.labels_management_screen.export_title,
                      onAction: widget.onExport,
                    ),
                isVerticalSubtitle: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTooltip(BuildContext context) {
    return CoconutToolTip(
      backgroundColor: context.coconutColors.surface,
      borderColor: context.coconutColors.surface,
      icon: SvgPicture.asset(
        'assets/svg/circle-info.svg',
        width: 20,
        colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
      ),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(
        text: TextSpan(
          style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
          children: [
            TextSpan(
              text: '${t.labels_management_screen.tooltip.title}\n',
              style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
            ),
            TextSpan(
              text: '${t.labels_management_screen.tooltip.description}\n\n',
              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
            ),
            TextSpan(
              text: '${t.labels_management_screen.tooltip.supported_title}\n',
              style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
            ),
            TextSpan(
              text: t.labels_management_screen.tooltip.supported_list,
              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(BuildContext context) {
    return Positioned(
      top: _tooltipIconPosition!.dy + _tooltipIconSize!.height - 10,
      right: 18,
      child: GestureDetector(
        onTap: _removeTooltip,
        child: ClipPath(
          clipper: RightTriangleBubbleClipper(),
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.68,
            padding: const EdgeInsets.only(top: 28, left: 16, right: 16, bottom: 12),
            color: context.coconutColors.popoverBackground,
            child: Text(
              t.labels_management_screen.description,
              style: CoconutTypography.body3_12.copyWith(color: context.coconutColors.popoverText, height: 1.3),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToActionScreen({
    required BuildContext context,
    required String title,
    required String description,
    required String iconPath,
    required String actionButtonText,
    required VoidCallback onAction,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => _LabelManagementActionScreen(
              title: title,
              description: description,
              iconPath: iconPath,
              actionButtonText: actionButtonText,
              onAction: onAction,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(position: AnimationUtil.buildSlideInAnimation(animation), child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  void _navigateToImportFilePicker(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => LabelImportFilePickerScreen(
              onFileSelected: (filePath) {
                widget.onImport(filePath);
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(position: AnimationUtil.buildSlideInAnimation(animation), child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }
}

class _LabelManagementActionScreen extends StatelessWidget {
  final String title;
  final String description;
  final String iconPath;
  final String actionButtonText;
  final VoidCallback onAction;

  const _LabelManagementActionScreen({
    required this.title,
    required this.description,
    required this.iconPath,
    required this.actionButtonText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(title: title, context: context),
      body: Stack(
        children: [
          _buildContentView(context),
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(text: actionButtonText, onButtonClicked: onAction),
          ),
        ],
      ),
    );
  }

  Widget _buildContentView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CoconutToolTip(
            backgroundColor: context.coconutColors.surface,
            borderColor: context.coconutColors.surface,
            icon: SvgPicture.asset(
              'assets/svg/circle-info.svg',
              width: 20,
              colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
            ),
            tooltipType: CoconutTooltipType.fixed,
            richText: RichText(
              textAlign: TextAlign.start,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title\n\n',
                    style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                  ),
                  TextSpan(
                    text: description,
                    style: CoconutTypography.body1_16.setColor(context.coconutColors.secondaryText),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: context.coconutColors.primary.withOpacity(0.1)),
            child: SvgPicture.asset(
              iconPath,
              width: 40,
              height: 40,
              colorFilter: ColorFilter.mode(context.coconutColors.primary, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 150),
        ],
      ),
    );
  }
}
