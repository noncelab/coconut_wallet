import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutSegmentedControl, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_preset.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/screens/home/home_item_configure_sheets.dart';
import 'package:coconut_wallet/screens/home/home_preset_preview_screen.dart';
import 'package:coconut_wallet/screens/home/widget_configure_sheet.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
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
  /// 탭 내용 위쪽 그라데이션 높이. 처음 화면에서 내용이 흐려지지 않도록 목록은 [_contentTop]부터 시작한다.
  static const _topFadeHeight = 16.0;
  static const _contentTop = 20.0;

  late HomeEditTab _tab = widget.initialTab;
  HomeItemCategory? _widgetCategory;

  HomeViewModel get _viewModel => context.read<HomeViewModel>();

  Future<void> _add(HomeItemDefinition definition) async {
    final viewModel = _viewModel;
    if (definition.needsConfigureBeforeAdd) {
      final settings = await WidgetConfigureSheet.open(
        context,
        definition: definition,
        wallets: viewModel.wallets,
        previewBuilder: HomeItemConfigureSheets.previewFor(context, definition),
      );
      if (settings == null || !mounted) return;
      viewModel.addItem(definition, configuration: settings.toConfiguration(), span: settings.span);
      return;
    }
    if (definition is! ShortcutDefinition || !definition.requiresWalletContext) {
      viewModel.addItem(definition);
      return;
    }
    final walletContext = await HomeItemConfigureSheets.openShortcut(context, viewModel, definition);
    if (walletContext == null || !mounted) return;
    viewModel.addItem(definition, walletContext: walletContext);
  }

  Future<void> _configure(HomeItemDefinition definition) async {
    final item = _viewModel.itemOf(definition);
    if (item != null) await HomeItemConfigureSheets.configure(context, _viewModel, definition, item);
  }

  /// 위젯 목록의 미리보기 크기. 여러 크기를 고를 수 있으면 가장 큰 크기로 보여 준다.
  HomeSpan _previewSpan(HomeItemDefinition definition) =>
      definition.supportedSpans.contains(HomeSpan.wide) ? HomeSpan.wide : definition.supportedSpans.first;

  void _onItemTap(HomeViewModel viewModel, HomeItemDefinition definition) =>
      viewModel.isOnHome(definition) ? _configure(definition) : _add(definition);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<HomeViewModel>();
    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(context: context, backgroundColor: colors.homeBackground, title: t.home_edit.title),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CoconutSegmentedControl(
                selectedColor: colors.segmentedControlSelected,
                segmentedControlContainerColor: colors.homeSurface,
                selectedTextColor: colors.segmentedControlSelectedText,
                unselectedTextColor: colors.segmentedControlUnselectedText,
                isSelected: [for (final tab in HomeEditTab.values) tab == _tab],
                onPressed: (index) => setState(() => _tab = HomeEditTab.values[index]),
                children: [Text(t.home_edit.presets), Text(t.home_edit.widgets), Text(t.home_edit.shortcuts)],
              ),
            ),
            if (_tab == HomeEditTab.widgets)
              Align(alignment: Alignment.centerLeft, child: _buildCategoryChips(viewModel)),
            Expanded(
              child: Stack(
                children: [
                  KeyedSubtree(
                    key: ValueKey('home-edit-tab-${_tab.name}'),
                    child: switch (_tab) {
                      HomeEditTab.presets => _buildPresetsTab(context, viewModel),
                      HomeEditTab.widgets => _buildWidgetsTab(context, viewModel),
                      HomeEditTab.shortcuts => _buildShortcutsTab(context, viewModel),
                    },
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _topFadeHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: const Key('home-edit-top-fade'),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [colors.homeBackground, colors.homeBackground.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(HomeViewModel viewModel, HomeItemDefinition definition, {double iconSize = 28}) {
    final colors = context.coconutColors;
    final onHome = viewModel.isOnHome(definition);
    final button = CupertinoButton(
      key: ValueKey('home-edit-${onHome ? 'remove' : 'add'}-${definition.id}'),
      padding: EdgeInsets.zero,
      minimumSize: Size.square(iconSize + 4),
      onPressed: () => onHome ? viewModel.removeDefinition(definition) : _add(definition),
      child: Icon(
        onHome ? CupertinoIcons.minus_circle_fill : CupertinoIcons.add_circled_solid,
        color: colors.mutedText,
        size: iconSize,
      ),
    );
    if (!onHome) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        Text(
          t.home_edit.added,
          key: ValueKey('home-edit-added-${definition.id}'),
          textScaler: TextScaler.noScaling,
          style: CoconutTypography.caption_10.copyWith(color: colors.primary),
        ),
        const SizedBox(width: 2),
        button,
      ],
    );
  }

  /// 미리보기에서 적용하면 프리셋을 적용하고, 되돌릴 수 있게 적용 전 구성을 들고 Edit Home을 닫는다.
  Future<void> _openPresetPreview(HomeViewModel viewModel, HomePreset preset) async {
    final apply = await HomePresetPreviewScreen.open(context, preset);
    if (!apply || !mounted) return;
    final previous = viewModel.applyPreset(preset);
    Navigator.of(context).pop(HomePresetApplied(preset: preset, previous: previous));
  }

  Widget _buildPresetsTab(BuildContext context, HomeViewModel viewModel) {
    final colors = context.coconutColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, _contentTop, 16, 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
          child: Text(
            t.home_presets.header,
            key: const Key('home-presets-header'),
            style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText),
          ),
        ),
        for (final (index, preset) in viewModel.presets.indexed) ...[
          if (index > 0) CoconutLayout.spacing_300h,
          HomeWidgetPressable(
            key: ValueKey('home-preset-card-${preset.id}'),
            onTap: () => _openPresetPreview(viewModel, preset),
            child: Container(
              key: ValueKey('home-preset-${preset.id}'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.name(), style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText)),
                  CoconutLayout.spacing_100h,
                  Text(preset.description(), style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText)),
                  CoconutLayout.spacing_300h,
                  Align(
                    alignment: Alignment.centerRight,
                    child: CupertinoButton(
                      key: ValueKey('home-preset-preview-${preset.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      minimumSize: Size.zero,
                      color: colors.homeBackground,
                      borderRadius: BorderRadius.circular(10),
                      onPressed: () => _openPresetPreview(viewModel, preset),
                      child: Text(
                        t.home_presets.preview,
                        style: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _categoryLabel(HomeItemCategory category) => switch (category) {
    HomeItemCategory.balance => t.home_edit.categories.balance,
    HomeItemCategory.wallets => t.home_edit.categories.wallets,
    HomeItemCategory.activities => t.home_edit.categories.activities,
    HomeItemCategory.hodl => t.home_edit.categories.hodl,
    HomeItemCategory.safety => t.home_edit.categories.safety,
    HomeItemCategory.shortcut => t.home_edit.shortcuts,
  };

  Widget _buildCategoryChips(HomeViewModel viewModel) {
    final categories = [for (final (category, _) in viewModel.widgetSections) category];
    return SingleChildScrollView(
      key: const Key('home-edit-category-chips'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (final category in <HomeItemCategory?>[null, ...categories])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                key: ValueKey('home-edit-chip-${category?.name ?? 'all'}'),
                label: category == null ? t.all : _categoryLabel(category),
                selected: _widgetCategory == category,
                onTap: () => setState(() => _widgetCategory = category),
              ),
            ),
        ],
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
        return ListView(
          key: ValueKey('home-edit-widget-list-${_widgetCategory?.name ?? 'all'}'),
          padding: const EdgeInsets.fromLTRB(16, _contentTop, 16, 48),
          children: [
            for (final (category, definitions) in viewModel.widgetSections)
              if (_widgetCategory == null || _widgetCategory == category) ...[
                Padding(
                  key: ValueKey('home-edit-category-${category.name}'),
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(
                    _categoryLabel(category),
                    style: CoconutTypography.heading4_18_Bold.copyWith(color: colors.primaryText),
                  ),
                ),
                Wrap(
                  spacing: gap,
                  runSpacing: 24,
                  children: [
                    for (final definition in definitions)
                      SizedBox(
                        key: ValueKey('home-edit-widget-${definition.id}'),
                        width: _previewSpan(definition) == HomeSpan.wide ? contentWidth : smallWidth,
                        child: GestureDetector(
                          key: ValueKey('home-edit-widget-tap-${definition.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _onItemTap(viewModel, definition),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: smallWidth,
                                child: DecoratedBox(
                                  key: ValueKey('home-edit-widget-shadow-${definition.id}'),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.homeWidgetShadow,
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: IgnorePointer(
                                    child: definition.build(
                                      context,
                                      HomeItem(
                                        id: 'preview-${definition.id}',
                                        definitionId: definition.id,
                                        kind: definition.kind,
                                        order: 0,
                                        span: _previewSpan(definition),
                                        configuration: viewModel.itemOf(definition)?.configuration ?? const {},
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              CoconutLayout.spacing_100h,
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          definition.displayName(),
                                          key: ValueKey('home-edit-widget-name-${definition.id}'),
                                          maxLines: 1,
                                          style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                                        ),
                                      ),
                                    ),
                                    _buildToggleButton(viewModel, definition, iconSize: 22),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                CoconutLayout.spacing_600h,
              ],
          ],
        );
      },
    );
  }

  Widget _buildShortcutRow(BuildContext context, HomeViewModel viewModel, ShortcutDefinition definition) {
    final colors = context.coconutColors;
    final iconPath = definition.feature.iconPath;
    return GestureDetector(
      key: ValueKey('home-edit-shortcut-${definition.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _onItemTap(viewModel, definition),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(10)),
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
                style: CoconutTypography.body3_12.copyWith(color: colors.primaryText),
              ),
            ),
            _buildToggleButton(viewModel, definition, iconSize: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutsTab(BuildContext context, HomeViewModel viewModel) {
    final colors = context.coconutColors;
    final onHome = viewModel.shortcutsOnHome;
    final available = viewModel.addableShortcutDefinitions;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text, style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText)),
    );
    Widget divider(String afterId) =>
        Container(key: ValueKey('home-edit-shortcut-divider-$afterId'), height: 1, color: colors.divider);
    List<Widget> rows(List<ShortcutDefinition> definitions) => [
      for (final (index, definition) in definitions.indexed) ...[
        if (index > 0) divider(definitions[index - 1].id),
        _buildShortcutRow(context, viewModel, definition),
      ],
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, _contentTop, 16, 96),
      children: [
        header(t.home_edit.shortcuts_on_home),
        ...rows(onHome),
        CoconutLayout.spacing_400h,
        header(t.home_edit.available_shortcuts),
        ...rows(available),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return HomeWidgetPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.chipSelectedBackground : colors.chipUnselectedBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: (selected ? CoconutTypography.body3_12_Bold : CoconutTypography.body3_12).copyWith(
            color: selected ? colors.chipSelectedText : colors.chipUnselectedText,
          ),
        ),
      ),
    );
  }
}
