import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutPopup, CoconutToast;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

bool _isCaution(BuildContext context, int walletId) =>
    context.select<SafetyProvider?, bool>((provider) => provider?.isCaution(walletId) ?? false);

/// 지갑 상세 "사용 주의" 배너. 해제하면 접힌다. SafetyProvider가 없거나 사용 주의가 아니면 아무것도 그리지 않는다
class SafetyCautionBanner extends StatelessWidget {
  const SafetyCautionBanner({super.key, required this.walletId});

  final int walletId;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final strings = t.safety_guide.caution;
    final duration = safetyReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 300);
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder:
          (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, axisAlignment: -1, child: child),
          ),
      child:
          _isCaution(context, walletId)
              ? Padding(
                key: const Key('safety-caution-banner'),
                padding: const EdgeInsets.only(bottom: 20),
                child: SafetyStatusBanner(
                  background: colors.dangerSurface,
                  iconPath: CommonStateIconPath.triangleWarning,
                  iconColor: colors.danger,
                  title: strings.badge,
                  body: strings.banner_body,
                  linkText: strings.remove_link,
                  onLink: () => _confirmRemove(context),
                ),
              )
              : const SizedBox(width: double.infinity),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final strings = t.safety_guide.caution;
    final removed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            languageCode: LocaleSettings.currentLocale.languageCode,
            title: strings.remove_title,
            description: strings.remove_body,
            leftButtonText: t.cancel,
            rightButtonText: strings.remove_confirm,
            rightButtonColor: context.coconutColors.primaryText,
            onTapLeft: () => Navigator.pop(dialogContext, false),
            onTapRight: () => Navigator.pop(dialogContext, true),
          ),
    );
    if (removed != true || !context.mounted) return;
    final provider = context.read<SafetyProvider?>();
    if (provider == null) return;
    await provider.setCaution(walletId, false);
    if (!context.mounted) return;
    CoconutToast.showToast(
      context: context,
      text: strings.removed_toast,
      isVisibleIcon: true,
      iconPath: CommonStateIconPath.circleInfo,
    );
  }
}

/// "사용 주의" 배지(WalletTypeBadge와 같은 크기). 사용 주의가 아니면 그리지 않는다
class SafetyCautionBadge extends StatelessWidget {
  const SafetyCautionBadge({
    super.key,
    required this.walletId,
    this.compact = false,
    this.maxWidth = double.infinity,
    this.leadingGap = 0,
    this.margin = EdgeInsets.zero,
  });

  final int walletId;

  /// 작은(2×2) 홈 지갑 카드: 글자 없이 20 원 아이콘(뜻은 Semantics로)
  final bool compact;

  /// 이 폭을 넘으면 한 줄 그대로 줄여 맞춘다(WalletCard 머리 줄은 배지에 폭 제한을 주지 않는다)
  final double maxWidth;

  /// 배지 앞 간격(예: 넓은 WalletCard 머리 줄에서 8). 사용 주의가 아니면 간격도 없다
  final double leadingGap;

  /// 사용 주의일 때만 두는 바깥 간격(아니면 자리도 차지하지 않는다)
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    if (!_isCaution(context, walletId)) return const SizedBox.shrink();
    final colors = context.coconutColors;
    Widget icon(double size) => SvgPicture.asset(
      CommonStateIconPath.triangleWarning,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(colors.danger, BlendMode.srcIn),
    );
    final badge =
        compact
            ? Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.dangerSurface, borderRadius: BorderRadius.circular(10)),
              child: icon(12),
            )
            // WalletTypeBadge와 같은 모양: 14 아이콘 상자 + 4 + 글자
            : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: colors.dangerSurface, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 14, height: 14, child: Center(child: icon(10))),
                      CoconutLayout.spacing_100w,
                      Text(
                        t.safety_guide.caution.badge,
                        style: CoconutTypography.caption_10_Bold.setColor(colors.dangerText),
                      ),
                    ],
                  ),
                ),
              ),
            );
    return Padding(
      padding: margin.add(EdgeInsets.only(left: leadingGap)),
      child: Semantics(label: t.safety_guide.caution.badge_a11y, child: ExcludeSemantics(child: badge)),
    );
  }
}

/// WalletCard 머리 줄에서 배지가 차지할 수 있는 가장 넓은 폭(이름 열이 남는다)
const kSafetyCautionSlotMaxWidth = 120.0;

/// `WalletCard.statusBadge` 슬롯용(아닐 때는 null). [compact]면 2×2 카드용 아이콘 원, 아니면 글자 배지를
/// [kSafetyCautionSlotMaxWidth] 안에서 줄여 맞춘다. [leadingGap]은 넓은 카드 머리 줄의 배지 앞 간격(작은 카드는 카드가 둔다).
/// 빌더 콜백 안에서 바깥 State의 context로 불려도 되게 select 대신 watch를 쓴다
Widget? safetyCautionBadgeFor(BuildContext context, int walletId, {bool compact = false, double leadingGap = 0}) =>
    context.watch<SafetyProvider?>()?.isCaution(walletId) == true
        ? SafetyCautionBadge(
          walletId: walletId,
          compact: compact,
          maxWidth: kSafetyCautionSlotMaxWidth,
          leadingGap: leadingGap,
        )
        : null;
