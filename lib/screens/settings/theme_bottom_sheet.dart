import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutToast, CoconutToastLevel, CoconutPopup;
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_content.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_navigation.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/features/ccos/card/coconut_open_store_intro_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

/// CCOS `theme` 카테고리의 host surface(진입점)다.
/// `CcosFeatureCategory.theme`으로 등록된 기능(현재는 `CoconutPulpFeature`)이 활성화되어 있으면
/// 여기 테마 목록에 실제로 노출된다.
///
/// 다른 카테고리를 새로 추가하는 경우 이 파일을 그대로 복사하지 말 것
/// 카테고리마다 또는 기능마다 최적화된 진입점을 새로 설계한다
/// (`docs/ccos/foundation/architecture.md` 6.1절 참고).
class ThemeBottomSheet extends StatefulWidget {
  const ThemeBottomSheet({super.key});

  @override
  State<ThemeBottomSheet> createState() => _ThemeBottomSheetState();
}

class _ThemeBottomSheetState extends State<ThemeBottomSheet> {
  // 스와이프로 삭제 가능한 테마
  CoconutThemeVariant? _swipedVariant;

  Future<void> _onThemeSelected(BuildContext context, CoconutThemeVariant variant) async {
    if (_swipedVariant != null) {
      setState(() => _swipedVariant = null);
    }
    await context.read<PreferenceProvider>().changeThemeVariant(variant);
  }

  Future<void> _handleDeleteTheme(BuildContext context, PreferenceProvider provider) async {
    final featuredListing = CcosFeatureRegistrySource.featuredListing;
    final isCurrentlyApplied = provider.themeVariant == CoconutThemeVariant.coconutPulp;

    if (isCurrentlyApplied) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder:
                (dialogContext) => CoconutPopup(
                  languageCode: provider.language,
                  title: t.ccos.intro_screen.delete_popup_title,
                  description: t.ccos.intro_screen.delete_popup_description,
                  leftButtonText: t.cancel,
                  rightButtonText: t.delete,
                  onTapLeft: () => Navigator.pop(dialogContext, false),
                  onTapRight: () => Navigator.pop(dialogContext, true),
                ),
          ) ??
          false;

      if (!confirmed) {
        if (mounted) setState(() => _swipedVariant = null);
        return;
      }
      await provider.changeThemeVariant(CoconutThemeVariant.dark);
    }

    await provider.deactivateCcosFeature(featuredListing.id);
    if (!context.mounted) return;
    setState(() => _swipedVariant = null);
    CoconutToast.showToast(
      context: context,
      text: t.ccos.intro_screen.theme_removed,
      isVisibleIcon: true,
      iconPath: CommonStateIconPath.circleInfo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Consumer<PreferenceProvider>(
      builder: (context, provider, child) {
        // 여기가 실제 진입점: theme 카테고리이면서 사용자가 활성화(+구매 완료)한
        // CCOS 기능만 이 목록에 나타난다. category 체크는 `featuredListing`이
        // 우연히 테마를 가리키고 있다는 사실에 기대지 않기 위한 명시적 가드다 —
        // registry에 theme이 아닌 다른 카테고리 기능이 늘어나도 여기에는 영향을
        // 주지 않는다. isAvailable(=activated && entitled)은
        // PreferenceProvider.loadCcosRuntimeState()가 앱 진입 시 로컬 상태에서
        // 다시 계산한 값이다 (lib/ccos/ccos_feature_runtime.dart 참고).
        //
        // 주의: 이 체크는 여전히 단일 CCOS 테마(Coconut Pulp) 하나만 가정한다.
        // 두 번째 CCOS 테마가 등록되더라도 이 화면은 그걸 자동으로 보여주지
        // 않는다 — 현재는 scope 밖이며, 필요해지면 allListings를 순회하는
        // 구조로 다시 설계해야 한다.
        final ccosThemeListing = CcosFeatureRegistrySource.featuredListing;
        final isCcosThemeSelectable =
            ccosThemeListing.category == CcosFeatureCategory.theme &&
            ccosThemeListing.isSelectableTheme &&
            provider.getCcosFeatureAvailability(ccosThemeListing.id).isAvailable;

        final builtInThemes = <_ThemeOption>[
          _ThemeOption(variant: CoconutThemeVariant.dark, title: t.theme_dark),
          _ThemeOption(variant: CoconutThemeVariant.light, title: t.theme_light),
          if (isCcosThemeSelectable)
            _ThemeOption(variant: CoconutThemeVariant.coconutPulp, title: t.theme_coconut_pulp),
        ];
        return Scaffold(
          backgroundColor: colors.background,
          appBar: CoconutAppBar.build(
            title: t.theme,
            context: context,
            onBackPressed: null,
            isBottom: true,
            actionButtonList: [
              CoconutAppBarActionButton(
                onPressed: () => openCoconutOpenStoreIntroScreen(context),
                icon: SvgPicture.asset(
                  BrandIconPath.coconutPlanet,
                  width: Sizes.size24,
                  height: Sizes.size24,
                  colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                ),
              ),
            ],
          ),
          body: GestureDetector(
            onTap: () {
              if (_swipedVariant != null) setState(() => _swipedVariant = null);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
              children: [
                const SizedBox(height: Sizes.size8),
                if (provider.shouldShowOpenStoreIntroCard) ...[
                  CoconutOpenStoreIntroCard(
                    intro: CcosOpenStoreContentSource.intro,
                    onTap: () => openCoconutOpenStoreIntroScreen(context),
                    onDismiss: provider.hideOpenStoreIntroCardForOneMonth,
                  ),
                  const SizedBox(height: Sizes.size20),
                ],
                ..._buildThemeRows(context, provider, builtInThemes),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildThemeRows(BuildContext context, PreferenceProvider provider, List<_ThemeOption> options) {
    final colors = context.coconutColors;
    final selectedVariant = provider.themeVariant;
    final widgets = <Widget>[];
    for (int index = 0; index < options.length; index++) {
      final option = options[index];
      final isSelected = option.variant == selectedVariant;
      final isCoconutPulp = option.variant == CoconutThemeVariant.coconutPulp;
      final subtitle =
          isCoconutPulp
              ? '${CcosFeatureRegistrySource.featuredListing.author} · ${CcosFeatureRegistrySource.featuredListing.authorBio}'
              : null;

      widgets.add(
        // 두 기본 테마(어두운 테마, 밝은 테마)는 삭제 불가
        isCoconutPulp
            ? _DeletableThemeRow(
              title: option.title,
              subtitle: subtitle,
              isSelected: isSelected,
              isSwiped: _swipedVariant == option.variant,
              onSwipeChanged: (isSwiped) {
                setState(() => _swipedVariant = isSwiped ? option.variant : null);
              },
              onDelete: () => _handleDeleteTheme(context, provider),
              onTap: () => _onThemeSelected(context, option.variant),
            )
            : InkWell(
              onTap: () => _onThemeSelected(context, option.variant),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Sizes.size20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(option.title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: SvgPicture.asset(
                          CommonActionIconPath.check,
                          colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      );
      if (index < options.length - 1) {
        widgets.add(Divider(color: colors.primaryText.withValues(alpha: 0.12), height: 1));
      }
    }
    return widgets;
  }
}

class _ThemeOption {
  const _ThemeOption({required this.variant, required this.title});

  final CoconutThemeVariant variant;
  final String title;
}

// 왼쪽으로 스와이프 시 오른쪽에 삭제 버튼이 드러나는 Theme Row
class _DeletableThemeRow extends StatefulWidget {
  const _DeletableThemeRow({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isSwiped,
    required this.onSwipeChanged,
    required this.onDelete,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final bool isSwiped;
  final ValueChanged<bool> onSwipeChanged;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  State<_DeletableThemeRow> createState() => _DeletableThemeRowState();
}

class _DeletableThemeRowState extends State<_DeletableThemeRow> with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  late final AnimationController _animationController;
  Animation<double> _animation = const AlwaysStoppedAnimation(0);
  bool _isAnimating = false;
  VoidCallback? _pendingOnComplete;

  static const double _swipeThreshold = 0.15; // 15% 이상 스와이프 시 삭제 동작
  static const double _swipeStopPosition = 0.2;
  static const double _borderRadius = 12;
  static const double _deleteButtonSize = 52;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void didUpdateWidget(covariant _DeletableThemeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSwiped != widget.isSwiped && !widget.isSwiped) {
      _animateToOriginalPosition();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _animateTo(double end, {VoidCallback? onComplete}) {
    _isAnimating = true;
    _pendingOnComplete = onComplete;
    _animationController.stop();
    _animationController.reset();
    _animation = Tween<double>(
      begin: _dragOffset,
      end: end,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut))..addListener(() {
      if (mounted) setState(() => _dragOffset = _animation.value);
    });
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _isAnimating = false;
        if (status == AnimationStatus.completed) {
          final callback = _pendingOnComplete;
          _pendingOnComplete = null;
          callback?.call();
        }
      }
    });
    _animationController.forward();
  }

  void _animateToOriginalPosition() => _animateTo(0);

  void _animateToDeletePosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    _animateTo(-screenWidth * _swipeStopPosition);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final screenWidth = MediaQuery.of(context).size.width;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_borderRadius),
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: colors.background)),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: screenWidth * _swipeStopPosition,
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDelete,
                child: Container(
                  width: _deleteButtonSize,
                  height: _deleteButtonSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.danger,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(_borderRadius),
                      bottomRight: Radius.circular(_borderRadius),
                    ),
                  ),
                  child: SvgPicture.asset(
                    CommonActionIconPath.trash,
                    width: 20,
                    colorFilter: ColorFilter.mode(colors.iconOnDanger, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (_isAnimating) return;
              if (details.delta.dx < 0 || (details.delta.dx > 0 && _dragOffset < 0)) {
                setState(() {
                  _dragOffset = (_dragOffset + details.delta.dx).clamp(-screenWidth, 0);
                });
              }
            },
            onHorizontalDragEnd: (details) {
              if (_isAnimating) return;
              final swipeThresholdPx = screenWidth * _swipeThreshold;
              if (_dragOffset.abs() >= swipeThresholdPx) {
                widget.onSwipeChanged(true);
                _animateToDeletePosition();
              } else {
                widget.onSwipeChanged(false);
                _animateToOriginalPosition();
              }
            },
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Container(
                color: colors.background,
                child: InkWell(
                  onTap: () {
                    if (_dragOffset != 0) {
                      widget.onSwipeChanged(false);
                    } else {
                      widget.onTap();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sizes.size20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: Sizes.size4),
                                Text(
                                  widget.subtitle!,
                                  style: CoconutTypography.caption_10.setColor(colors.secondaryText),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.isSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: SvgPicture.asset(
                              CommonActionIconPath.check,
                              colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
