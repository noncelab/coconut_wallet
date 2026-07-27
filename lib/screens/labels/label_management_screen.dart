import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum _LabelManagementView { menu, import, export }

class LabelManagementScreen extends StatelessWidget {
  final String importDescription;
  final String exportDescription;
  final VoidCallback onImport;
  final VoidCallback onExport;

  const LabelManagementScreen({
    super.key,
    required this.importDescription,
    required this.exportDescription,
    required this.onImport,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return _LabelManagementScreenContent(
      importDescription: importDescription,
      exportDescription: exportDescription,
      onImport: onImport,
      onExport: onExport,
    );
  }
}

class _LabelManagementScreenContent extends StatefulWidget {
  final String importDescription;
  final String exportDescription;
  final VoidCallback onImport;
  final VoidCallback onExport;

  const _LabelManagementScreenContent({
    required this.importDescription,
    required this.exportDescription,
    required this.onImport,
    required this.onExport,
  });

  @override
  State<_LabelManagementScreenContent> createState() => _LabelManagementScreenContentState();
}

class _LabelManagementScreenContentState extends State<_LabelManagementScreenContent> {
  _LabelManagementView _currentView = _LabelManagementView.menu;

  String get _appBarTitle {
    switch (_currentView) {
      case _LabelManagementView.import:
        return t.wallet_info_screen.import_labels;
      case _LabelManagementView.export:
        return t.wallet_info_screen.export_labels;
      case _LabelManagementView.menu:
        return t.labels_management_bottom_sheet.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(
        title: _appBarTitle,
        context: context,
        onBackPressed:
            _currentView != _LabelManagementView.menu
                ? () => setState(() => _currentView = _LabelManagementView.menu)
                : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentView) {
      case _LabelManagementView.import:
        return _buildActionView(
          title: t.wallet_info_screen.import_labels,
          description: widget.importDescription,
          iconPath: 'assets/svg/import.svg',
          actionButtonText: t.import,
          onAction: widget.onImport,
        );
      case _LabelManagementView.export:
        return _buildActionView(
          title: t.wallet_info_screen.export_labels,
          description: widget.exportDescription,
          iconPath: 'assets/svg/export.svg',
          actionButtonText: t.export,
          onAction: widget.onExport,
        );
      case _LabelManagementView.menu:
        return _buildMenuView();
    }
  }

  Widget _buildMenuView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoconutLayout.spacing_400h,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      t.labels_management_bottom_sheet.title,
                      style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                    ),
                    CoconutLayout.spacing_100w,
                    Text(t.labels_management_bottom_sheet.feature, style: CoconutTypography.body2_14_Bold),
                  ],
                ),
                CoconutLayout.spacing_100h,
                Text(
                  t.labels_management_bottom_sheet.description,
                  style: CoconutTypography.body3_12.setColor(context.coconutColors.tertiaryText),
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_1000h,
          ButtonGroup(
            buttons: [
              SingleButton(
                title: t.wallet_info_screen.import_labels,
                onPressed: () => setState(() => _currentView = _LabelManagementView.import),
              ),
              SingleButton(
                title: t.wallet_info_screen.export_labels,
                onPressed: () => setState(() => _currentView = _LabelManagementView.export),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionView({
    required String title,
    required String description,
    required String iconPath,
    required String actionButtonText,
    required VoidCallback onAction,
  }) {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.coconutColors.primary.withOpacity(0.1),
                  ),
                  child: SvgPicture.asset(
                    iconPath,
                    width: 40,
                    height: 40,
                    colorFilter: ColorFilter.mode(context.coconutColors.primary, BlendMode.srcIn),
                  ),
                ),
                CoconutLayout.spacing_1000h,
                Text(
                  title,
                  style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                  textAlign: TextAlign.center,
                ),
                CoconutLayout.spacing_500h,
                Text(
                  description,
                  style: CoconutTypography.body1_16.setColor(context.coconutColors.secondaryText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 150),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FixedBottomButton(text: actionButtonText, onButtonClicked: onAction),
        ),
      ],
    );
  }
}
