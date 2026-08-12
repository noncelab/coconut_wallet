import 'dart:math' as math;
import 'package:flutter/physics.dart';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_build_scene.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_contribute_screen.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_discover_screen.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_first_pow_scene.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_idea_scene.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_text_effects.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/effects/liquid_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class CoconutOpenStoreIntroScreen extends StatefulWidget {
  const CoconutOpenStoreIntroScreen({super.key});

  @override
  State<CoconutOpenStoreIntroScreen> createState() => _CoconutOpenStoreIntroScreenState();
}

class _CoconutOpenStoreIntroScreenState extends State<CoconutOpenStoreIntroScreen> with TickerProviderStateMixin {
  CcosFeatureListing get _featuredListing => CcosFeatureRegistrySource.featuredListing;
  static const Duration _loadingDuration = Duration(milliseconds: 5700);
  static const Duration _storyEntranceDuration = Duration(milliseconds: 1050);
  static const Duration _defaultSceneDuration = Duration(milliseconds: 2200);
  static const Duration _ideaSceneDuration = Duration(milliseconds: 8800);
  static const Duration _firstPowSceneDuration = Duration(milliseconds: 11000);
  static const Duration _discoverSceneDuration = Duration(milliseconds: 9800);
  static const Duration _contributeSceneDuration = Duration(milliseconds: 9800);
  // Temporary switch for editing the loading state.
  // Set this back to false to restore the normal auto-advance into the story scenes.
  static const bool _freezeLoadingPreview = false;
  static const double _loadingPreviewFrame = 0.72;
  static const double _loadingStoryRevealFrame = 5120 / 5700;

  // Scene durations above were tuned against the Korean source text's reading/typing pace.
  // Other locales run noticeably longer, so each scene's duration is scaled by how many
  // characters the active locale actually types relative to these Korean baselines - otherwise
  // longer translations get typed out in the same fixed time and feel rushed.
  static const int _ideaSceneBaselineChars = 79;
  static const int _firstPowSceneBaselineChars = 72;
  static const int _discoverSceneBaselineChars = 81;
  static const int _contributeSceneBaselineChars = 99;

  static const Color _screenBackground = Color(0xFFCDD4D7);
  static const Color _loadingBackground = Color(0xFFF9F8F6);
  static const Color _loadingTextPrimary = Color(0xFF0B0B11);
  static const Color _textPrimary = Color(0xFF10161C);
  static const Color _accentBlue = Color(0xFF68D5FF);

  final PageController _pageController = PageController();
  late final AnimationController _loadingController = AnimationController(vsync: this, duration: _loadingDuration);
  late final AnimationController _sceneController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final AnimationController _storyEntranceController = AnimationController(
    vsync: this,
    duration: _storyEntranceDuration,
  );
  late final CurvedAnimation _loadingCurve = CurvedAnimation(parent: _loadingController, curve: Curves.easeInOutCubic);
  late final AnimationController _overviewController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  bool _hasCompletedLoading = false;
  bool _hasStartedStoryEntrance = false;
  bool _isLoadingUnderlayVisible = true;
  bool _isSceneOverviewVisible = false;
  int _currentSceneIndex = 0;

  Future<void> _handleAddTheme(BuildContext context) async {
    final provider = context.read<PreferenceProvider>();
    final alreadyEntitled = provider.getCcosFeatureAvailability(_featuredListing.id).isEntitled;
    if (_featuredListing.requiresEntitlement && !alreadyEntitled) {
      await provider.markCcosFeaturePurchased(_featuredListing.id);
    }
    await provider.activateCcosFeature(_featuredListing.id);
    if (!context.mounted) return;
    CoconutToast.showToast(
      context: context,
      text: t.ccos.intro_screen.theme_activated,
      isVisibleIcon: true,
      iconPath: CommonStateIconPath.circleInfo,
    );
  }

  Future<void> _handleRemoveTheme(BuildContext context, PreferenceProvider provider) async {
    final isUsingPulpTheme =
        _featuredListing.linkedVariant == CoconutThemeVariant.coconutPulp &&
        provider.themeVariant == CoconutThemeVariant.coconutPulp;

    if (isUsingPulpTheme) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => CoconutPopup(
                  languageCode: provider.language,
                  title: t.ccos.intro_screen.delete_popup_title,
                  description: t.ccos.intro_screen.delete_popup_description,
                  leftButtonText: t.cancel,
                  rightButtonText: t.delete,
                  onTapLeft: () => Navigator.pop(context, false),
                  onTapRight: () => Navigator.pop(context, true),
                ),
          ) ??
          false;

      if (!confirmed) return;
      await provider.changeThemeVariant(CoconutThemeVariant.dark);
    }

    await provider.deactivateCcosFeature(_featuredListing.id);
    if (!context.mounted) return;
    CoconutToast.showToast(
      context: context,
      text: t.ccos.intro_screen.theme_removed,
      isVisibleIcon: true,
      iconPath: CommonStateIconPath.circleInfo,
    );
  }

  void _openSceneOverview() {
    setState(() {
      _isSceneOverviewVisible = true;
    });
    _overviewController.forward(from: 0);
  }

  void _closeSceneOverview() {
    setState(() {
      _isSceneOverviewVisible = false;
    });
  }

  Future<void> _animateToScene(int index) async {
    _closeSceneOverview();
    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  List<_OpenStoreSceneDefinition> _buildSceneDefinitions({
    required BuildContext context,
    required PreferenceProvider provider,
    required bool isAdded,
    required bool isApplied,
  }) {
    return [
      _OpenStoreSceneDefinition(
        index: 0,
        chapter: '01 / 05',
        label: t.ccos.intro_screen.scenes.idea.label,
        sceneStep: '01',
        overviewTitle: t.ccos.intro_screen.scenes.idea.overview_title,
        overviewHighlight: t.ccos.intro_screen.scenes.idea.overview_highlight,
      ),
      _OpenStoreSceneDefinition(
        index: 1,
        chapter: '02 / 05',
        label: t.ccos.intro_screen.scenes.build.label,
        sceneStep: '02',
        overviewTitle: t.ccos.intro_screen.scenes.build.overview_title,
        overviewHighlight: t.ccos.intro_screen.scenes.build.overview_highlight,
      ),
      _OpenStoreSceneDefinition(
        index: 2,
        chapter: '03 / 05',
        label: t.ccos.intro_screen.scenes.first_pow.label,
        sceneStep: '03',
        overviewTitle: t.ccos.intro_screen.scenes.first_pow.overview_title,
        overviewHighlight: t.ccos.intro_screen.scenes.first_pow.overview_highlight,
        buildHero:
            (context, animation) => FirstPowSceneBody(
              animation: animation,
              sceneDurationMs: _sceneDurationFor(2).inMilliseconds,
              listing: _featuredListing,
              isAdded: isAdded,
              isApplied: isApplied,
              isCurrentScene: _currentSceneIndex == 2,
              onAdd: () => _handleAddTheme(context),
              onRemove: () => _handleRemoveTheme(context, provider),
            ),
      ),
      _OpenStoreSceneDefinition(
        index: 3,
        chapter: '04 / 05',
        label: t.ccos.intro_screen.scenes.discover.label,
        sceneStep: '04',
        overviewTitle: t.ccos.intro_screen.scenes.discover.overview_title,
        overviewHighlight: t.ccos.intro_screen.scenes.discover.overview_highlight,
      ),
      _OpenStoreSceneDefinition(
        index: 4,
        chapter: '05 / 05',
        label: t.ccos.intro_screen.scenes.contribute.label,
        sceneStep: '05',
        overviewTitle: t.ccos.intro_screen.scenes.contribute.overview_title,
        overviewHighlight: t.ccos.intro_screen.scenes.contribute.overview_highlight,
      ),
    ];
  }

  Duration _scaledSceneDuration(Duration base, int baselineChars, List<String> typedText) {
    final currentChars = typedText.fold<int>(0, (sum, text) => sum + text.length);
    if (baselineChars <= 0 || currentChars <= 0) return base;
    return Duration(milliseconds: (base.inMilliseconds * currentChars / baselineChars).round());
  }

  Duration _typingSceneDuration(
    Duration base,
    int baselineChars,
    List<String> lines,
    List<int> starts, {
    int endPauseMs = 450,
  }) {
    final scaledDuration = _scaledSceneDuration(base, baselineChars, lines);
    final typingEndMs = List.generate(
      lines.length,
      (index) => index,
    ).fold<int>(0, (latest, item) => math.max(latest, starts[item] + typewriterDurationMs(lines[item])));
    return Duration(milliseconds: math.max(scaledDuration.inMilliseconds, typingEndMs + endPauseMs));
  }

  Duration _sceneDurationFor(int index) {
    switch (index) {
      case 0:
        final lines = [
          t.ccos.idea_scene.line1,
          t.ccos.idea_scene.line2,
          t.ccos.idea_scene.line3,
          t.ccos.idea_scene.line4,
        ];
        return _typingSceneDuration(
          _ideaSceneDuration,
          _ideaSceneBaselineChars,
          lines,
          IdeaSceneBody.typingStartMs(lines),
        );
      case 1:
        return BuildSceneBody.sceneDuration();
      case 2:
        final lines = [t.ccos.first_pow_scene.intro_line1, t.ccos.first_pow_scene.intro_line2];
        return _typingSceneDuration(
          _firstPowSceneDuration,
          _firstPowSceneBaselineChars,
          lines,
          FirstPowSceneBody.typingStartMs(lines),
          endPauseMs: FirstPowSceneBody.buttonPauseMs + FirstPowSceneBody.buttonEntranceMs,
        );
      case 3:
        final lines = [t.ccos.discover_scene.line1, t.ccos.discover_scene.line2, t.ccos.discover_scene.line3];
        return _typingSceneDuration(
          _discoverSceneDuration,
          _discoverSceneBaselineChars,
          lines,
          DiscoverSceneBody.typingStartMs(lines),
        );
      case 4:
        final lines = [
          t.ccos.contribute_scene.line1,
          t.ccos.contribute_scene.line2,
          t.ccos.contribute_scene.line3,
          t.ccos.contribute_scene.line4,
        ];
        return _typingSceneDuration(
          _contributeSceneDuration,
          _contributeSceneBaselineChars,
          lines,
          ContributeSceneBody.typingStartMs(lines),
          endPauseMs: 1050,
        );
      default:
        return _defaultSceneDuration;
    }
  }

  int _navigationRevealStartMsFor(int index) {
    switch (index) {
      case 0:
        final lines = [
          t.ccos.idea_scene.line1,
          t.ccos.idea_scene.line2,
          t.ccos.idea_scene.line3,
          t.ccos.idea_scene.line4,
        ];
        return IdeaSceneBody.navigationRevealStartMs(lines);
      case 1:
        return BuildSceneBody.navigationRevealStartMs();
      case 2:
        final lines = [t.ccos.first_pow_scene.intro_line1, t.ccos.first_pow_scene.intro_line2];
        return FirstPowSceneBody.navigationRevealStartMs(lines);
      case 3:
        final lines = [t.ccos.discover_scene.line1, t.ccos.discover_scene.line2, t.ccos.discover_scene.line3];
        return DiscoverSceneBody.navigationRevealStartMs(lines);
      case 4:
        final lines = [
          t.ccos.contribute_scene.line1,
          t.ccos.contribute_scene.line2,
          t.ccos.contribute_scene.line3,
          t.ccos.contribute_scene.line4,
        ];
        return ContributeSceneBody.navigationRevealStartMs(lines);
      default:
        return (_defaultSceneDuration.inMilliseconds * 0.72).round();
    }
  }

  @override
  void initState() {
    super.initState();
    _storyEntranceController.addStatusListener(_handleStoryEntranceStatus);
    _loadingController.addListener(_handleLoadingProgress);
    _loadingController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _startStoryEntrance();
      }
    });
    if (_freezeLoadingPreview) {
      _loadingController.value = _loadingPreviewFrame;
      return;
    }
    _loadingController.forward();
  }

  void _handleLoadingProgress() {
    if (_loadingController.value >= _loadingStoryRevealFrame) {
      _startStoryEntrance();
    }
  }

  void _startStoryEntrance() {
    if (!mounted || _hasStartedStoryEntrance) {
      return;
    }
    _hasStartedStoryEntrance = true;
    setState(() {
      _hasCompletedLoading = true;
    });
    _storyEntranceController.forward(from: 0);
  }

  void _handleStoryEntranceStatus(AnimationStatus status) {
    if (!mounted || status != AnimationStatus.completed) {
      return;
    }

    setState(() {
      _isLoadingUnderlayVisible = false;
    });
    _sceneController.duration = _sceneDurationFor(_currentSceneIndex);
    _sceneController.forward(from: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _loadingController.removeListener(_handleLoadingProgress);
    _loadingController.dispose();
    _sceneController.dispose();
    _storyEntranceController.removeStatusListener(_handleStoryEntranceStatus);
    _storyEntranceController.dispose();
    _overviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PreferenceProvider>(
      builder: (context, provider, child) {
        final availability = provider.getCcosFeatureAvailability(_featuredListing.id);
        final isAdded = availability.isActivated;
        final isApplied =
            isAdded &&
            _featuredListing.linkedVariant != null &&
            provider.themeVariant == _featuredListing.linkedVariant;
        final sceneItems = _buildSceneDefinitions(
          context: context,
          provider: provider,
          isAdded: isAdded,
          isApplied: isApplied,
        );

        return Stack(
          children: [
            Scaffold(
              backgroundColor: _hasCompletedLoading ? _screenBackground : _loadingBackground,
              appBar:
                  _hasCompletedLoading
                      ? PreferredSize(
                        preferredSize: const Size.fromHeight(56),
                        child: Visibility(
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          visible: !_isSceneOverviewVisible,
                          child: CoconutAppBar.build(
                            context: context,
                            foregroundColor: _textPrimary,
                            leadingHighlightColor: _accentBlue.withValues(alpha: 0.22),
                            onBackPressed: () => Navigator.of(context).maybePop(),
                            actionButtonList: [
                              CoconutAppBarActionButton(
                                onPressed: _openSceneOverview,
                                highlightColor: _accentBlue.withValues(alpha: 0.22),
                                icon: SvgPicture.asset(
                                  CommonMenuIconPath.hamburger,
                                  width: 24,
                                  height: 24,
                                  colorFilter: const ColorFilter.mode(_textPrimary, BlendMode.srcIn),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : null,
              body: Stack(
                children: [
                  if (_hasCompletedLoading)
                    _StoryPagerEntrance(animation: _storyEntranceController, child: _buildStoryPager(sceneItems)),
                  if (_isLoadingUnderlayVisible || !_hasCompletedLoading)
                    _OpenStoreLoadingSequence(key: const ValueKey('open-store-loading'), animation: _loadingCurve),
                ],
              ),
            ),
            if (_hasCompletedLoading && _isSceneOverviewVisible)
              Positioned.fill(
                child: _SceneOverviewOverlay(
                  items: sceneItems,
                  currentIndex: _currentSceneIndex,
                  entranceAnimation: _overviewController,
                  onClose: _closeSceneOverview,
                  onSelect: _animateToScene,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStoryPager(List<_OpenStoreSceneDefinition> sceneItems) {
    return Stack(
      key: const ValueKey('open-store-story'),
      children: [
        const Positioned.fill(child: _OpenStoreBackdrop()),
        PageView(
          controller: _pageController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            if (_currentSceneIndex != index) {
              setState(() {
                _currentSceneIndex = index;
              });
            }
            _sceneController.duration = _sceneDurationFor(index);
            _sceneController.forward(from: 0);
          },
          children: [
            for (final item in sceneItems)
              _StoryScene(
                sceneIndex: item.index,
                sceneCount: sceneItems.length,
                label: item.label,
                hero: item.buildHero?.call(context, _sceneController),
                sceneAnimation: _sceneController,
                sceneDurationMs: _sceneDurationFor(item.index).inMilliseconds,
                navigationRevealStartMs: _navigationRevealStartMsFor(item.index),
                onPrevious: item.index == 0 ? null : () => _animateToScene(item.index - 1),
                onNext: item.index == sceneItems.length - 1 ? null : () => _animateToScene(item.index + 1),
              ),
          ],
        ),
      ],
    );
  }
}

class _StoryPagerEntrance extends StatelessWidget {
  const _StoryPagerEntrance({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeOutQuart.transform(animation.value.clamp(0.0, 1.0));
        return ClipRect(
          child: Opacity(
            opacity: 0.08 + (0.92 * t),
            child: Transform.translate(
              offset: Offset((1 - t) * MediaQuery.sizeOf(context).width * 0.72, 0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _OpenStoreSceneDefinition {
  const _OpenStoreSceneDefinition({
    required this.index,
    required this.chapter,
    required this.label,
    required this.sceneStep,
    required this.overviewTitle,
    required this.overviewHighlight,
    this.buildHero,
  });

  final int index;
  final String chapter;
  final String label;
  final String sceneStep;
  final String overviewTitle;
  final String overviewHighlight;
  final Widget Function(BuildContext context, Animation<double> animation)? buildHero;
}

class _OpenStoreLoadingSequence extends StatelessWidget {
  const _OpenStoreLoadingSequence({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;
        const totalMs = 5700;
        const iconPhaseEnd = 2300 / totalMs;
        const ringDelayAfterIcon = 300 / totalMs;
        const ringDrawDuration = 2000 / totalMs;
        const ringStart = iconPhaseEnd + ringDelayAfterIcon;
        const ringOpacityDuration = 160 / totalMs;
        const polishStart = ringStart + ringDrawDuration;
        const beatStart = 4720 / totalMs;
        const beatDuration = 620 / totalMs;
        const fadeStart = 5350 / totalMs;
        const fadeDuration = 350 / totalMs;

        final iconMotion = (value / iconPhaseEnd).clamp(0.0, 1.0);
        final iconScale = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 15.6, end: 1.0).chain(CurveTween(curve: Curves.easeInCubic)),
            weight: 72,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 0.92).chain(CurveTween(curve: Curves.easeIn)),
            weight: 10,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.92, end: 1.05).chain(CurveTween(curve: Curves.easeOut)),
            weight: 10,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: 8,
          ),
        ]).transform(iconMotion);
        final titleOpacity = Curves.easeOut.transform(((value - 0.54) / 0.14).clamp(0.0, 1.0));
        final ringOpacity = Curves.easeOut.transform(((value - ringStart) / ringOpacityDuration).clamp(0.0, 1.0));
        final ringProgress = Curves.easeOut.transform(((value - ringStart) / ringDrawDuration).clamp(0.0, 1.0));
        final polishValue = ((value - polishStart) / 0.05).clamp(0.0, 1.0);
        final polishGlowOpacity = Curves.easeOut.transform(polishValue) * 0.22;
        final beatT = ((value - beatStart) / beatDuration).clamp(0.0, 1.0);
        final heartbeatScale = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.12).chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: 34,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.12, end: 0.98).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 28,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.98, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: 38,
          ),
        ]).transform(beatT);
        final loadingOpacity = 1 - Curves.easeOut.transform(((value - fadeStart) / fadeDuration).clamp(0.0, 1.0));
        final startIconSize = MediaQuery.of(context).size.width * 1.2;

        return Opacity(
          opacity: loadingOpacity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _OpenStoreLoadingBackdrop(),
              Align(
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: iconScale * heartbeatScale,
                  child: SizedBox(
                    width: startIconSize,
                    height: startIconSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          child: Opacity(
                            opacity: polishGlowOpacity,
                            child: Container(
                              width: 74,
                              height: 74,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color.fromARGB(37, 31, 31, 47),
                                    Color.fromARGB(18, 50, 50, 83),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.45, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: ringOpacity,
                          child: CustomPaint(
                            size: const Size.square(86.4),
                            painter: _LoadingProgressRingPainter(progress: ringProgress),
                          ),
                        ),
                        SvgPicture.asset(
                          BrandIconPath.coconutPlanet,
                          width: 60,
                          height: 60,
                          colorFilter: const ColorFilter.mode(
                            _CoconutOpenStoreIntroScreenState._loadingTextPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                bottom: 38,
                child: Opacity(
                  opacity: titleOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.ccos.intro_screen.loading_title,
                        style: CoconutTypography.heading1_32_Bold
                            .setColor(_CoconutOpenStoreIntroScreenState._loadingTextPrimary)
                            .copyWith(fontSize: 50, height: 1, letterSpacing: 0.7, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OpenStoreLoadingBackdrop extends StatelessWidget {
  const _OpenStoreLoadingBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(color: _CoconutOpenStoreIntroScreenState._loadingBackground)),
        Align(
          alignment: const Alignment(-0.72, -0.84),
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              gradient: RadialGradient(colors: [Color(0x1A7BE7D8), Colors.transparent], stops: [0.0, 1.0]),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.12, 0.06),
          child: Container(
            width: 240,
            height: 240,
            decoration: const BoxDecoration(
              gradient: RadialGradient(colors: [Color(0x177C6BFF), Colors.transparent], stops: [0.0, 1.0]),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.84, 0.94),
          child: Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              gradient: RadialGradient(colors: [Color(0x19FF85B5), Colors.transparent], stops: [0.0, 1.0]),
            ),
          ),
        ),
      ],
    );
  }
}

class _SceneOverviewOverlay extends StatelessWidget {
  const _SceneOverviewOverlay({
    required this.items,
    required this.currentIndex,
    required this.entranceAnimation,
    required this.onClose,
    required this.onSelect,
  });

  final List<_OpenStoreSceneDefinition> items;
  final int currentIndex;
  final Animation<double> entranceAnimation;
  final VoidCallback onClose;
  final ValueChanged<int> onSelect;

  static const Alignment _originAlignment = Alignment(0.94, -1);

  static const Interval _backgroundStage = Interval(0.0, 0.45);
  static const Interval _contentStage = Interval(0.45, 0.95);
  static const Interval _closeButtonStage = Interval(0.9, 1.0);

  static double _panelScaleFor(double backgroundStageT) {
    const growEnd = 0.6;
    const shrinkEnd = 0.72;
    const overshoot = 1.08;
    if (backgroundStageT <= growEnd) {
      final t = (backgroundStageT / growEnd).clamp(0.0, 1.0);
      return Curves.easeOut.transform(t) * overshoot;
    }
    if (backgroundStageT <= shrinkEnd) {
      final t = ((backgroundStageT - growEnd) / (shrinkEnd - growEnd)).clamp(0.0, 1.0);
      return overshoot + (1.0 - overshoot) * Curves.easeIn.transform(t);
    }
    return 1.0;
  }

  static double _itemRevealProgress(double contentStageT, int index, int itemCount) {
    const revealSpan = 0.5;
    final step = itemCount > 1 ? (1 - revealSpan) / (itemCount - 1) : 0.0;
    final start = index * step;
    final t = ((contentStageT - start) / revealSpan).clamp(0.0, 1.0);
    return Curves.easeOut.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entranceAnimation,
      builder: (context, child) {
        final backgroundStageT = _backgroundStage.transform(entranceAnimation.value);
        final splashProgress = Curves.easeOut.transform((backgroundStageT / 0.4).clamp(0.0, 1.0));
        final splashOpacity = (1 - Curves.easeIn.transform((backgroundStageT / 0.4).clamp(0.0, 1.0))) * 0.5;
        final panelScale = _panelScaleFor(backgroundStageT);
        final panelOpacity = Curves.easeOut.transform((backgroundStageT / 0.4).clamp(0.0, 1.0));

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose, child: const SizedBox.expand()),
            ),
            IgnorePointer(
              child: Align(
                alignment: _originAlignment,
                child: Opacity(
                  opacity: splashOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.2 + (splashProgress * 3.2),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [Color(0x99FFFFFF), Colors.transparent]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: panelOpacity,
              child: Transform.scale(scale: panelScale, alignment: _originAlignment, child: child),
            ),
          ],
        );
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7E8B95).withValues(alpha: 0.2),
                  blurRadius: 32,
                  spreadRadius: 1,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: -2),
              ],
            ),
            child: LiquidGlassSurface(
              cornerRadius: 34,
              blurSigma: 4,
              distortion: 0.16,
              distortionWidth: 42,
              magnification: 1.1,
              tintColor: const Color(0x2AFBFDFF),
              rimOnLeftRight: true,
              rimOnTopBottom: false,
              rimWidth: 2,
              child: Stack(
                children: [
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.bottomLeft,
                            radius: 1.0,
                            colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: AnimatedBuilder(
                      animation: entranceAnimation,
                      builder: (context, child) {
                        final contentStageT = _contentStage.transform(entranceAnimation.value);
                        return ListView.separated(
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.only(top: 48),
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 34),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final itemT = _itemRevealProgress(contentStageT, index, items.length);
                            return Opacity(
                              opacity: itemT,
                              child: Transform.translate(
                                offset: Offset(0, 16 * (1 - itemT)),
                                child: _SceneNavigationRow(
                                  item: item,
                                  isSelected: currentIndex == index,
                                  isReversed: index.isOdd,
                                  onTap: () => onSelect(index),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: AnimatedBuilder(
                      animation: entranceAnimation,
                      builder: (context, child) {
                        final closeButtonOpacity = Curves.easeOut.transform(
                          _closeButtonStage.transform(entranceAnimation.value),
                        );
                        return Opacity(opacity: closeButtonOpacity, child: child);
                      },
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onClose,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: SvgPicture.asset(
                              CommonActionIconPath.close,
                              width: 22,
                              height: 22,
                              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneNavigationRow extends StatefulWidget {
  const _SceneNavigationRow({
    required this.item,
    required this.isSelected,
    required this.isReversed,
    required this.onTap,
  });

  final _OpenStoreSceneDefinition item;
  final bool isSelected;
  final bool isReversed;
  final VoidCallback onTap;

  @override
  State<_SceneNavigationRow> createState() => _SceneNavigationRowState();
}

class _SceneNavigationRowState extends State<_SceneNavigationRow> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  late final AnimationController _squashController = AnimationController(vsync: this, value: 1.0);

  void _handleTapDown([TapDownDetails? _]) {
    _squashController.stop();
    _squashController.animateTo(0.88, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
  }

  void _handleTapRelease([TapUpDetails? _]) {
    _squashController.animateWith(
      SpringSimulation(const SpringDescription(mass: 1, stiffness: 380, damping: 16), _squashController.value, 1.0, 0),
    );
  }

  @override
  void dispose() {
    _squashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copyBlock = _SceneNavigationCopy(item: widget.item, alignEnd: widget.isReversed);
    final jumpButton = _SceneJumpButton(
      label: widget.item.label,
      onTap: widget.onTap,
      isSelected: widget.isSelected || _isPressed,
    );
    final rowWidth = MediaQuery.sizeOf(context).width - 40;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: AnimatedBuilder(
        animation: _squashController,
        builder: (context, child) {
          final squash = _squashController.value;
          final scaleY = squash;
          final scaleX = 1 + ((1 - squash) * 0.6);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(scaleX, scaleY),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapRelease,
            onTapCancel: _handleTapRelease,
            onHighlightChanged: (value) {
              if (_isPressed == value) return;
              setState(() {
                _isPressed = value;
              });
            },
            borderRadius: BorderRadius.circular(28),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Ink(
              width: rowWidth,
              child: Stack(
                children: [
                  Positioned(
                    left: widget.isReversed ? null : 0,
                    right: widget.isReversed ? 0 : null,
                    top: 0,
                    child: _SceneNavigationNumber(step: widget.item.sceneStep, alignEnd: widget.isReversed),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: widget.isReversed ? 0 : 14,
                      right: widget.isReversed ? 14 : 0,
                      top: 52,
                    ),
                    child: SizedBox(
                      width: rowWidth - 14,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: widget.isReversed ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280), child: copyBlock),
                          const SizedBox(height: 6),
                          Padding(
                            padding: EdgeInsets.only(left: widget.isReversed ? 4 : 0, right: widget.isReversed ? 0 : 4),
                            child: Row(
                              mainAxisAlignment: widget.isReversed ? MainAxisAlignment.start : MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.max,
                              children: [jumpButton],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneNavigationCopy extends StatelessWidget {
  const _SceneNavigationCopy({required this.item, required this.alignEnd});

  final _OpenStoreSceneDefinition item;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final highlightIndex = item.overviewTitle.indexOf(item.overviewHighlight);
    final beforeText = highlightIndex > 0 ? item.overviewTitle.substring(0, highlightIndex) : '';
    final afterText = item.overviewTitle.substring(highlightIndex + item.overviewHighlight.length);
    final regularStyle = CoconutTypography.heading4_18.setColor(_CoconutOpenStoreIntroScreenState._textPrimary);

    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        RichText(
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          text: TextSpan(
            children: [
              if (beforeText.isNotEmpty) TextSpan(text: beforeText, style: regularStyle),
              TextSpan(
                text: item.overviewHighlight,
                style: CoconutTypography.heading3_21_Bold.setColor(_CoconutOpenStoreIntroScreenState._textPrimary),
              ),
              if (afterText.isNotEmpty) TextSpan(text: afterText, style: regularStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _SceneNavigationNumber extends StatelessWidget {
  const _SceneNavigationNumber({required this.step, required this.alignEnd});

  final String step;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Text(
        step,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: CoconutTypography.heading1_32_Bold
            .setColor(Colors.white.withValues(alpha: 0.92))
            .copyWith(fontSize: 82, height: 0.92),
      ),
    );
  }
}

class _SceneJumpButton extends StatelessWidget {
  const _SceneJumpButton({required this.label, required this.onTap, required this.isSelected});

  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.04 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _CoconutOpenStoreIntroScreenState._textPrimary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: CoconutTypography.caption_10_Bold.setColor(
                    _CoconutOpenStoreIntroScreenState._screenBackground,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: _CoconutOpenStoreIntroScreenState._screenBackground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingProgressRingPainter extends CustomPainter {
  const _LoadingProgressRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width / 2) - 3;
    final basePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = _CoconutOpenStoreIntroScreenState._loadingTextPrimary.withValues(alpha: 0.06);
    final progressPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.2
          ..color = const Color.fromARGB(255, 43, 43, 76);

    canvas.drawCircle(center, radius, basePaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoadingProgressRingPainter oldDelegate) => oldDelegate.progress != progress;
}

class _StoryScene extends StatelessWidget {
  const _StoryScene({
    required this.sceneIndex,
    required this.sceneCount,
    required this.label,
    this.hero,
    required this.sceneAnimation,
    required this.sceneDurationMs,
    required this.navigationRevealStartMs,
    required this.onPrevious,
    required this.onNext,
  });

  final int sceneIndex;
  final int sceneCount;
  final String label;
  final Widget? hero;
  final Animation<double> sceneAnimation;
  final int sceneDurationMs;
  final int navigationRevealStartMs;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sceneAnimation,
      builder: (context, child) {
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
        final isIdeaScene = sceneIndex == 0;
        final isBuildScene = sceneIndex == 1;
        final isFirstPowScene = sceneIndex == 2;
        final isDiscoverScene = sceneIndex == 3;
        final ideaLabelSlide = Tween<Offset>(
          begin: const Offset(0.18, 0),
          end: Offset.zero,
        ).transform(Curves.easeOut.transform(const Interval(0.08, 0.26).transform(sceneAnimation.value)));

        return LayoutBuilder(
          builder: (context, constraints) {
            return ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _SceneWatermarkBanner(animation: sceneAnimation, availableHeight: constraints.maxHeight),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 4, 24, 22 + bottomInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(sceneIndex + 1).toString().padLeft(2, '0')} / 05',
                                  style: CoconutTypography.caption_10_Bold.setColor(Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Transform.translate(
                                  offset: isIdeaScene ? Offset(ideaLabelSlide.dx * 36, 0) : Offset.zero,
                                  child: Opacity(
                                    opacity:
                                        isIdeaScene
                                            ? Curves.easeOut.transform(
                                              const Interval(0.08, 0.26).transform(sceneAnimation.value),
                                            )
                                            : 1,
                                    child: Text(
                                      label,
                                      style: CoconutTypography.heading4_18_Bold.setColor(
                                        _CoconutOpenStoreIntroScreenState._textPrimary.withAlpha(200),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child:
                                isIdeaScene
                                    ? IdeaSceneBody(animation: sceneAnimation, sceneDurationMs: sceneDurationMs)
                                    : isBuildScene
                                    ? BuildSceneBody(animation: sceneAnimation)
                                    : isFirstPowScene
                                    ? hero ?? const SizedBox.shrink()
                                    : isDiscoverScene
                                    ? DiscoverSceneBody(animation: sceneAnimation, sceneDurationMs: sceneDurationMs)
                                    : ContributeSceneBody(
                                      animation: sceneAnimation,
                                      sceneDurationMs: sceneDurationMs,
                                      onStartPr: () => launchURL(CONTRIBUTING_URL),
                                    ),
                          ),
                          const SizedBox(height: 10),
                          _SceneBottomNavigation(
                            animation: sceneAnimation,
                            sceneDurationMs: sceneDurationMs,
                            revealStartMs: navigationRevealStartMs,
                            currentIndex: sceneIndex,
                            sceneCount: sceneCount,
                            onPrevious: onPrevious,
                            onNext: onNext,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SceneWatermarkBanner extends StatefulWidget {
  const _SceneWatermarkBanner({required this.animation, required this.availableHeight});

  final Animation<double> animation;
  final double availableHeight;

  @override
  State<_SceneWatermarkBanner> createState() => _SceneWatermarkBannerState();
}

class _SceneWatermarkBannerState extends State<_SceneWatermarkBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _driftController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 50000),
  )..repeat();

  @override
  void dispose() {
    _driftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reveal = Curves.easeOutCubic.transform(widget.animation.value.clamp(0.0, 1.0));
    final height = widget.availableHeight * 0.20;
    final bannerText = t.ccos.intro_screen.watermark_banner; // 배너 간격 유지를 위해 스페이스 포함
    final textStyle = CoconutTypography.heading1_32_Bold
        .setColor(Colors.white.withValues(alpha: 0.16))
        .copyWith(fontSize: 140, height: 1, letterSpacing: -2.8, fontWeight: FontWeight.w800);
    final textPainter =
        TextPainter(text: const TextSpan(), textScaler: MediaQuery.textScalerOf(context))
          ..text = TextSpan(text: bannerText, style: textStyle)
          ..textDirection = TextDirection.ltr
          ..maxLines = 1
          ..layout();
    final gap = math.max(12.0, height * 0.08);
    final unitWidth = textPainter.width + gap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        final unitCount = (visibleWidth / unitWidth).ceil() + 2;
        final trackWidth = unitCount * unitWidth;

        Widget buildTrack() {
          return SizedBox(
            width: trackWidth,
            height: height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < unitCount; i++) ...[
                  if (i != 0) SizedBox(width: gap),
                  Text(bannerText, style: textStyle),
                ],
              ],
            ),
          );
        }

        return AnimatedBuilder(
          animation: Listenable.merge([widget.animation, _driftController]),
          builder: (context, child) {
            final drift = Curves.linear.transform(_driftController.value);
            final dx = -trackWidth * drift;

            return Opacity(
              opacity: reveal.clamp(0.0, 1.0),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  width: visibleWidth,
                  height: height,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          width: trackWidth,
                          height: height,
                          child: Transform.translate(offset: Offset(dx, 0), child: buildTrack()),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          width: trackWidth,
                          height: height,
                          child: Transform.translate(offset: Offset(dx + trackWidth, 0), child: buildTrack()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OpenStoreBackdrop extends StatelessWidget {
  const _OpenStoreBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD6DCDF), Color(0xFFCDD4D7), Color(0xFFC6D0D5)],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(-0.95, -1),
          child: Container(
            width: 320,
            height: 320,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x557AA2FF), Color(0x226E8EFF), Colors.transparent],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.9, -0.74),
          child: Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x44B684FF), Color(0x15937FC5), Colors.transparent],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.2, 1.0),
          child: Container(
            width: 420,
            height: 300,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x2274DCE0), Color(0x1167A7D0), Colors.transparent],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SceneBottomNavigation extends StatelessWidget {
  const _SceneBottomNavigation({
    required this.animation,
    required this.sceneDurationMs,
    required this.revealStartMs,
    required this.currentIndex,
    required this.sceneCount,
    required this.onPrevious,
    required this.onNext,
  });

  final Animation<double> animation;
  final int sceneDurationMs;
  final int revealStartMs;
  final int currentIndex;
  final int sceneCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scaleInterval = intervalFromMs(
      revealStartMs,
      revealStartMs + 520,
      sceneDurationMs,
      curve: Curves.easeOutBack,
    );
    final opacityInterval = intervalFromMs(revealStartMs, revealStartMs + 420, sceneDurationMs, curve: Curves.easeOut);
    final scale = Tween<double>(begin: 0.74, end: 1).animate(CurvedAnimation(parent: animation, curve: scaleInterval));
    final opacity = CurvedAnimation(parent: animation, curve: opacityInterval);

    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: Row(
          children: [
            if (onPrevious != null) _SceneNavCircleButton(icon: Icons.arrow_back_rounded, onTap: onPrevious),
            const Spacer(),
            if (onNext != null) _SceneNavCircleButton(icon: Icons.arrow_forward_rounded, onTap: onNext, pulse: true),
          ],
        ),
      ),
    );
  }
}

class _SceneNavCircleButton extends StatefulWidget {
  const _SceneNavCircleButton({required this.icon, required this.onTap, this.pulse = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool pulse;

  @override
  State<_SceneNavCircleButton> createState() => _SceneNavCircleButtonState();
}

class _SceneNavCircleButtonState extends State<_SceneNavCircleButton> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  static const int _pulseBurstMs = 600;
  static const int _pulsePauseMs = 3000;
  static const int _pulseLoopMs = _pulseBurstMs + _pulsePauseMs;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: _pulseLoopMs))
        ..repeat();
    }
  }

  static double _pulseScaleFor(double loopT) {
    const burstFraction = _pulseBurstMs / _pulseLoopMs;
    if (loopT >= burstFraction) return 1.0;
    final burstLocal = loopT / burstFraction;
    final bump = math.sin(((burstLocal * 2) % 1.0) * math.pi);
    return 1.0 + (0.12 * bump);
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: widget.onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(widget.icon, color: Colors.black.withValues(alpha: widget.onTap == null ? 0.35 : 0.8)),
        ),
      ),
    );

    final pulseController = _pulseController;
    if (pulseController == null) return button;

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return Transform.scale(scale: _pulseScaleFor(pulseController.value), child: child);
      },
      child: button,
    );
  }
}
