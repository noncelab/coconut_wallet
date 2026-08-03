import 'dart:ui';
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
  static const CcosFeatureListing _featuredListing = CcosFeatureRegistrySource.featuredListing;
  static const Duration _loadingDuration = Duration(milliseconds: 4600);
  static const Duration _defaultSceneDuration = Duration(milliseconds: 2200);
  static const Duration _ideaSceneDuration = Duration(milliseconds: 8800);
  static const Duration _buildSceneDuration = Duration(milliseconds: 13400);
  static const Duration _firstPowSceneDuration = Duration(milliseconds: 11000);
  static const Duration _discoverSceneDuration = Duration(milliseconds: 9800);
  static const Duration _contributeSceneDuration = Duration(milliseconds: 9800);

  static const Color _screenBackground = Color(0xFFCDD4D7);
  static const Color _loadingBackground = Color(0xFFF9F8F6);
  static const Color _loadingTextPrimary = Color(0xFF0B0B11);
  static const Color _textPrimary = Color(0xFF10161C);
  static const Color _textSecondary = Color(0xB3515F6B);
  static const Color _accentBlue = Color(0xFF68D5FF);
  static const Color _accentPurple = Color(0xFFAD74FF);
  static const Color _accentMint = Color(0xFF73F4DE);

  final PageController _pageController = PageController();
  late final AnimationController _loadingController = AnimationController(vsync: this, duration: _loadingDuration);
  late final AnimationController _sceneController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final CurvedAnimation _loadingCurve = CurvedAnimation(parent: _loadingController, curve: Curves.easeInOutCubic);
  // Drives the "droplet splash" entrance of the scene-overview panel when it opens.
  late final AnimationController _overviewController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  bool _hasCompletedLoading = false;
  bool _isSceneOverviewVisible = false;
  int _currentSceneIndex = 0;

  Future<void> _handleAddTheme(BuildContext context) async {
    final provider = context.read<PreferenceProvider>();
    if (_featuredListing.requiresEntitlement) {
      await provider.markCcosFeaturePurchased(_featuredListing.id);
    }
    await provider.activateCcosFeature(_featuredListing.id);
    if (!context.mounted) return;
    CoconutToast.showToast(
      context: context,
      text: '${_featuredListing.title} 기능이 활성화되었어요',
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
                  title: '코코넛 과육 테마를 삭제할까요?',
                  description: '현재 코코넛 과육 테마를 사용하고 있어요. 삭제하면 기본 테마가 적용돼요.',
                  leftButtonText: '취소',
                  rightButtonText: '삭제',
                  onTapLeft: () => Navigator.pop(context, false),
                  onTapRight: () => Navigator.pop(context, true),
                ),
          ) ??
          false;

      if (!confirmed) return;
      await provider.changeThemeVariant(CoconutThemeVariant.dark);
    }

    await provider.deactivateCcosFeature(_featuredListing.id);
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
        label: 'IDEA',
        title: '각자의 실험이 흩어지기보다\n함께 연결되어\n더 큰 네트워크 효과를 만들 수 있다면,',
        description: '작은 아이디어 하나로도\n비트코인 스탠다드를\n조금씩 앞당길 수 있지 않을까요?',
        overviewStep: '01',
        overviewTitle: '좋은 아이디어가\n더 큰 파급으로 이어지도록',
        overviewSubtitle: '',
        accent: _accentMint,
        buildHero: (_, __) => const SizedBox.shrink(),
      ),
      _OpenStoreSceneDefinition(
        index: 1,
        chapter: '02 / 05',
        label: 'BUILD',
        title: '누구나 비트코인\n빌더가 되는 세상',
        description: '여러분의 PoW가\n코코넛 안에서\n기능이 되어 사용자와 만납니다',
        overviewStep: '02',
        overviewTitle: '나의 아이디어가\n모두의 기능이 되는 공간',
        overviewSubtitle: '',
        accent: _accentBlue,
        buildHero: (_, __) => const SizedBox.shrink(),
      ),
      _OpenStoreSceneDefinition(
        index: 2,
        chapter: '03 / 05',
        label: 'FIRST PoW',
        title: '첫 번째 PoW는\n코코넛 팀이\n먼저 남겨봤습니다.',
        description: '코코넛 과육 테마는 앞으로 오픈 스토어에 올라올 기능이 어떤 모습으로 소개되고 사용되는지 보여주기 위한 첫 번째 예시입니다.',
        overviewStep: '03',
        overviewTitle: '첫 PoW\n코코넛 과육 테마 by 코코넛 팀',
        overviewHighlight: '첫 PoW',
        overviewSubtitle: '',
        accent: _accentPurple,
        buildHero:
            (context, animation) => FirstPowSceneBody(
              animation: animation,
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
        label: 'DISCOVER',
        title: '',
        description: '',
        overviewStep: '04',
        overviewTitle: '모든 비트코인 빌더가\n코코넛 안에서 빛날 수 있도록',
        overviewSubtitle: '',
        accent: _accentMint,
        buildHero: (_, __) => const SizedBox.shrink(),
      ),
      _OpenStoreSceneDefinition(
        index: 4,
        chapter: '05 / 05',
        label: 'CONTRIBUTE',
        title: '',
        description: '',
        overviewStep: '05',
        overviewTitle: '다음 PoW를\n기다립니다',
        overviewHighlight: '다음 PoW',
        overviewSubtitle: '',
        accent: _accentPurple,
        buildHero: (_, __) => const SizedBox.shrink(),
      ),
    ];
  }

  Duration _sceneDurationFor(int index) {
    switch (index) {
      case 0:
        return _ideaSceneDuration;
      case 1:
        return _buildSceneDuration;
      case 2:
        return _firstPowSceneDuration;
      case 3:
        return _discoverSceneDuration;
      case 4:
        return _contributeSceneDuration;
      default:
        return _defaultSceneDuration;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadingController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _hasCompletedLoading = true;
        });
        _sceneController.duration = _sceneDurationFor(_currentSceneIndex);
        _sceneController.forward(from: 0);
      }
    });
    _loadingController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _loadingController.dispose();
    _sceneController.dispose();
    _overviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _hasCompletedLoading ? _screenBackground : _loadingBackground,
      appBar:
          _hasCompletedLoading && !_isSceneOverviewVisible
              ? CoconutAppBar.build(
                context: context,
                foregroundColor: _textPrimary,
                // A soft tint pulled from the screen's own backdrop gradient, instead of the
                // app bar's default (too-dark-on-this-light-palette) press highlight.
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
              )
              : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isStory = child.key == const ValueKey('open-store-story');
          if (isStory) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0.14, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            return SlideTransition(position: offsetAnimation, child: FadeTransition(opacity: animation, child: child));
          }
          return FadeTransition(opacity: animation, child: child);
        },
        child:
            _hasCompletedLoading
                ? _buildStoryPager()
                : _OpenStoreLoadingSequence(key: const ValueKey('open-store-loading'), animation: _loadingCurve),
      ),
    );
  }

  Widget _buildStoryPager() {
    return Stack(
      key: const ValueKey('open-store-story'),
      children: [
        const Positioned.fill(child: _OpenStoreBackdrop()),
        Consumer<PreferenceProvider>(
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
                        chapter: item.chapter,
                        sceneIndex: item.index,
                        sceneCount: sceneItems.length,
                        label: item.label,
                        title: item.title,
                        description: item.description,
                        hero: item.buildHero(context, _sceneController),
                        sceneAnimation: _sceneController,
                        onPrevious: item.index == 0 ? null : () => _animateToScene(item.index - 1),
                        onNext: item.index == sceneItems.length - 1 ? null : () => _animateToScene(item.index + 1),
                      ),
                  ],
                ),
                if (_isSceneOverviewVisible)
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
        ),
      ],
    );
  }
}

class _OpenStoreSceneDefinition {
  const _OpenStoreSceneDefinition({
    required this.index,
    required this.chapter,
    required this.label,
    required this.title,
    required this.description,
    required this.overviewStep,
    required this.overviewTitle,
    required this.overviewSubtitle,
    required this.accent,
    required this.buildHero,
    this.overviewHighlight,
  });

  final int index;
  final String chapter;
  final String label;
  final String title;
  final String description;
  final String overviewStep;
  final String overviewTitle;
  // Exact prefix of overviewTitle to bold/enlarge in the navigation overlay. Defaults to just
  // the first word (split on the first space) when omitted.
  final String? overviewHighlight;
  final String overviewSubtitle;
  final Color accent;
  final Widget Function(BuildContext context, Animation<double> animation) buildHero;
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
        const iconPhaseEnd = 0.50;
        const ringDelayAfterIcon = 300 / 4600;
        const ringDrawDuration = 2000 / 4600;
        const ringStart = iconPhaseEnd + ringDelayAfterIcon;
        const ringOpacityDuration = 160 / 4600;
        const polishStart = ringStart + ringDrawDuration;

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
        final startIconSize = MediaQuery.of(context).size.width * 1.2;

        return Stack(
          fit: StackFit.expand,
          children: [
            const _OpenStoreLoadingBackdrop(),
            Align(
              alignment: Alignment.center,
              child: Transform.scale(
                scale: iconScale,
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
                      'Coconut\nOpen Store',
                      style: CoconutTypography.heading1_32_Bold
                          .setColor(_CoconutOpenStoreIntroScreenState._loadingTextPrimary)
                          .copyWith(fontSize: 42, height: 1, letterSpacing: 0.7, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  // Roughly where the hamburger action button sits in the app bar, so the panel and its
  // splash burst appear to originate from the button that was actually tapped.
  static const Alignment _originAlignment = Alignment(0.94, -1);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entranceAnimation,
      builder: (context, child) {
        final backdropOpacity = Curves.easeOut.transform(entranceAnimation.value);
        // A quick droplet-like burst from the button, ahead of the panel settling into place.
        final splashProgress = Curves.easeOut.transform((entranceAnimation.value / 0.42).clamp(0.0, 1.0));
        final splashOpacity = (1 - Curves.easeIn.transform((entranceAnimation.value / 0.6).clamp(0.0, 1.0))) * 0.5;
        // Overshoots slightly past 1.0 then settles, like a droplet stretching before it relaxes.
        final panelScale = Curves.easeOutBack.transform(entranceAnimation.value);
        final panelOpacity = Curves.easeOut.transform((entranceAnimation.value / 0.6).clamp(0.0, 1.0));

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose, child: const SizedBox.expand()),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: backdropOpacity,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(color: const Color(0x14F4F7F8)),
                ),
              ),
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
                // Soft light-colored halo along the outside of the edge - an "edge-lit glass"
                // cue that reads regardless of whatever happens to be behind the panel.
                BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: -2),
              ],
            ),
            child: LiquidGlassSurface(
              // Border/shadow already come from the DecoratedBox above, so the surface itself
              // stays borderless (default rim is off) - it only supplies refraction and blur.
              cornerRadius: 34,
              blurSigma: 6,
              distortion: 0.16,
              distortionWidth: 42,
              magnification: 1.1,
              tintColor: const Color(0x2AFBFDFF),
              child: Stack(
                children: [
                  // Specular highlight - the bright glint of light across the top edge
                  // that reads as "glass" rather than a flat frosted panel. Backdrop-
                  // independent, unlike the lens warp, so it always sells the material.
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
                  // A second, fainter diagonal glint from the opposite corner adds
                  // dimensionality that doesn't depend on the backdrop either.
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
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: CoconutIconButton(
                            onPressed: onClose,
                            icon: SvgPicture.asset(
                              CommonActionIconPath.close,
                              width: 28,
                              height: 28,
                              colorFilter: const ColorFilter.mode(
                                _CoconutOpenStoreIntroScreenState._textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 34),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _SceneNavigationRow(
                                item: item,
                                isSelected: currentIndex == index,
                                isReversed: index.isOdd,
                                onTap: () => onSelect(index),
                              );
                            },
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

  // Drives a "jelly" squash-and-stretch: a quick press-in, then a springy (slightly
  // overshooting) release back to rest, instead of a stiff uniform scale.
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
          // Vertically compresses while bulging horizontally (and vice versa on the
          // springy overshoot past 1.0) - the squash-and-stretch that reads as "jelly".
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: _isPressed ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
                border: _isPressed ? Border.all(color: Colors.white.withValues(alpha: 0.42), width: 1) : null,
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: widget.isReversed ? null : 0,
                    right: widget.isReversed ? 0 : null,
                    top: 0,
                    child: _SceneNavigationNumber(step: widget.item.overviewStep, alignEnd: widget.isReversed),
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
    final String highlightText;
    final String remainingText;
    final explicitHighlight = item.overviewHighlight;
    if (explicitHighlight != null && item.overviewTitle.startsWith(explicitHighlight)) {
      highlightText = explicitHighlight;
      remainingText = item.overviewTitle.substring(explicitHighlight.length);
    } else {
      final titleParts = item.overviewTitle.split(' ');
      highlightText = titleParts.isNotEmpty ? titleParts.first : item.overviewTitle;
      remainingText = titleParts.length > 1 ? ' ${titleParts.sublist(1).join(' ')}' : '';
    }

    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        RichText(
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          text: TextSpan(
            children: [
              TextSpan(
                text: highlightText,
                style: CoconutTypography.heading3_21_Bold.setColor(_CoconutOpenStoreIntroScreenState._textPrimary),
              ),
              if (remainingText.isNotEmpty)
                TextSpan(
                  text: remainingText,
                  style: CoconutTypography.heading4_18.setColor(_CoconutOpenStoreIntroScreenState._textPrimary),
                ),
            ],
          ),
        ),
        if (item.overviewSubtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            item.overviewSubtitle,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: CoconutTypography.heading4_18.setColor(_CoconutOpenStoreIntroScreenState._textPrimary),
          ),
        ],
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
    required this.chapter,
    required this.sceneIndex,
    required this.sceneCount,
    required this.label,
    required this.title,
    required this.description,
    required this.hero,
    required this.sceneAnimation,
    required this.onPrevious,
    required this.onNext,
  });

  final String chapter;
  final int sceneIndex;
  final int sceneCount;
  final String label;
  final String title;
  final String description;
  final Widget hero;
  final Animation<double> sceneAnimation;
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
        final isContributeScene = sceneIndex == 4;
        final titleText = typewriterText(title, sceneAnimation, const Interval(0.14, 0.56, curve: Curves.linear));
        final descriptionText = typewriterText(
          description,
          sceneAnimation,
          const Interval(0.52, 0.84, curve: Curves.linear),
        );
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
                                  chapter,
                                  style: CoconutTypography.caption_10_Bold.setColor(
                                    Colors.white,
                                    // _CoconutOpenStoreIntroScreenState._textSecondary,
                                  ),
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
                                    ? IdeaSceneBody(animation: sceneAnimation)
                                    : isBuildScene
                                    ? BuildSceneBody(animation: sceneAnimation, title: title, description: description)
                                    : isFirstPowScene
                                    ? hero
                                    : isDiscoverScene
                                    ? DiscoverSceneBody(animation: sceneAnimation)
                                    : isContributeScene
                                    ? ContributeSceneBody(
                                      animation: sceneAnimation,
                                      onStartPr: () => launchURL(CONTRIBUTING_URL),
                                    )
                                    : Column(
                                      children: [
                                        Expanded(flex: 12, child: hero),
                                        Expanded(
                                          flex: 10,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    titleText,
                                                    style: CoconutTypography.heading3_21_Bold.setColor(
                                                      _CoconutOpenStoreIntroScreenState._textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: SizedBox(
                                                      width: 236,
                                                      child: Text(
                                                        descriptionText,
                                                        textAlign: TextAlign.right,
                                                        style: CoconutTypography.heading4_18_Bold.setColor(
                                                          _CoconutOpenStoreIntroScreenState._textPrimary.withValues(
                                                            alpha: 0.9,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                          const SizedBox(height: 10),
                          _SceneBottomNavigation(
                            animation: sceneAnimation,
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
    // 70% speed: same distance over a longer duration (14000 / 0.7).
    duration: const Duration(milliseconds: 20000),
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
    const bannerText = 'Coconut Open Store '; // 배너 간격 유지를 위해 스페이스 포함
    final textStyle = CoconutTypography.heading1_32_Bold
        .setColor(Colors.white.withValues(alpha: 0.16))
        .copyWith(fontSize: 140, height: 1, letterSpacing: -2.8, fontWeight: FontWeight.w800);
    final textPainter =
        TextPainter(text: const TextSpan(), textScaler: MediaQuery.textScalerOf(context))
          ..text = TextSpan(text: bannerText, style: textStyle)
          ..textDirection = TextDirection.ltr
          ..maxLines = 1
          ..layout();
    // Keep the phrases visually close enough that the next "Coconut" begins entering as the
    // previous "Store" leaves, so it reads like one continuous ribbon rather than isolated words.
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
                    // Positioned (rather than a bare Stack child) forces a tight width of
                    // trackWidth regardless of the Stack's own (narrower) size, so the track
                    // never gets clamped down and overflows its Row.
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
    required this.currentIndex,
    required this.sceneCount,
    required this.onPrevious,
    required this.onNext,
  });

  final Animation<double> animation;
  final int currentIndex;
  final int sceneCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: 0.74,
      end: 1,
    ).animate(CurvedAnimation(parent: animation, curve: const Interval(0.74, 1.0, curve: Curves.easeOutBack)));
    final opacity = CurvedAnimation(parent: animation, curve: const Interval(0.72, 0.96, curve: Curves.easeOut));

    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: Row(
          children: [
            if (onPrevious != null) _SceneNavCircleButton(icon: Icons.arrow_back_rounded, onTap: onPrevious),
            const Spacer(),
            if (onNext != null) _SceneNavCircleButton(icon: Icons.arrow_forward_rounded, onTap: onNext),
          ],
        ),
      ),
    );
  }
}

class _SceneNavCircleButton extends StatelessWidget {
  const _SceneNavCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(
            icon,
            color:
                onTap == null
                    ? _CoconutOpenStoreIntroScreenState._textSecondary.withValues(alpha: 0.35)
                    : _CoconutOpenStoreIntroScreenState._textPrimary,
          ),
        ),
      ),
    );
  }
}
