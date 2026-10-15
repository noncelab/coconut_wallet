import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/providers/view_model/home/all_features_view_model.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 홈을 가로로 넘기면 나오는 모든 기능 화면. 맨 위 검색, 아래는 분류별 목록이나 검색 결과.
class AllFeaturesScreen extends StatefulWidget {
  final FeatureRegistry registry;
  final bool Function(FeatureItem feature)? isAvailable;

  /// 지갑이 필요해 흐리게 표시할 기능. 누르면 [onLaunch]가 기존 안내를 제공한다.
  final bool Function(FeatureItem feature)? isDimmed;
  final bool noWallets;
  final Future<void> Function(BuildContext context)? onAddWallet;
  final void Function(BuildContext context, FeatureItem feature) onLaunch;
  final Future<void> Function(BuildContext context)? onFakeBalanceTap;
  final List<String> recentIds;
  final void Function(List<String> ids)? saveRecentIds;

  const AllFeaturesScreen({
    super.key,
    required this.registry,
    required this.onLaunch,
    this.onFakeBalanceTap,
    this.isAvailable,
    this.isDimmed,
    this.noWallets = false,
    this.onAddWallet,
    this.recentIds = const [],
    this.saveRecentIds,
  });

  @override
  State<AllFeaturesScreen> createState() => _AllFeaturesScreenState();
}

class _AllFeaturesScreenState extends State<AllFeaturesScreen> with AutomaticKeepAliveClientMixin<AllFeaturesScreen> {
  static const _searchVerticalPadding = 14.0;
  static const _fakeBalanceIconPath = 'assets/svg/features/widgets/fake-balance-mask.svg';

  /// 검색 창 아래 그라데이션 높이. 처음 화면에서 내용이 흐려지지 않도록 목록은 [_contentTop]부터 시작한다.
  static const _topFadeHeight = 16.0;
  static const _contentTop = 20.0;

  late final FeatureItem _fakeBalanceFeature = FeatureItem(
    id: AllFeaturesViewModel.fakeBalanceRecentId,
    label: () => t.wallet_home_screen.edit.fake_balance.fake_balance_setting,
    iconPath: _fakeBalanceIconPath,
    category: FeatureCategory.settings,
    keywords: const ['decoy balance', '가짜', '페이크'],
    localizedKeywords: () => t.all_features.fake_balance_search_terms.split(','),
  );

  late final AllFeaturesViewModel _viewModel = AllFeaturesViewModel(
    registry: widget.registry,
    isAvailable: widget.isAvailable,
    recentIds: widget.recentIds,
    saveRecentIds: widget.saveRecentIds,
    extraFeature: widget.onFakeBalanceTap == null ? null : _fakeBalanceFeature,
  );
  final TextEditingController _controller = TextEditingController();
  bool _addingWallet = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  String _categoryLabel(FeatureCategory? category) => switch (category) {
    FeatureCategory.wallet => t.all_features.categories.wallet,
    FeatureCategory.transactions => t.all_features.categories.transactions,
    FeatureCategory.utxo => t.all_features.categories.utxo,
    FeatureCategory.tools => t.all_features.categories.tools,
    FeatureCategory.safety => t.all_features.categories.safety,
    FeatureCategory.settings => t.all_features.categories.settings,
    null => t.all_features.categories.added,
  };

  void _launch(BuildContext context, FeatureItem feature) {
    FocusScope.of(context).unfocus();
    _viewModel.recordLaunch(feature);
    if (feature.id == AllFeaturesViewModel.fakeBalanceRecentId) {
      widget.onFakeBalanceTap?.call(context);
    } else {
      widget.onLaunch(context, feature);
    }
  }

  Future<void> _addWallet() async {
    final onAddWallet = widget.onAddWallet;
    if (_addingWallet || onAddWallet == null) return;
    _addingWallet = true;
    FocusScope.of(context).unfocus();
    try {
      await onAddWallet(context);
    } finally {
      _addingWallet = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.coconutColors;
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ColoredBox(
          color: colors.homeBackground,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _buildSearchField(context)),
                Expanded(
                  child: Stack(
                    children: [
                      Consumer<AllFeaturesViewModel>(
                        builder:
                            (context, viewModel, _) =>
                                viewModel.isSearching ? _buildResults(viewModel) : _buildSections(viewModel),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: _topFadeHeight,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            key: const Key('all-features-top-fade'),
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
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final colors = context.coconutColors;
    return CupertinoTextField(
      key: const Key('all-features-search'),
      controller: _controller,
      onChanged: _viewModel.search,
      placeholder: t.all_features.search_placeholder,
      placeholderStyle: CoconutTypography.body1_16.copyWith(color: colors.tertiaryText),
      style: CoconutTypography.body1_16.copyWith(color: colors.primaryText),
      cursorColor: colors.primaryText,
      textInputAction: TextInputAction.search,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: _searchVerticalPadding),
      suffix: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder:
            (context, value, _) =>
                value.text.isEmpty
                    ? const SizedBox.shrink()
                    : GestureDetector(
                      key: const Key('all-features-search-clear'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _controller.clear();
                        _viewModel.search('');
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: _searchVerticalPadding),
                        child: Icon(CupertinoIcons.clear_thick_circled, size: 20, color: colors.tertiaryText),
                      ),
                    ),
      ),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Icon(CupertinoIcons.search, size: 22, color: colors.secondaryText),
      ),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildSections(AllFeaturesViewModel viewModel) {
    final colors = context.coconutColors;
    return ListView(
      key: const Key('all-features-body'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, _contentTop, 16, 32),
      children: [
        if (viewModel.recent case final recent when recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(t.all_features.recent, style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText)),
          ),
          Row(
            key: const Key('all-features-recent'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < AllFeaturesViewModel.recentLimit; i++)
                Expanded(child: i < recent.length ? _buildRecentTile(recent[i]) : const SizedBox.shrink()),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Container(key: const Key('all-features-recent-divider'), height: 1, color: colors.divider),
          ),
        ],
        if (widget.noWallets) _walletBanner(),
        for (final (index, (category, entries)) in viewModel.sections.indexed) ...[
          Padding(
            key: ValueKey('all-features-category-${category?.name ?? 'added'}'),
            padding: EdgeInsets.fromLTRB(4, index == 0 ? 0 : 16, 4, 4),
            child: Text(
              _categoryLabel(category),
              style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
            ),
          ),
          for (final entry in entries) _buildRow(entry),
        ],
      ],
    );
  }

  Widget _buildResults(AllFeaturesViewModel viewModel) {
    final colors = context.coconutColors;
    final results = viewModel.results;
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            t.all_features.no_results,
            key: const Key('all-features-no-results'),
            style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText),
          ),
        ),
      );
    }
    return ListView(
      key: const Key('all-features-results'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, _contentTop, 16, 32),
      children: [if (widget.noWallets) _walletBanner(), for (final entry in results) _buildRow(entry)],
    );
  }

  bool _requiresWallet(FeatureItem feature) => widget.isDimmed?.call(feature) ?? false;

  Widget _walletBanner() {
    final colors = context.coconutColors;
    final message = t.all_features.wallet_required_description;
    final label = t.home_widgets.add_wallet;
    final messageStyle = CoconutTypography.body2_14.copyWith(color: colors.primaryText);
    final buttonStyle = CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        key: const Key('all-features-wallet-banner'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(12)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double textWidth(String text, TextStyle style) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final width = painter.width;
              painter.dispose();
              return width;
            }

            final buttonWidth = (textWidth(label, buttonStyle) + 32).clamp(48.0, double.infinity);
            final messageWidth = constraints.maxWidth - 20 - 12 - 12 - buttonWidth;
            var inline = false;
            if (messageWidth > 0) {
              final painter = TextPainter(
                text: TextSpan(text: message, style: messageStyle),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 2,
              )..layout(maxWidth: messageWidth);
              inline = !painter.didExceedMaxLines;
              painter.dispose();
            }
            final icon = Icon(CupertinoIcons.info_circle, size: 20, color: colors.secondaryText);
            final text = Text(message, style: messageStyle);
            final button = ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: CupertinoButton(
                key: const Key('all-features-add-wallet'),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                borderRadius: BorderRadius.circular(24),
                color: colors.divider,
                onPressed: widget.onAddWallet == null ? null : _addWallet,
                child: Text(label, textAlign: TextAlign.center, style: buttonStyle),
              ),
            );
            return inline
                ? Row(
                  children: [icon, const SizedBox(width: 12), Expanded(child: text), const SizedBox(width: 12), button],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [icon, const SizedBox(width: 12), Expanded(child: text)]),
                    const SizedBox(height: 8),
                    Align(alignment: AlignmentDirectional.centerEnd, child: button),
                  ],
                );
          },
        ),
      ),
    );
  }

  Widget _buildRecentTile(FeatureItem feature) => _recentTile(feature);

  Widget _recentTile(FeatureItem feature) {
    final colors = context.coconutColors;
    final foreground = _requiresWallet(feature) ? colors.secondaryText : colors.primaryText;
    final iconPath = feature.iconPath;
    return GestureDetector(
      key: ValueKey('all-features-recent-${feature.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _launch(context, feature),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(14)),
            child:
                iconPath == null
                    ? null
                    : SvgPicture.asset(
                      iconPath,
                      width: 24 * feature.iconScale,
                      height: 24 * feature.iconScale,
                      colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
                    ),
          ),
          const SizedBox(height: 6),
          Text(
            feature.shortcutLabel(),
            textAlign: TextAlign.center,
            style: CoconutTypography.body3_12.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(AllFeaturesEntry entry) => _row(entry);

  Widget _row(AllFeaturesEntry entry) {
    final colors = context.coconutColors;
    final foreground = _requiresWallet(entry.launchItem) ? colors.secondaryText : colors.primaryText;
    final feature = entry.item;
    final iconPath = feature.iconPath;
    return GestureDetector(
      key:
          _viewModel.isSearching && feature.id == AllFeaturesViewModel.fakeBalanceRecentId
              ? const Key('all-features-fake-balance-result')
              : ValueKey('all-features-item-${feature.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _launch(context, entry.launchItem),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                        width: 20 * feature.iconScale,
                        height: 20 * feature.iconScale,
                        colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
                      ),
            ),
            CoconutLayout.spacing_300w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feature.label(), style: CoconutTypography.body1_16.copyWith(color: foreground)),
                  if (entry.path.isNotEmpty)
                    Text(
                      entry.path.join(' › '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CoconutTypography.caption_10.copyWith(color: colors.secondaryText),
                    ),
                  if (feature.id == AllFeaturesViewModel.fakeBalanceRecentId)
                    Text(
                      t.all_features.fake_balance_applies_to_home,
                      style: CoconutTypography.caption_10.copyWith(color: colors.secondaryText),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
