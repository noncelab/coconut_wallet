import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_export_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_import_screen.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LabelManagementScreen extends StatefulWidget {
  final int? walletId;
  final bool showImportMemosFromOtherWalletsOption;

  const LabelManagementScreen({super.key, this.walletId, this.showImportMemosFromOtherWalletsOption = true});

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
              title: t.label_management_screen.title,
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
    final clampedTextScaler = TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2));

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: clampedTextScaler),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          children: [
            _buildInfoTooltip(context),
            const SizedBox(height: 21),
            ButtonGroup(
              buttons: [
                SingleButton(
                  title: t.label_management_screen.import_title,
                  subtitle: t.label_management_screen.import_description,
                  onPressed: () => _navigateToImportFilePicker(context, walletId: widget.walletId),
                  enableShrinkAnim: true,
                  isVerticalSubtitle: true,
                ),
                SingleButton(
                  title: t.label_management_screen.export_title,
                  subtitle: t.label_management_screen.export_description,
                  onPressed: () => _navigateToExportWalletPicker(context, walletId: widget.walletId),
                  enableShrinkAnim: true,
                  isVerticalSubtitle: true,
                ),
              ],
            ),
          ],
        ),
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
              text: '${t.label_management_screen.tooltip.title}\n',
              style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
            ),
            TextSpan(
              text: '${t.label_management_screen.tooltip.description}\n\n',
              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
            ),
            TextSpan(
              text: '${t.label_management_screen.tooltip.supported_title}\n',
              style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
            ),
            TextSpan(
              text: t.label_management_screen.tooltip.supported_list,
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
              t.label_management_screen.description,
              style: CoconutTypography.body3_12.copyWith(color: context.coconutColors.popoverText, height: 1.3),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToImportFilePicker(BuildContext context, {int? walletId}) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder:
            (context) => LabelImportScreen(
              walletId: walletId,
              showImportMemosFromOtherWalletsOption: widget.showImportMemosFromOtherWalletsOption,
            ),
      ),
    );
  }

  void _navigateToExportWalletPicker(BuildContext context, {int? walletId}) {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (context) => LabelExportScreen(initialSelectedWalletId: walletId)));
  }
}

class _LabelManagementActionScreen extends StatefulWidget {
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
  State<_LabelManagementActionScreen> createState() => _LabelManagementActionScreenState();
}

class _LabelManagementActionScreenState extends State<_LabelManagementActionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(title: widget.title, context: context),
      body: Stack(
        children: [
          _buildContentView(context),
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(text: widget.actionButtonText, onButtonClicked: widget.onAction),
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
                    text: '${widget.title}\n\n',
                    style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                  ),
                  TextSpan(
                    text: widget.description,
                    style: CoconutTypography.body1_16.setColor(context.coconutColors.secondaryText),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.coconutColors.primary.withValues(alpha: 0.1),
            ),
            child: SvgPicture.asset(
              widget.iconPath,
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
