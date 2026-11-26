import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutToast;
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_theme_removal.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_navigation_target.dart';
import 'package:coconut_wallet/ccos/ccos_feature_status.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ccos_store_view_model.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_action_button.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_creator_story.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_feature_icon.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_screenshot_strip.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart' show CoconutToast;
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_scope.dart';
import 'package:flutter/services.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
import 'package:coconut_wallet/widgets/common/effects/liquid_glass_surface.dart';
import 'package:coconut_wallet/widgets/features/ccos/coconut_open_store_backdrop.dart';

class CoconutOpenStoreFeatureDetailScreen extends StatelessWidget {
  const CoconutOpenStoreFeatureDetailScreen({super.key, required this.featureId});

  final String featureId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (context) =>
              CcosStoreViewModel(context.read<PreferenceProvider>(), context.read<CcosFeatureStatusRegistry>()),
      child: CcosStoreScope(child: _CoconutOpenStoreFeatureDetailView(featureId: featureId)),
    );
  }
}

class _CoconutOpenStoreFeatureDetailView extends StatefulWidget {
  const _CoconutOpenStoreFeatureDetailView({required this.featureId});

  final String featureId;

  @override
  State<_CoconutOpenStoreFeatureDetailView> createState() => _CoconutOpenStoreFeatureDetailViewState();
}

class _CoconutOpenStoreFeatureDetailViewState extends State<_CoconutOpenStoreFeatureDetailView> {
  static const double _iconSize = 120;
  static const double _barHeight = 60;

  final ScrollController _scrollController = ScrollController();
  bool _isHeaderHidden = false;
  bool _isScrolled = false;

  String get featureId => widget.featureId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (CcosFeatureRegistrySource.findListingById(featureId) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final hidden = offset > _iconSize;
    final scrolled = offset > 0;
    if (hidden != _isHeaderHidden || scrolled != _isScrolled) {
      setState(() {
        _isHeaderHidden = hidden;
        _isScrolled = scrolled;
      });
    }
  }

  Future<void> _add(BuildContext context, CcosStoreViewModel viewModel) async {
    final toast = await viewModel.add(featureId);
    if (!context.mounted) return;
    CoconutToast.showToast(context: context, text: toast, isVisibleIcon: true);
  }

  Future<void> _remove(BuildContext context, CcosStoreViewModel viewModel) async {
    if (viewModel.needsRemoveConfirm(featureId) && !await confirmCoconutThemeRemoval(context)) return;
    final removal = await viewModel.remove(featureId);
    if (!removal.removed || !context.mounted) return;
    CoconutToast.showToast(context: context, text: removal.toast!, isVisibleIcon: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<CcosStoreViewModel>();
    final listing = viewModel.listingOf(featureId);
    if (listing == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CoconutAppBar.build(context: context, title: '', isBottom: true, isBackButton: true),
      );
    }
    final state = viewModel.stateOf(featureId);
    final topInset = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: buildSystemBarStyle(backgroundColor: colors.background, brightness: Brightness.light),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(top: topInset + _barHeight + 8, bottom: 40),
              children: [
                _inset(_buildHeader(context, viewModel, listing, state)),
                if (viewModel.unavailableNoticeOf(featureId) case final notice?) ...[
                  CoconutLayout.spacing_400h,
                  _inset(
                    Text(
                      notice,
                      key: const ValueKey('ccos-detail-unavailable-notice'),
                      style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                    ),
                  ),
                ],
                _inset(_divider(context)),
                _inset(_sectionLabel(context, t.ccos.store.feature_section)),
                if (listing.screenshots.isNotEmpty) ...[
                  CcosStoreScreenshotStrip(screenshots: listing.screenshots),
                  CoconutLayout.spacing_400h,
                ],
                _inset(
                  Text(listing.description, style: CoconutTypography.body2_14.setColor(colors.secondaryTextStrong)),
                ),
                _inset(_divider(context)),
                _inset(_sectionLabel(context, t.ccos.store.creator_section)),
                _inset(CcosStoreCreatorStory(story: listing.creatorStory)),
                if (state == CcosStoreItemState.added || state == CcosStoreItemState.applied) ...[
                  _inset(_divider(context)),
                  _inset(_buildRemove(context, viewModel)),
                ],
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + _barHeight + 16,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  key: const ValueKey('ccos-detail-top-fade'),
                  opacity: _isScrolled ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.6, 1],
                        colors: [
                          CoconutOpenStoreBackdrop.topColor,
                          CoconutOpenStoreBackdrop.topColor.withValues(alpha: 0.85),
                          CoconutOpenStoreBackdrop.topColor.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar(context, viewModel, listing, state, topInset)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    CcosStoreViewModel viewModel,
    CcosFeatureListing listing,
    CcosStoreItemState state,
    double topInset,
  ) {
    final colors = context.coconutColors;
    final collapsedOpacity = _isHeaderHidden ? 1.0 : 0.0;
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: _barHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 8,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    key: const ValueKey('ccos-detail-back-glass'),
                    opacity: _isScrolled ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const LiquidGlassSurface(
                      cornerRadius: 18,
                      blurSigma: 12,
                      tintColor: Color(0x99FFFFFF),
                      child: SizedBox.square(dimension: 36),
                    ),
                  ),
                  FeatureAwareBackButton(onPressed: () => Navigator.pop(context), color: colors.primaryText),
                ],
              ),
            ),
            AnimatedOpacity(
              key: const ValueKey('ccos-detail-appbar-content'),
              opacity: collapsedOpacity,
              duration: const Duration(milliseconds: 200),
              child: CcosStoreFeatureIcon(iconPath: listing.iconPath, size: 32),
            ),
            Positioned(
              right: 16,
              child: AnimatedOpacity(
                opacity: collapsedOpacity,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_isHeaderHidden,
                  child: KeyedSubtree(
                    key: const ValueKey('ccos-detail-appbar-action'),
                    child: _buildActions(context, viewModel, listing, state),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    CcosStoreViewModel viewModel,
    CcosFeatureListing listing,
    CcosStoreItemState state,
  ) {
    final colors = context.coconutColors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: CcosStoreFeatureIcon(
              key: const ValueKey('ccos-detail-icon'),
              iconPath: listing.iconPath,
              size: _iconSize,
            ),
          ),
          CoconutLayout.spacing_400w,
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _iconSize),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText),
                      ),
                      CoconutLayout.spacing_100h,
                      Text(
                        listing.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                      ),
                    ],
                  ),
                  Text(
                    listing.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                  ),
                  CoconutLayout.spacing_100h,
                  _buildActions(context, viewModel, listing, state, actionKey: const ValueKey('ccos-detail-action')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    CcosStoreViewModel viewModel,
    CcosFeatureListing listing,
    CcosStoreItemState state, {
    Key? actionKey,
  }) {
    final colors = context.coconutColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CcosStoreActionButton(key: actionKey, state: state, onAdd: () => _add(context, viewModel)),
        if ((state == CcosStoreItemState.added || state == CcosStoreItemState.applied) &&
            listing.isSelectableTheme) ...[
          CoconutLayout.spacing_200w,
          ShrinkAnimationButton(
            key: actionKey == null ? null : const ValueKey('ccos-detail-open'),
            onPressed:
                () => AppSettingsScreen.open(context, AppSettingsTarget.theme, highlightTheme: listing.linkedVariant),
            defaultColor: colors.surfaceButton,
            pressedOverlayColor: colors.surfacePressOverlay,
            borderRadius: 16,
            borderWidth: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(t.ccos.store.open, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRemove(BuildContext context, CcosStoreViewModel viewModel) {
    final colors = context.coconutColors;
    final blockedReason = viewModel.removeBlockedReasonOf(featureId);
    final blocked = blockedReason != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShrinkAnimationButton(
          key: const ValueKey('ccos-detail-remove'),
          onPressed: () => _remove(context, viewModel),
          isActive: !blocked,
          defaultColor: colors.surfaceButton,
          disabledColor: colors.surfaceButton,
          pressedOverlayColor: colors.surfacePressOverlay,
          borderRadius: 12,
          borderWidth: 0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Text(
              t.ccos.store.remove,
              style: CoconutTypography.body2_14_Bold.setColor(blocked ? colors.tertiaryText : colors.dangerText),
            ),
          ),
        ),
        if (blocked) ...[
          CoconutLayout.spacing_200h,
          Text(
            blockedReason,
            textAlign: TextAlign.center,
            style: CoconutTypography.body3_12.setColor(colors.secondaryText),
          ),
        ],
      ],
    );
  }

  Widget _inset(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

  Widget _sectionLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(label, style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.tertiaryText)),
  );

  Widget _divider(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Divider(height: 1, color: context.coconutColors.divider),
  );
}
