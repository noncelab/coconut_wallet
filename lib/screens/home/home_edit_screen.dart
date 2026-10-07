import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutSegmentedControl, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/screens/home/shortcut_configure_sheet.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

enum HomeEditTab { presets, widgets, shortcuts }

class HomeEditScreen extends StatefulWidget {
  final HomeEditTab initialTab;

  const HomeEditScreen({super.key, this.initialTab = HomeEditTab.presets});

  @override
  State<HomeEditScreen> createState() => _HomeEditScreenState();
}

class _HomeEditScreenState extends State<HomeEditScreen> {
  late HomeEditTab _tab = widget.initialTab;

  HomeViewModel get _viewModel => context.read<HomeViewModel>();

  Future<void> _add(HomeItemDefinition definition) async {
    final viewModel = _viewModel;
    if (definition is! ShortcutDefinition || !definition.requiresWalletContext) {
      viewModel.addItem(definition);
      return;
    }
    final walletContext =
        viewModel.walletContextWithoutAsking() ??
        await CommonBottomSheets.showBottomSheet_100<ShortcutWalletContext>(
          context: context,
          screenName: '/shortcut-configure-sheet',
          isDismissible: true,
          backgroundColor: context.coconutColors.surfaceBottomSheet,
          child: ShortcutConfigureSheet(
            feature: definition.feature,
            wallets: viewModel.wallets,
            current: viewModel.shortcutWalletContext,
            hasOtherWalletShortcuts: viewModel.hasWalletShortcutsOnHome,
          ),
        );
    if (walletContext == null || !mounted) return;
    viewModel.addItem(definition, walletContext: walletContext);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<HomeViewModel>();
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: colors.background,
        title: t.home_edit.title,
        actionButtonList: [
          CupertinoButton(
            key: const Key('home-edit-done'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            minimumSize: Size.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.done, style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CoconutSegmentedControl(
                selectedColor: colors.segmentedControlSelected,
                segmentedControlContainerColor: colors.segmentedControlBackground,
                selectedTextColor: colors.segmentedControlSelectedText,
                unselectedTextColor: colors.segmentedControlUnselectedText,
                isSelected: [for (final tab in HomeEditTab.values) tab == _tab],
                onPressed: (index) => setState(() => _tab = HomeEditTab.values[index]),
                children: [Text(t.home_edit.presets), Text(t.home_edit.widgets), Text(t.home_edit.shortcuts)],
              ),
            ),
            CoconutLayout.spacing_300h,
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('home-edit-tab-${_tab.name}'),
                child: switch (_tab) {
                  HomeEditTab.presets => const SizedBox.expand(),
                  HomeEditTab.widgets => _buildWidgetsTab(context, viewModel),
                  HomeEditTab.shortcuts => _buildShortcutsTab(context, viewModel),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(HomeViewModel viewModel, HomeItemDefinition definition) {
    final onHome = viewModel.isOnHome(definition);
    return CupertinoButton(
      key: ValueKey('home-edit-${onHome ? 'remove' : 'add'}-${definition.id}'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(32, 32),
      onPressed: () => onHome ? viewModel.removeDefinition(definition) : _add(definition),
      child: Icon(
        onHome ? CupertinoIcons.minus_circle_fill : CupertinoIcons.add_circled_solid,
        color: context.coconutColors.secondaryText,
        size: 28,
      ),
    );
  }

  Widget _buildWidgetsTab(BuildContext context, HomeViewModel viewModel) {
    final colors = context.coconutColors;
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - 32;
        final smallWidth = (contentWidth - gap) / 2;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: gap,
            runSpacing: 24,
            children: [
              for (final definition in viewModel.widgetDefinitions)
                SizedBox(
                  key: ValueKey('home-edit-widget-${definition.id}'),
                  width: definition.supportedSpans.first == HomeSpan.wide ? contentWidth : smallWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: smallWidth,
                        child: IgnorePointer(
                          child: definition.build(
                            context,
                            HomeItem(
                              id: 'preview-${definition.id}',
                              definitionId: definition.id,
                              kind: definition.kind,
                              order: 0,
                              span: definition.supportedSpans.first,
                            ),
                          ),
                        ),
                      ),
                      CoconutLayout.spacing_200h,
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              definition.displayName(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: CoconutTypography.body2_14.copyWith(color: colors.primaryText),
                            ),
                          ),
                          _buildToggleButton(viewModel, definition),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShortcutRow(BuildContext context, HomeViewModel viewModel, ShortcutDefinition definition) {
    final colors = context.coconutColors;
    final iconPath = definition.feature.iconPath;
    return Padding(
      key: ValueKey('home-edit-shortcut-${definition.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(10)),
            child:
                iconPath == null
                    ? null
                    : SvgPicture.asset(
                      iconPath,
                      width: 20 * definition.feature.iconScale,
                      height: 20 * definition.feature.iconScale,
                      colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                    ),
          ),
          CoconutLayout.spacing_300w,
          Expanded(
            child: Text(
              definition.displayName(),
              style: CoconutTypography.body1_16.copyWith(color: colors.primaryText),
            ),
          ),
          _buildToggleButton(viewModel, definition),
        ],
      ),
    );
  }

  Widget _buildShortcutsTab(BuildContext context, HomeViewModel viewModel) {
    final colors = context.coconutColors;
    final onHome = viewModel.shortcutsOnHome;
    final available = viewModel.shortcutDefinitions.where((definition) => !viewModel.isOnHome(definition)).toList();
    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text, style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText)),
    );
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        header(t.home_edit.shortcuts_on_home),
        for (final definition in onHome) _buildShortcutRow(context, viewModel, definition),
        CoconutLayout.spacing_400h,
        header(t.home_edit.available_shortcuts),
        for (final definition in available) _buildShortcutRow(context, viewModel, definition),
      ],
    );
  }
}
