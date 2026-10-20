import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutToast, CoconutToastLevel, CoconutUnderlinedButton;
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/safety/help_channels_sheet.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart' show CoconutToast, CoconutToastLevel;
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_guide_scaffold.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

/// 줄 사이로 갈리면 안 되는 짧은 값(플랜 줄의 "1년"·가격)
String _unbroken(String text) => TextUtils.preventLineBreakInsideWords(text).replaceAll(' ', '\u00A0');

/// Coconut Premium 페이월(PA1 소개 → PA2 무료와 비교 → PA3 플랜을 한 화면에). Premium 카드·칩·설정에서만 연다
class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  /// 구독(또는 복원)을 마치면 true
  static Future<bool> open(BuildContext context) async {
    final purchased = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        settings: const RouteSettings(name: '/premium/paywall'),
        builder: (_) => const CustomLoadingOverlay(child: PremiumPaywallScreen()),
      ),
    );
    return purchased ?? false;
  }

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  late final EntitlementService _premium = context.read<EntitlementService>();

  /// null = 불러오는 중
  List<PremiumProduct>? _products;
  PremiumProduct? _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _products = null);
    final products = await _premium.loadProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _selected = products.firstOrNull; // 연간이 먼저
    });
  }

  Future<void> _subscribe() async {
    final product = _selected;
    if (product == null || _busy) return;
    if (_premium.state.value.isActive) {
      _toast(t.premium.toast.already_subscribed);
      return;
    }
    setState(() => _busy = true);
    context.loaderOverlay.show();
    var outcome = PurchaseOutcome.failed;
    try {
      outcome = await _premium.purchase(product);
    } catch (_) {
      // 서비스가 뜻밖에 실패해도 화면은 원래대로 돌아오고 실패 안내를 한다
    } finally {
      if (mounted) {
        context.loaderOverlay.hide();
        setState(() => _busy = false);
      }
    }
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.purchased:
        await _showResult();
        if (mounted) Navigator.of(context).pop(true);
      case PurchaseOutcome.pending:
        await _showResult(pending: true);
        if (mounted) Navigator.of(context).pop(false);
      case PurchaseOutcome.cancelled:
        break; // 스토어 창을 닫았으면 아무 안내 없이 원래대로
      case PurchaseOutcome.failed:
      case PurchaseOutcome.unavailable:
        vibrateLightDouble();
        _toast(t.premium.toast.failed, warning: true);
    }
  }

  /// 구독 결과(§10.4). 승인 대기는 체크 대신 정보 아이콘
  Future<void> _showResult({bool pending = false}) {
    final colors = context.coconutColors;
    return Navigator.of(context).push(
      CupertinoPageRoute<void>(
        settings: RouteSettings(name: pending ? '/premium/pending' : '/premium/purchased'),
        builder:
            (resultContext) => SafetyResultPage(
              key: Key(pending ? 'premium-result-pending' : 'premium-result-purchased'),
              title: safetyKoText(pending ? t.premium.purchased.pending_title : t.premium.purchased.title),
              description: safetyKoText(pending ? t.premium.purchased.pending_body : t.premium.purchased.body),
              icon:
                  pending
                      ? SafetyIconCircle(
                        size: 64,
                        background: colors.iconBackgroundSubtle,
                        icon: SvgPicture.asset(
                          CommonStateIconPath.circleInfo,
                          width: 32,
                          height: 32,
                          colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                        ),
                      )
                      : null,
              // 승인 대기는 아직 Premium이 아니라 칩·비상 이동 안내가 없다
              badge: pending ? null : const PremiumChip(),
              buttonText: t.confirm,
              onButton: () => Navigator.of(resultContext).pop(),
              children: [
                // POLISH §4 D9: 목적지를 정해야 초안이 생긴다(정하는 곳 안내). "서명과 전송은 직접"은 본문에 그대로
                if (!pending)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      safetyKoText(t.premium.purchased.rescue_hint),
                      key: const Key('premium-result-rescue-hint'),
                      textAlign: TextAlign.center,
                      // 다음 단계 안내라 위계를 지킨다: 제목 > 본문 > 안내(R5의 secondaryTextStrong은 안전 필독 글 전용)
                      style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                    ),
                  ),
              ],
            ),
      ),
    );
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final restored = await restorePremiumPurchases(context, _premium);
    if (!mounted) return;
    setState(() => _busy = false);
    if (restored) Navigator.of(context).pop(true);
  }

  void _toast(String text, {bool warning = false}) => CoconutToast.showToast(
    context: context,
    text: text,
    isVisibleIcon: true,
    iconPath: warning ? CommonStateIconPath.triangleWarning : CommonStateIconPath.circleInfo,
    level: warning ? CoconutToastLevel.warning : CoconutToastLevel.info,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final trial = _selected?.freeTrialDays != null;
    return Scaffold(
      key: const Key('premium-paywall'),
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        context: context,
        title: t.premium.name,
        isBottom: true,
        backgroundColor: colors.background,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            // 아래 24는 페이드 자리
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [..._intro(context), ..._compare(context), ..._plans(context)],
            ),
          ),
          // 본문이 고정 묶음 앞에서 칼로 자른 듯 끊기지 않게(FixedBottomButton 둘레와 같은 페이드)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 24,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.background.withValues(alpha: 0), colors.background],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottom(context, trial),
    );
  }

  /// 구독 버튼을 누를 수 있으면 고른 플랜의 가격·기간·자동 갱신과 약관·개인정보 링크가 늘 버튼 바로 위에 보인다
  /// (Apple 3.1.2(c)·Schedule 2, Play 구독 정책: 조건을 스크롤 아래에 숨기지 않는다). 구매 복원은 버튼 바로 위 따로 한 줄(UI_SPEC §10.3).
  /// 이 묶음만 글자를 1.3배에서 멈춘다(2.0배·320dp에서 화면 절반을 넘겨 본문이 안 보였다). 전체 고지는 본문 끝에 상한 없이 그대로
  Widget _bottom(BuildContext context, bool trial) {
    final colors = context.coconutColors;
    final selected = _selected;
    final store = defaultTargetPlatform == TargetPlatform.android ? 'Google Play' : 'App Store';
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SafeArea(
        key: const Key('premium-paywall-bottom'),
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selected != null) ...[
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _planLine(selected),
                        style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                      ),
                      TextSpan(
                        text: '\n${t.premium.paywall.renew_line(store: store)}',
                        style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                      ),
                    ],
                  ),
                  key: const Key('premium-paywall-selected-plan'),
                  textAlign: TextAlign.center,
                ),
                CoconutLayout.spacing_200h,
              ],
              _legalLinks(context),
              CoconutLayout.spacing_200h,
              Center(
                child: CoconutUnderlinedButton(
                  key: const Key('premium-paywall-restore'),
                  text: t.premium.paywall.restore,
                  textStyle: CoconutTypography.body3_12_Bold,
                  defaultColor: colors.secondaryTextStrong,
                  padding: _linkPadding,
                  onTap: _restore,
                ),
              ),
              CoconutLayout.spacing_300h,
              InlineActionButton(
                key: const Key('premium-paywall-subscribe'),
                text: trial ? t.premium.paywall.start_trial : t.premium.paywall.subscribe,
                isActive: selected != null && !_busy && _premium.isAvailable,
                onPressed: _subscribe,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Coconut Premium · 1년 · {스토어 가격 그대로}(· N일 무료 체험: 스토어 상품에 있을 때만).
  /// 기간·가격은 줄 사이로 갈리지 않고, 줄은 "·" 뒤에서만 바뀐다(줄 앞에 점이 오지 않게)
  String _planLine(PremiumProduct product) {
    final paywall = t.premium.paywall;
    final trialDays = product.freeTrialDays;
    return [
      t.premium.name,
      _unbroken(product.config.period == PremiumPeriod.yearly ? paywall.period_year : paywall.period_month),
      _unbroken(product.price),
      if (trialDays != null) safetyKoText(paywall.trial(n: trialDays)),
    ].join(' · ');
  }

  /// 이용약관 · 개인정보 처리방침(점 없이: 줄이 바뀌어도 줄 앞뒤에 점이 남지 않는다)
  Widget _legalLinks(BuildContext context) {
    final colors = context.coconutColors;
    final style = CoconutTypography.caption_10_Bold;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        CoconutUnderlinedButton(
          key: const Key('premium-paywall-terms'),
          text: t.app_info_screen.terms_of_service,
          textStyle: style,
          defaultColor: colors.secondaryText,
          padding: _linkPadding,
          onTap: () => launchURL(context, TERMS_OF_SERVICE_URL, destination: ExternalLinkDestination.termsOfService),
        ),
        CoconutUnderlinedButton(
          key: const Key('premium-paywall-privacy'),
          text: t.app_info_screen.privacy_policy,
          textStyle: style,
          defaultColor: colors.secondaryText,
          padding: _linkPadding,
          onTap: () => launchURL(context, PRIVACY_POLICY_URL, destination: ExternalLinkDestination.privacyPolicy),
        ),
      ],
    );
  }

  /// PA1 소개
  List<Widget> _intro(BuildContext context) {
    final colors = context.coconutColors;
    return [
      const Center(child: PremiumHero()),
      CoconutLayout.spacing_500h,
      Text(
        t.premium.assist_name,
        textAlign: TextAlign.center,
        style: CoconutTypography.body3_12_Bold.setColor(colors.premiumText),
      ),
      CoconutLayout.spacing_100h,
      Semantics(
        header: true,
        child: Text(
          safetyKoText(t.premium.paywall.headline),
          textAlign: TextAlign.center,
          style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText),
        ),
      ),
      CoconutLayout.spacing_600h,
      // 이번 빌드에 있는 것만(상시 감시·푸시·도난 방지 같은 말 금지)
      _ValueRow(
        iconPath: FeatureShortcutIconPath.transactionDraft,
        title: t.premium.paywall.value_respond_title,
        body: t.premium.paywall.value_respond_body,
      ),
      CoconutLayout.spacing_300h,
      _ValueRow(
        iconPath: CommonActionIconPath.arrowReload,
        title: t.premium.rescue.name,
        body: t.premium.paywall.value_rescue_body,
      ),
      CoconutLayout.spacing_300h,
      _ValueRow(
        iconPath: FeatureShortcutIconPath.tutorial,
        title: t.premium.paywall.value_guide_title,
        body: t.premium.paywall.value_guide_body,
      ),
    ];
  }

  /// PA2 무료와 Premium
  List<Widget> _compare(BuildContext context) {
    final colors = context.coconutColors;
    final paywall = t.premium.paywall;
    return [
      _sectionTitle(context, paywall.compare_title),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            _CompareRow(
              label: '',
              // 고정 칸의 열 제목은 줄여서 한 줄로("Kostenlos"가 단어 중간에서 끊기지 않게)
              free: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  paywall.free,
                  maxLines: 1,
                  style: CoconutTypography.body3_12_Bold.setColor(colors.secondaryText),
                ),
              ),
              premium: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PremiumMark(size: 12),
                    CoconutLayout.spacing_50w,
                    Text(
                      t.premium.badge,
                      maxLines: 1,
                      style: CoconutTypography.body3_12_Bold.setColor(colors.premiumText),
                    ),
                  ],
                ),
              ),
            ),
            // Premium 칸은 늘 ✓. 무료도 직접 대응할 수 있다는 줄을 먼저 둔다
            for (final (label, free) in [
              (paywall.row_detect, true),
              (paywall.row_guide, true),
              (paywall.row_build_yourself, true),
              (paywall.row_auto_prepare, false),
              (paywall.row_rescue, false),
              (paywall.row_help, false),
            ]) ...[
              Divider(color: colors.border.withValues(alpha: 0.21), height: 1),
              _CompareRow(
                label: label,
                free: _Mark(included: free),
                premium: const _Mark(included: true, premium: true),
              ),
            ],
          ],
        ),
      ),
      CoconutLayout.spacing_300h,
      Text(safetyKoText(paywall.compare_note), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
      CoconutLayout.spacing_200h,
      // 가치 행은 모두 정적이고, 도움 채널은 결제 없이 여기서 연다(도움은 무료)
      Align(
        alignment: Alignment.centerLeft,
        child: CoconutUnderlinedButton(
          key: const Key('premium-paywall-help'),
          text: t.safety_guide.help_center.open,
          textStyle: CoconutTypography.body3_12_Bold,
          defaultColor: colors.secondaryTextStrong,
          padding: _linkPadding,
          onTap: () => showHelpChannelsSheet(context),
        ),
      ),
    ];
  }

  /// PA3 플랜·고지
  List<Widget> _plans(BuildContext context) {
    final colors = context.coconutColors;
    final products = _products;
    final android = defaultTargetPlatform == TargetPlatform.android;
    return [
      _sectionTitle(context, t.premium.paywall.plans_title),
      if (products == null)
        const _PlanSkeleton()
      else if (products.isEmpty || !_premium.isAvailable)
        SafetyStatusBanner(
          key: const Key('premium-paywall-unavailable'),
          background: colors.surface,
          iconPath: CommonStateIconPath.circleInfo,
          iconColor: colors.iconSecondary,
          title: safetyKoText(t.premium.paywall.store_unavailable),
          body: safetyKoText(t.premium.paywall.store_unavailable_body),
          linkText: t.retry,
          onLink: _load,
        )
      else
        for (final (index, product) in products.indexed) ...[
          if (index > 0) CoconutLayout.spacing_300h,
          _PlanCard(product: product, selected: product == _selected, onTap: () => setState(() => _selected = product)),
        ],
      CoconutLayout.spacing_400h,
      // 전체 고지(약관·개인정보 링크는 아래 고정 영역에 늘 보인다). 체험 문장은 고른 상품에 스토어 체험이 있을 때만.
      // 큰 글자에서도 단어 중간에서 끊기지 않게(R1, X9)
      Text(
        safetyKoText(
          [
            android ? t.premium.store_notice.google : t.premium.store_notice.apple,
            if (_selected?.freeTrialDays != null)
              android ? t.premium.store_notice.google_trial : t.premium.store_notice.apple_trial,
            t.premium.paywall.platform_note,
          ].join(' '),
        ),
        key: const Key('premium-paywall-notice'),
        style: CoconutTypography.caption_10.setColor(colors.secondaryText),
      ),
    ];
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 32, bottom: 12),
    child: Semantics(
      header: true,
      child: Text(text, style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText)),
    ),
  );
}

/// 구매 복원 + 결과 토스트(페이월·구독 관리 공통). 복원돼 Premium이 켜졌으면 true
Future<bool> restorePremiumPurchases(BuildContext context, EntitlementService premium) async {
  context.loaderOverlay.show();
  String text;
  bool restored = false;
  try {
    await premium.restore();
    restored = premium.state.value.isActive;
    text = restored ? t.premium.toast.restored : t.premium.toast.nothing_to_restore;
  } catch (_) {
    text = t.premium.toast.restore_failed;
  }
  // 화면이 사라졌으면 그 오버레이도 함께 사라졌다. loaderOverlay 도우미는 전역이라 기다리기 전에 잡아 두지 않는다
  if (!context.mounted) return restored;
  context.loaderOverlay.hide();
  CoconutToast.showToast(context: context, text: text, isVisibleIcon: true, iconPath: CommonStateIconPath.circleInfo);
  return restored;
}

/// WalletOnboardingView 항목 행과 같은 비율. 세 행 모두 같은 모양의 정적 행(도움 채널 링크는 비교표 아래)
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.iconPath, required this.title, required this.body});

  final String iconPath;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 28,
              child: Center(
                child: SvgPicture.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(colors.premiumText, BlendMode.srcIn),
                ),
              ),
            ),
            CoconutLayout.spacing_400w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(safetyKoText(title), style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
                  CoconutLayout.spacing_50h,
                  Text(safetyKoText(body), style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.label, required this.free, required this.premium});

  final String label;
  final Widget free;
  final Widget premium;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                safetyKoText(label),
                style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
              ),
            ),
            SizedBox(width: 56, child: Center(child: free)),
            SizedBox(width: 64, child: Center(child: premium)),
          ],
        ),
      ),
    );
  }
}

/// ✓(포함) 또는 –(포함 안 됨). 판매표에는 초록(Health의 "통과")을 쓰지 않는다: 무료 열 iconPrimary, Premium 열 premiumText
class _Mark extends StatelessWidget {
  const _Mark({required this.included, this.premium = false});

  final bool included;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final paywall = t.premium.paywall;
    return Semantics(
      label: included ? paywall.included_a11y : paywall.not_included_a11y,
      child: ExcludeSemantics(
        child:
            included
                ? SvgPicture.asset(
                  CommonActionIconPath.check,
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(premium ? colors.premiumText : colors.iconPrimary, BlendMode.srcIn),
                )
                : Text('–', style: CoconutTypography.body3_12.setColor(colors.iconSecondary)),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.product, required this.selected, required this.onTap});

  final PremiumProduct product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final paywall = t.premium.paywall;
    final yearly = product.config.period == PremiumPeriod.yearly;
    final trialDays = product.freeTrialDays;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ShrinkAnimationButton(
        key: Key('premium-plan-${product.config.period?.name}'),
        onPressed: () {
          vibrateExtraLight();
          onTap();
        },
        defaultColor: colors.surface,
        pressedOverlayColor: colors.surfacePressOverlay,
        pressedOverlayOpacity: colors.surfacePressOverlayOpacity,
        borderRadius: 16,
        // 고른 카드는 로고 그라데이션 링, 안 고른 카드는 같은 두께의 투명 링(고를 때 크기가 흔들리지 않게).
        // 링의 시안 끝은 밝은 바탕에서 1.9:1이라 고름은 오른쪽 체크가 알리고 링은 장식이다
        borderGradient: selected ? colors.mainnetLogoGradient : _noRing,
        borderWidth: 1.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      yearly ? paywall.period_year : paywall.period_month,
                      style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText),
                    ),
                    CoconutLayout.spacing_100h,
                    // 스토어 현지 가격 문자열 그대로(재포맷·월 환산 금지)
                    Text(product.price, style: CoconutTypography.body2_14_Number.setColor(colors.primaryText)),
                    if (trialDays != null) ...[
                      CoconutLayout.spacing_100h,
                      Text(
                        paywall.trial(n: trialDays),
                        // Premium 상품의 속성이라 premiumText(초록은 다른 곳에서 "통과"라는 뜻)
                        style: CoconutTypography.body3_12_Bold.setColor(colors.premiumText),
                      ),
                    ],
                  ],
                ),
              ),
              CoconutLayout.spacing_300w,
              // UtxoSelectionCard와 같은 고름 표시
              SvgPicture.asset(
                CommonFormIconPath.circleCheck,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(selected ? colors.borderStrong : colors.iconSecondary, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 작은 링크(법적 링크·구매 복원·도움 받기)도 누름 높이 24 이상(WCAG 2.5.8 AA). 고정 묶음은 키우지 않는다
const _linkPadding = EdgeInsets.symmetric(horizontal: 4, vertical: 5);

/// 안 고른 플랜 카드의 링(고른 카드와 같은 두께, 투명)
const _noRing = LinearGradient(colors: [Colors.transparent, Colors.transparent]);

class _PlanSkeleton extends StatelessWidget {
  const _PlanSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final bar = Container(
      height: 92,
      decoration: BoxDecoration(color: colors.surfaceSkeletonBase, borderRadius: BorderRadius.circular(16)),
    );
    return Semantics(
      label: t.premium.paywall.loading,
      child: Shimmer.fromColors(
        enabled: !safetyReduceMotion(context),
        baseColor: colors.surfaceSkeletonBase,
        highlightColor: colors.surfaceSkeletonHighlight,
        child: Column(children: [bar, CoconutLayout.spacing_300h, bar]),
      ),
    );
  }
}
