import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ccos/theme/ccos_theme_catalog.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

class CoconutOpenStoreScreen extends StatefulWidget {
  const CoconutOpenStoreScreen({super.key});

  static const CcosOpenStoreIntro _intro = CcosThemeCatalogSource.intro;
  static const CcosThemeOffer _featuredOffer = CcosThemeCatalogSource.featuredOffer;
  static const CcosThemeContributionCta _contributionCta = CcosThemeCatalogSource.featuredContributionCta;
  static const List<CcosOpenStoreFeature> _plannedFeatures = CcosThemeCatalogSource.plannedFeatures;
  static const CcosDeveloperSection _developerSection = CcosThemeCatalogSource.developerSection;

  @override
  State<CoconutOpenStoreScreen> createState() => _CoconutOpenStoreScreenState();
}

class _CoconutOpenStoreScreenState extends State<CoconutOpenStoreScreen> {
  static const double _sceneSpacing = 40;
  static const double _collapsedHeaderHeight = 180;
  static const Duration _sceneTransitionDelay = Duration(milliseconds: 320);

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scene3Key = GlobalKey();
  final GlobalKey _scene4Key = GlobalKey();
  final GlobalKey _scene5Key = GlobalKey();

  bool _isHeaderCollapsed = false;
  bool _isScene2Visible = false;
  bool _isScene3Visible = false;
  bool _isScene4Visible = false;
  bool _isScene5Visible = false;
  final Set<GlobalKey> _centeredScenes = <GlobalKey>{};

  Future<void> _handleHeaderStoryComplete() async {
    if (_isHeaderCollapsed) return;

    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() {
      _isHeaderCollapsed = true;
      _isScene2Visible = true;
    });
  }

  Future<void> _handleScene2Complete() async {
    if (_isScene3Visible) return;
    await Future<void>.delayed(_sceneTransitionDelay);
    if (!mounted) return;
    setState(() {
      _isScene3Visible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollSceneToCenter(_scene3Key);
      }
    });
  }

  Future<void> _handleScene3Complete() async {
    if (_isScene4Visible) return;
    await Future<void>.delayed(_sceneTransitionDelay);
    if (!mounted) return;
    setState(() {
      _isScene4Visible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollSceneToCenter(_scene4Key);
      }
    });
  }

  Future<void> _handleScene4Complete() async {
    if (_isScene5Visible) return;
    await Future<void>.delayed(_sceneTransitionDelay);
    if (!mounted) return;
    setState(() {
      _isScene5Visible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollSceneToCenter(_scene5Key);
      }
    });
  }

  Future<void> _scrollSceneToCenter(GlobalKey key) async {
    if (_centeredScenes.contains(key) || !_scrollController.hasClients) return;
    final context = key.currentContext;
    if (context == null) return;
    _centeredScenes.add(key);
    await Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(title: '', context: context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final expandedHeaderHeight = constraints.maxHeight - Sizes.size12;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.background, colors.background, colors.brandAccentBackground.withValues(alpha: 0.10)],
                stops: const [0, 0.72, 1],
              ),
            ),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Sizes.size16, Sizes.size12, Sizes.size16, _sceneSpacing),
                  sliver: SliverToBoxAdapter(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeInOutCubic,
                      height: _isHeaderCollapsed ? _collapsedHeaderHeight : expandedHeaderHeight,
                      child: _HeaderScene(
                        intro: CoconutOpenStoreScreen._intro,
                        onStoryComplete: _handleHeaderStoryComplete,
                        isCollapsed: _isHeaderCollapsed,
                      ),
                    ),
                  ),
                ),
                if (_isScene2Visible)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Sizes.size16, 0, Sizes.size16, Sizes.size32),
                    sliver: SliverList.list(
                      children: [
                        _ThemeCardScene(
                          offer: CoconutOpenStoreScreen._featuredOffer,
                          onSceneComplete: _handleScene2Complete,
                        ),
                        if (_isScene3Visible) ...[
                          const SizedBox(height: _sceneSpacing),
                          KeyedSubtree(
                            key: _scene3Key,
                            child: _ContributionScene(
                              cta: CoconutOpenStoreScreen._contributionCta,
                              onFirstVisible: () => _scrollSceneToCenter(_scene3Key),
                              onSceneComplete: _handleScene3Complete,
                            ),
                          ),
                        ],
                        if (_isScene4Visible) ...[
                          const SizedBox(height: _sceneSpacing),
                          KeyedSubtree(
                            key: _scene4Key,
                            child: _FeatureListScene(
                              features: CoconutOpenStoreScreen._plannedFeatures,
                              onFirstVisible: () => _scrollSceneToCenter(_scene4Key),
                              onSceneComplete: _handleScene4Complete,
                            ),
                          ),
                        ],
                        if (_isScene5Visible) ...[
                          const SizedBox(height: _sceneSpacing),
                          KeyedSubtree(
                            key: _scene5Key,
                            child: _DeveloperCtaScene(
                              section: CoconutOpenStoreScreen._developerSection,
                              onFirstVisible: () => _scrollSceneToCenter(_scene5Key),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

mixin _SceneVisibilityTrigger<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  static const double _visibleThreshold = 0.4;

  late final AnimationController controller = AnimationController(vsync: this, duration: animationDuration);
  bool _hasStarted = false;

  Duration get animationDuration;

  bool get disableAnimations => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (disableAnimations && !_hasStarted) {
      _hasStarted = true;
      controller.value = 1;
    }
  }

  @protected
  TickerFuture? playAnimationIfNeeded() {
    if (_hasStarted) return null;
    _hasStarted = true;
    if (disableAnimations) {
      controller.value = 1;
      return null;
    }
    return controller.forward();
  }

  void handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction >= _visibleThreshold) {
      playAnimationIfNeeded();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class RevealOnScroll extends StatelessWidget {
  const RevealOnScroll({super.key, required this.animation, required this.child, this.beginOffsetY = 24});

  final Animation<double> animation;
  final Widget child;
  final double beginOffsetY;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return child;
    }

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, beginOffsetY * (1 - value)), child: child),
        );
      },
    );
  }
}

class _HeaderScene extends StatefulWidget {
  const _HeaderScene({required this.intro, required this.onStoryComplete, required this.isCollapsed});

  final CcosOpenStoreIntro intro;
  final Future<void> Function() onStoryComplete;
  final bool isCollapsed;

  @override
  State<_HeaderScene> createState() => _HeaderSceneState();
}

class _HeaderSceneState extends State<_HeaderScene> with SingleTickerProviderStateMixin, _SceneVisibilityTrigger {
  static const double _logoDurationRatio = 0.30;
  static const double _titleStart = 0.24;
  static const double _titleEnd = 0.48;
  static const double _subtitleStart = 0.45;
  static const double _subtitleEnd = 0.72;
  static const double _descriptionStart = 0.69;
  static const double _descriptionEnd = 0.96;
  static const double _topIconCenterY = 44;
  static const double _topTitleCenterY = 100;
  static const double _topSubtitleCenterY = 132;
  static const double _topDescriptionCenterY = 156;
  static const double _iconTitleGap = _topTitleCenterY - _topIconCenterY;
  static const double _titleSubtitleGap = _topSubtitleCenterY - _topTitleCenterY;
  static const double _subtitleDescriptionGap = _topDescriptionCenterY - _topSubtitleCenterY;

  bool _didScheduleCompletion = false;

  @override
  Duration get animationDuration => const Duration(milliseconds: 3600);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didScheduleCompletion) return;
      _startStory();
    });
  }

  @override
  void handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction < 0.4) return;
    _startStory();
  }

  void _startStory() {
    if (_didScheduleCompletion) return;
    _didScheduleCompletion = true;
    final ticker = playAnimationIfNeeded();
    if (disableAnimations || ticker == null) {
      widget.onStoryComplete();
      return;
    }
    ticker.whenComplete(widget.onStoryComplete);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final size = MediaQuery.sizeOf(context);
    final Animation<double> logoScale =
        disableAnimations
            ? const AlwaysStoppedAnimation<double>(1)
            : Tween<double>(begin: (size.width + 120) / 64, end: 1).animate(
              CurvedAnimation(
                parent: controller,
                curve: const Interval(0, _logoDurationRatio, curve: Curves.easeOutExpo),
              ),
            );
    final Animation<double> logoOpacity =
        disableAnimations
            ? const AlwaysStoppedAnimation<double>(1)
            : Tween<double>(begin: 0.18, end: 1).animate(
              CurvedAnimation(
                parent: controller,
                curve: const Interval(0, _logoDurationRatio * 0.8, curve: Curves.easeOutCubic),
              ),
            );
    final titleReveal = CurvedAnimation(
      parent: controller,
      curve: const Interval(_titleStart, _titleEnd, curve: Curves.easeOutCubic),
    );
    final subtitleReveal = CurvedAnimation(
      parent: controller,
      curve: const Interval(_subtitleStart, _subtitleEnd, curve: Curves.easeOutCubic),
    );
    final descriptionReveal = CurvedAnimation(
      parent: controller,
      curve: const Interval(_descriptionStart, _descriptionEnd, curve: Curves.easeOutCubic),
    );

    return VisibilityDetector(
      key: const ValueKey('open-store-scene-header'),
      onVisibilityChanged: handleVisibilityChanged,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic,
            tween: Tween<double>(begin: 0, end: widget.isCollapsed ? 1 : 0),
            builder: (context, collapseProgress, child) {
              return AnimatedBuilder(
                animation: Listenable.merge([controller, logoScale, logoOpacity]),
                builder: (context, child) {
                  final titleProgress = disableAnimations ? 1.0 : titleReveal.value;
                  final subtitleProgress = disableAnimations ? 1.0 : subtitleReveal.value;
                  final descriptionProgress = disableAnimations ? 1.0 : descriptionReveal.value;
                  final availableHeight = constraints.maxHeight;
                  final centerY = availableHeight * 0.5;

                  final storyDescriptionCenterY = centerY;
                  final storySubtitleCenterY = centerY - (descriptionProgress * _subtitleDescriptionGap);
                  final storyTitleCenterY = storySubtitleCenterY - (subtitleProgress * _titleSubtitleGap);
                  final storyIconCenterY = storyTitleCenterY - (titleProgress * _iconTitleGap);

                  final iconCenterY = storyIconCenterY + (_topIconCenterY - storyIconCenterY) * collapseProgress;
                  final titleCenterY = storyTitleCenterY + (_topTitleCenterY - storyTitleCenterY) * collapseProgress;
                  final subtitleCenterY =
                      storySubtitleCenterY + (_topSubtitleCenterY - storySubtitleCenterY) * collapseProgress;
                  final descriptionCenterY =
                      storyDescriptionCenterY + (_topDescriptionCenterY - storyDescriptionCenterY) * collapseProgress;

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Transform.translate(
                            offset: Offset(0, iconCenterY - 32),
                            child: Opacity(
                              opacity: disableAnimations ? 1.0 : logoOpacity.value,
                              child: Transform.scale(
                                alignment: Alignment.center,
                                scale: disableAnimations ? 1.0 : logoScale.value,
                                child: SvgPicture.asset(
                                  BrandIconPath.coconutPlanet,
                                  width: 64,
                                  height: 64,
                                  colorFilter: ColorFilter.mode(colors.brandAccentBackground, BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Transform.translate(
                            offset: Offset(0, titleCenterY - 20),
                            child: RevealOnScroll(
                              animation: titleReveal,
                              beginOffsetY: 18,
                              child: Text(
                                widget.intro.title,
                                textAlign: TextAlign.center,
                                style: CoconutTypography.heading2_28_Bold.setColor(colors.primaryText),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Transform.translate(
                            offset: Offset(0, subtitleCenterY - 10),
                            child: RevealOnScroll(
                              animation: subtitleReveal,
                              beginOffsetY: 18,
                              child: Text(
                                '커뮤니티와 함께 성장하는 코코넛 월렛',
                                textAlign: TextAlign.center,
                                style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Transform.translate(
                            offset: Offset(0, descriptionCenterY - 10),
                            child: RevealOnScroll(
                              animation: descriptionReveal,
                              beginOffsetY: 18,
                              child: Text(
                                '여러분의 아이디어가 코코넛의 다음 기능이 됩니다.',
                                textAlign: TextAlign.center,
                                style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ThemeCardScene extends StatefulWidget {
  const _ThemeCardScene({required this.offer, required this.onSceneComplete});

  final CcosThemeOffer offer;
  final Future<void> Function() onSceneComplete;

  @override
  State<_ThemeCardScene> createState() => _ThemeCardSceneState();
}

class _ContributionScene extends StatefulWidget {
  const _ContributionScene({required this.cta, required this.onFirstVisible, required this.onSceneComplete});

  final CcosThemeContributionCta cta;
  final Future<void> Function() onFirstVisible;
  final Future<void> Function() onSceneComplete;

  @override
  State<_ContributionScene> createState() => _ContributionSceneState();
}

class _ContributionSceneState extends State<_ContributionScene>
    with SingleTickerProviderStateMixin, _SceneVisibilityTrigger {
  bool _didRequestCenter = false;
  bool _didNotifyCompletion = false;

  @override
  Duration get animationDuration => const Duration(milliseconds: 1600);

  Animation<double> _sceneReveal(double start, double end) {
    return CurvedAnimation(parent: controller, curve: Interval(start, end, curve: Curves.easeInOutCubic));
  }

  @override
  void handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction < 0.4) return;
    final ticker = playAnimationIfNeeded();
    if (!_didNotifyCompletion && ticker != null) {
      _didNotifyCompletion = true;
      ticker.whenComplete(widget.onSceneComplete);
    }
    if (_didRequestCenter) return;
    _didRequestCenter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onFirstVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return VisibilityDetector(
      key: const ValueKey('open-store-scene-contribution'),
      onVisibilityChanged: handleVisibilityChanged,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: colors.shadowSubtle, blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevealOnScroll(
              animation: _sceneReveal(0, 0.6),
              beginOffsetY: 28,
              child: Text(
                '💬 ${widget.cta.title}',
                style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
              ),
            ),
            const SizedBox(height: 10),
            RevealOnScroll(
              animation: _sceneReveal(0.14, 0.76),
              beginOffsetY: 28,
              child: Text(widget.cta.description, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
            ),
            const SizedBox(height: 14),
            RevealOnScroll(
              animation: _sceneReveal(0.28, 1),
              beginOffsetY: 28,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${widget.cta.ctaLabel} >',
                  style: CoconutTypography.body3_12_Bold.setColor(colors.primaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureListScene extends StatefulWidget {
  const _FeatureListScene({required this.features, required this.onFirstVisible, required this.onSceneComplete});

  final List<CcosOpenStoreFeature> features;
  final Future<void> Function() onFirstVisible;
  final Future<void> Function() onSceneComplete;

  @override
  State<_FeatureListScene> createState() => _FeatureListSceneState();
}

class _FeatureListSceneState extends State<_FeatureListScene>
    with SingleTickerProviderStateMixin, _SceneVisibilityTrigger {
  bool _didRequestCenter = false;
  bool _didNotifyCompletion = false;

  @override
  Duration get animationDuration => const Duration(milliseconds: 1900);

  Animation<double> _itemReveal(int index, int total) {
    final baseStart = 0.10 + (index * 0.12);
    final end = (baseStart + 0.56).clamp(0.0, 1.0);
    return CurvedAnimation(parent: controller, curve: Interval(baseStart, end, curve: Curves.easeInOutCubic));
  }

  @override
  void handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction < 0.4) return;
    final ticker = playAnimationIfNeeded();
    if (!_didNotifyCompletion && ticker != null) {
      _didNotifyCompletion = true;
      ticker.whenComplete(widget.onSceneComplete);
    }
    if (_didRequestCenter) return;
    _didRequestCenter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onFirstVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return VisibilityDetector(
      key: const ValueKey('open-store-scene-feature-list'),
      onVisibilityChanged: handleVisibilityChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('이런 기능을 기다려요', style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText)),
          const SizedBox(height: 16),
          for (var index = 0; index < widget.features.length; index++) ...[
            RevealOnScroll(
              animation: _itemReveal(index, widget.features.length),
              beginOffsetY: 28,
              child: _FeatureCard(feature: widget.features[index]),
            ),
            if (index != widget.features.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DeveloperCtaScene extends StatefulWidget {
  const _DeveloperCtaScene({required this.section, required this.onFirstVisible});

  final CcosDeveloperSection section;
  final Future<void> Function() onFirstVisible;

  @override
  State<_DeveloperCtaScene> createState() => _DeveloperCtaSceneState();
}

class _DeveloperCtaSceneState extends State<_DeveloperCtaScene>
    with SingleTickerProviderStateMixin, _SceneVisibilityTrigger {
  bool _didRequestCenter = false;

  @override
  Duration get animationDuration => const Duration(milliseconds: 1600);

  Animation<double> _sceneReveal(double start, double end) {
    return CurvedAnimation(parent: controller, curve: Interval(start, end, curve: Curves.easeInOutCubic));
  }

  @override
  void handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction < 0.4) return;
    playAnimationIfNeeded();
    if (_didRequestCenter) return;
    _didRequestCenter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onFirstVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return VisibilityDetector(
      key: const ValueKey('open-store-scene-developer-cta'),
      onVisibilityChanged: handleVisibilityChanged,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.brandAccentBackground.withValues(alpha: 0.12),
              colors.brandAccentBackground.withValues(alpha: 0.24),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevealOnScroll(
              animation: _sceneReveal(0, 0.58),
              beginOffsetY: 28,
              child: Text(widget.section.title, style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText)),
            ),
            const SizedBox(height: 10),
            RevealOnScroll(
              animation: _sceneReveal(0.14, 0.76),
              beginOffsetY: 28,
              child: Text(widget.section.description, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < widget.section.actions.length; index++) ...[
              RevealOnScroll(
                animation: _sceneReveal(0.28 + (index * 0.14), 1),
                beginOffsetY: 28,
                child: _DeveloperActionButton(action: widget.section.actions[index]),
              ),
              if (index != widget.section.actions.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeCardSceneState extends State<_ThemeCardScene> with SingleTickerProviderStateMixin, _SceneVisibilityTrigger {
  static const double _step = 220 / 1600;
  static const double _span = 980 / 1600;
  bool _didNotifyCompletion = false;

  @override
  Duration get animationDuration => const Duration(milliseconds: 1600);

  Animation<double> _sceneReveal(double start, double end) {
    return CurvedAnimation(parent: controller, curve: Interval(start, end, curve: Curves.easeInOutCubic));
  }

  void _showAddToast() {
    CoconutToast.showToast(
      context: context,
      text: '${widget.offer.title} 테마가 테마 화면에 추가되었어요',
      isVisibleIcon: true,
      iconPath: CommonStateIconPath.circleInfo,
    );
  }

  @override
  void handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction < 0.4) return;
    final ticker = playAnimationIfNeeded();
    if (!_didNotifyCompletion && ticker != null) {
      _didNotifyCompletion = true;
      ticker.whenComplete(widget.onSceneComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return VisibilityDetector(
      key: const ValueKey('open-store-scene-theme-card'),
      onVisibilityChanged: handleVisibilityChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RevealOnScroll(
            animation: _sceneReveal(0, _span),
            beginOffsetY: 28,
            child: Row(
              children: [
                Text('🎨 테마', style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.brandAccentBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '첫 번째 예시',
                    style: CoconutTypography.caption_10_Bold.setColor(colors.brandAccentForeground),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          RevealOnScroll(
            animation: _sceneReveal(_step, _step + _span),
            beginOffsetY: 28,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: colors.shadowSubtle, blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 104,
                    height: 136,
                    decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text(
                      '미리보기\n이미지',
                      textAlign: TextAlign.center,
                      style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.offer.title, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
                        const SizedBox(height: 4),
                        Text(widget.offer.author, style: CoconutTypography.caption_10.setColor(colors.secondaryText)),
                        const SizedBox(height: 10),
                        Text(widget.offer.description, style: CoconutTypography.body3_12.setColor(colors.primaryText)),
                        const SizedBox(height: 12),
                        const Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [_ThemeTagChip(label: '밝은 테마'), _ThemeTagChip(label: '무료')],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          RevealOnScroll(
            animation: _sceneReveal(_step * 2, 1),
            beginOffsetY: 28,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primaryText,
                  foregroundColor: colors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _showAddToast,
                child: Text('테마 화면에 추가하기', style: CoconutTypography.body2_14_Bold.setColor(colors.background)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTagChip extends StatelessWidget {
  const _ThemeTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: CoconutTypography.caption_10.setColor(colors.secondaryText)),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final CcosOpenStoreFeature feature;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: colors.shadowSubtle, blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_featureIcon(feature.iconKey), color: _featureIconColor(feature.iconKey), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                if (feature.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(feature.description, style: CoconutTypography.caption_10.setColor(colors.secondaryText)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperActionButton extends StatelessWidget {
  const _DeveloperActionButton({required this.action});

  final CcosDeveloperAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          foregroundColor: colors.primaryText,
        ),
        onPressed: () {},
        child: Row(
          children: [
            Icon(_developerIcon(action.iconKey), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(action.label, style: CoconutTypography.body3_12.setColor(colors.primaryText))),
          ],
        ),
      ),
    );
  }
}

IconData _featureIcon(String key) {
  return switch (key) {
    'analysis' => Icons.bar_chart_rounded,
    'layers' => Icons.layers_outlined,
    'widget' => Icons.widgets_outlined,
    'tools' => Icons.auto_fix_high_outlined,
    'idea' => Icons.lightbulb_outline_rounded,
    _ => Icons.apps_outlined,
  };
}

Color _featureIconColor(String key) {
  return switch (key) {
    'analysis' => const Color(0xFF36A5FF),
    'layers' => const Color(0xFFA85DFF),
    'widget' => const Color(0xFFFF8A3D),
    'tools' => const Color(0xFF19B9A6),
    'idea' => const Color(0xFFFFC542),
    _ => const Color(0xFF8C95A1),
  };
}

IconData _developerIcon(String key) {
  return switch (key) {
    'code' => Icons.code_rounded,
    'guide' => Icons.article_outlined,
    _ => Icons.open_in_new_rounded,
  };
}
