import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutTypography, TextColorExtension;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart' show openSafetyCheckAction;
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_score_gauge.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon_small.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

// ── 문구: 엔진은 enum만 돌려주고 화면이 t.wallet_health.*로 바꾼다 ──

String safetyCategoryName(SafetyCategory category) => switch (category) {
  SafetyCategory.app => t.wallet_health.category.app_protection,
  SafetyCategory.recovery => t.wallet_health.category.recovery_readiness,
  SafetyCategory.activity => t.wallet_health.category.wallet_activity,
  SafetyCategory.privacy => t.wallet_health.category.privacy,
};

/// 피그마 아이콘이 앱에 없어서 뜻이 같은 기존 아이콘을 쓴다
String safetyCategoryIconPath(SafetyCategory category) => switch (category) {
  SafetyCategory.recovery => FeatureWalletIconPath.vault,
  SafetyCategory.activity => FeatureTransactionIconPath.transaction,
  SafetyCategory.app => CommonSecurityIconPath.lock,
  SafetyCategory.privacy => CommonVisibilityIconPath.eyeCrossed,
};

/// [style] 글의 첫 줄 가운데에 [size] 아이콘·점을 두는 위 여백. 글자 배율을 따른다(POLISH R3, SafetyNumberedRow 방식)
double safetyFirstLineTop(BuildContext context, TextStyle style, double size) =>
    ((MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height! - size) / 2).clamp(0.0, double.infinity);

String safetyCheckName(SafetyCheckId id) {
  final c = t.wallet_health.check;
  return switch (id) {
    SafetyCheckId.appLock => c.app_lock.name,
    SafetyCheckId.appUpdate => c.app_update.name,
    SafetyCheckId.mnemonicBackup => c.mnemonic_backup.name,
    SafetyCheckId.passphraseVerify => c.passphrase_verify.name,
    SafetyCheckId.watchOnlyVerify => c.watch_only_verify.name,
    SafetyCheckId.multisigConfig => c.multisig_config.name,
    SafetyCheckId.bsmsBackup => c.bsms_backup.name,
    SafetyCheckId.unrecognizedOutgoing => c.unrecognized_outgoing.name,
    SafetyCheckId.txConflict => c.tx_conflict.name,
    SafetyCheckId.addressReuse => c.address_reuse.name,
    SafetyCheckId.possibleDusting => c.possible_dusting.name,
    // 지갑을 추가할 때 7일 안에 보낸 거래(대기·확정 모두, 내 거래예요 전까지)
    SafetyCheckId.pendingOutgoingAtBaseline => c.recent_at_add.name,
    SafetyCheckId.unexpectedSelfTransfer => c.self_transfer.name,
    SafetyCheckId.serverCert => c.server_cert.name,
    SafetyCheckId.metadataBackup => c.metadata_backup.name,
  };
}

/// 점수에 포함되지 않은 이유
String safetyReasonText(NotApplicableReason reason) => switch (reason) {
  NotApplicableReason.noWallet => t.wallet_health.category.reason_add_wallet,
  NotApplicableReason.noFunds => t.wallet_health.about.excluded_no_bitcoin,
  NotApplicableReason.noHistory => t.wallet_health.category.reason_onchain_activity,
  NotApplicableReason.noReceiveHistory ||
  NotApplicableReason.noUtxoHistory => t.wallet_health.category.reason_tx_history,
  NotApplicableReason.noPassphrase => t.wallet_health.about.excluded_no_passphrase,
  NotApplicableReason.noLabels => t.wallet_health.about.excluded_no_tags,
  NotApplicableReason.notCustomServer => t.wallet_health.about.excluded_not_scored,
  NotApplicableReason.updateCheckFailed => t.wallet_health.about.excluded_update_unknown,
  NotApplicableReason.notSettled => t.status_updating,
};

/// 카드의 "대기 중" 사유(피그마 WH-S0·S4)
String safetyWaitingText(SafetyCategory category, NotApplicableReason? reason) => switch (category) {
  SafetyCategory.recovery =>
    reason == NotApplicableReason.noWallet
        ? t.wallet_health.category.reason_add_wallet
        : t.wallet_health.category.reason_funds_or_usage,
  SafetyCategory.activity => t.wallet_health.category.reason_onchain_activity,
  SafetyCategory.privacy => t.wallet_health.category.reason_tx_history,
  SafetyCategory.app => t.wallet_health.category.reason_checks_available,
};

/// 인증서 지문 앞 8자리(콜론·공백 제외)
String safetyShortFingerprint(String fingerprint) {
  final hex = fingerprint.replaceAll(RegExp('[^0-9a-fA-F]'), '');
  return hex.length <= 8 ? hex : '${hex.substring(0, 8)}…';
}

/// 잔액 숨김·가짜 잔액이거나 설정을 모르면 실제 금액과 주소를 보이지 않는다(사건 카드·지갑 기여·검토 시트 공용)
bool safetyHidesAmounts(BuildContext context) {
  final preferences = context.watch<PreferenceProvider?>();
  return preferences == null || preferences.isBalanceHidden || preferences.isFakeBalanceActive;
}

/// 앱이 아는 지갑. WalletProvider가 없거나(위젯 테스트) 지워진 지갑이면 null
WalletItemBase? safetyWalletOf(BuildContext context, int? walletId) =>
    walletId == null ? null : context.read<WalletProvider?>()?.walletItemList.firstWhereOrNull((w) => w.id == walletId);

String safetyWalletKindText(WalletItemBase wallet) {
  if (wallet.hasLocalKey) return t.wallet_home_screen.wallet_filter.hot;
  return switch (wallet.walletType) {
    WalletType.multiSignature => t.wallet_stack_list.multisig,
    WalletType.taproot => t.wallet_stack_list.inheritance,
    _ => t.wallet_home_screen.wallet_filter.watch_only,
  };
}

/// "Daily · 핫월렛". 모르는 지갑이면 null
String? safetyWalletLine(BuildContext context, int? walletId) {
  final wallet = safetyWalletOf(context, walletId);
  return wallet == null ? null : '${wallet.name} · ${safetyWalletKindText(wallet)}';
}

Widget safetyWalletIcon(WalletItemBase wallet) => WalletIconSmall(
  walletImportSource: wallet.walletImportSource,
  colorIndex: wallet.colorIndex,
  iconIndex: wallet.iconIndex,
  isHotWallet: wallet.hasLocalKey,
  gradientColors:
      wallet is MultisigWalletItem
          ? WalletVisualStyleUtil.getGradientColors(wallet.signers)
          : TaprootCardStyle.from(wallet)?.iconGradientColors,
);

/// 검토 필요 행·🔔·카테고리 시트의 문제 문구. 세부 상태는 엔진이 [SafetyCheckResult.detail]·count로 준다
String safetyIssueText(SafetyCheckResult item) {
  final c = t.wallet_health.check;
  final critical = item.severity == SafetySeverity.critical;
  final detail = item.detail;
  final count = item.count ?? 0;
  return switch (item.id) {
    SafetyCheckId.appLock => c.app_lock.issue,
    SafetyCheckId.appUpdate => c.app_update.issue,
    SafetyCheckId.mnemonicBackup => c.mnemonic_backup.issue,
    SafetyCheckId.passphraseVerify => c.passphrase_verify.issue,
    SafetyCheckId.watchOnlyVerify when critical => t.wallet_health.incident.watch_only_mismatch_title,
    SafetyCheckId.watchOnlyVerify =>
      detail == SafetyCheckDetail.mismatch
          ? c.watch_only_verify.issue_mismatch
          : c.watch_only_verify.issue_not_verified,
    SafetyCheckId.multisigConfig when critical => t.wallet_health.incident.multisig_mismatch_title,
    SafetyCheckId.multisigConfig =>
      detail == SafetyCheckDetail.mismatch ? c.multisig_config.issue_mismatch : c.multisig_config.issue_incomplete,
    SafetyCheckId.bsmsBackup => switch (detail) {
      SafetyCheckDetail.updateRequired => c.bsms_backup.issue_update_required,
      SafetyCheckDetail.mismatch => c.bsms_backup.issue_mismatch,
      _ => c.bsms_backup.issue_not_verified,
    },
    SafetyCheckId.unrecognizedOutgoing => t.wallet_health.incident.outgoing_title,
    SafetyCheckId.txConflict => c.tx_conflict.issue,
    SafetyCheckId.addressReuse => t.wallet_health.category.addresses_reused(n: item.subjects.length),
    SafetyCheckId.possibleDusting => t.wallet_health.category.possible_dusting(n: item.subjects.length),
    SafetyCheckId.pendingOutgoingAtBaseline => c.recent_at_add.issue,
    SafetyCheckId.unexpectedSelfTransfer => c.self_transfer.issue,
    SafetyCheckId.serverCert => switch (detail) {
      SafetyCheckDetail.expired => t.wallet_health.review.server_cert.expired_title,
      SafetyCheckDetail.expiresSoon => t.wallet_health.review.server_cert.expiring_title,
      _ => t.wallet_health.incident.server_identity_title,
    },
    SafetyCheckId.metadataBackup =>
      detail == SafetyCheckDetail.changed ? c.metadata_backup.changed(n: count) : c.metadata_backup.never_exported,
  };
}

/// 실패한 점검의 짧은 결과(카테고리·지갑 시트 행 오른쪽, UI_SPEC §5.2)
String safetyFailedResultText(SafetyCheckResult item) {
  final c = t.wallet_health.check;
  final detail = item.detail;
  final count = item.count ?? 0;
  return switch (item.id) {
    SafetyCheckId.appLock => c.app_lock.disabled,
    SafetyCheckId.appUpdate => c.app_update.available,
    SafetyCheckId.mnemonicBackup => c.mnemonic_backup.needed,
    SafetyCheckId.passphraseVerify => c.passphrase_verify.not_verified,
    SafetyCheckId.watchOnlyVerify =>
      detail == SafetyCheckDetail.mismatch ? c.watch_only_verify.mismatch : c.watch_only_verify.not_verified,
    SafetyCheckId.multisigConfig =>
      detail == SafetyCheckDetail.mismatch ? c.multisig_config.mismatch : c.multisig_config.incomplete,
    SafetyCheckId.bsmsBackup => switch (detail) {
      SafetyCheckDetail.updateRequired => c.bsms_backup.update_required,
      SafetyCheckDetail.mismatch => c.bsms_backup.mismatch,
      _ => c.bsms_backup.not_verified,
    },
    SafetyCheckId.addressReuse => c.address_reuse.count(n: item.subjects.length),
    SafetyCheckId.possibleDusting => c.possible_dusting.count(n: item.subjects.length),
    SafetyCheckId.txConflict => t.wallet_health.category.replaced_incoming(n: item.subjects.length),
    SafetyCheckId.serverCert => switch (detail) {
      SafetyCheckDetail.expired => c.server_cert.expired_ago(n: count < 1 ? 1 : count),
      SafetyCheckDetail.expiresSoon => count == 0 ? c.server_cert.expires_today : c.server_cert.expires_in(n: count),
      _ => c.server_cert.changed,
    },
    SafetyCheckId.metadataBackup =>
      detail == SafetyCheckDetail.changed ? c.metadata_backup.changed(n: count) : c.metadata_backup.never_exported,
    SafetyCheckId.unrecognizedOutgoing ||
    SafetyCheckId.pendingOutgoingAtBaseline ||
    SafetyCheckId.unexpectedSelfTransfer => safetyIssueText(item),
  };
}

/// 통과 체크 아이콘의 의미 라벨: 코코넛이 확인함 / 직접 확인함(색만으로 구분하지 않게)
String safetyEvidenceA11y({required bool byUser}) =>
    byUser ? t.wallet_health.evidence.completed_by_you_a11y : t.wallet_health.evidence.verified_a11y;

/// 행 끝 알약 문구
String safetyCtaText(SafetyCheckResult item) {
  final cta = t.wallet_health.cta;
  return switch (item.id) {
    SafetyCheckId.appLock => cta.set_up,
    SafetyCheckId.mnemonicBackup => cta.back_up,
    SafetyCheckId.watchOnlyVerify when item.detail == SafetyCheckDetail.mismatch => cta.rescan,
    SafetyCheckId.passphraseVerify || SafetyCheckId.watchOnlyVerify || SafetyCheckId.bsmsBackup => cta.verify,
    SafetyCheckId.appUpdate => cta.update,
    SafetyCheckId.metadataBackup => cta.export_backup,
    _ => cta.review,
  };
}

/// 통과한 점검의 결과 문구. 사용자가 직접 확인한 항목은 "검증됨"과 구분한다
({String text, bool byUser}) safetyPassedText(SafetyCheckResult item) {
  final c = t.wallet_health.check;
  final evidence = t.wallet_health.evidence;
  if (item.evidence == SafetyEvidence.userConfirmed) return (text: evidence.completed_by_you, byUser: true);
  final text = switch (item.id) {
    SafetyCheckId.appLock => c.app_lock.enabled,
    SafetyCheckId.appUpdate => c.app_update.up_to_date,
    SafetyCheckId.mnemonicBackup => c.mnemonic_backup.confirmed,
    SafetyCheckId.passphraseVerify || SafetyCheckId.watchOnlyVerify || SafetyCheckId.bsmsBackup => evidence.verified,
    SafetyCheckId.multisigConfig => c.multisig_config.complete,
    SafetyCheckId.serverCert => c.server_cert.valid,
    SafetyCheckId.metadataBackup => c.metadata_backup.up_to_date,
    SafetyCheckId.unrecognizedOutgoing ||
    SafetyCheckId.txConflict ||
    SafetyCheckId.addressReuse ||
    SafetyCheckId.possibleDusting ||
    SafetyCheckId.pendingOutgoingAtBaseline ||
    SafetyCheckId.unexpectedSelfTransfer => c.none_found,
  };
  return (text: text, byUser: false);
}

/// 권장 점검 이름. 점검 결과(메모 백업·인증서 만료 임박)면 그 점검 이름
String safetyRecommendedName(BuildContext context, RecommendedItem item) {
  final r = t.wallet_health.recommended;
  final check = item.check;
  if (check != null) return safetyCheckName(check.id);
  return switch (item.id) {
    RecommendedCheckId.hotPhysicalBackup => r.mnemonic_stored,
    // 핫월렛 보관과 다중 서명 분리 보관은 다른 점검이라 제목도 따로(같은 지갑 집합에서 같은 줄이 두 번 나오지 않게)
    RecommendedCheckId.hotSafeStorage => r.safe_storage,
    RecommendedCheckId.multisigBackupSeparation => r.recovery_separate,
    RecommendedCheckId.hotPassphraseOffline => r.passphrase_recoverable,
    RecommendedCheckId.multisigQuorumAccess => r.signer_access(
      // 여러 다중 서명 지갑이면 가장 많이 필요한 서명 수
      quorum:
          context
              .read<WalletProvider?>()
              ?.walletItemList
              .whereType<MultisigWalletItem>()
              .map((w) => w.requiredSignatureCount)
              .maxOrNull ??
          2,
    ),
    RecommendedCheckId.metadataStoredOffsite => r.metadata_stored,
    null => '',
  };
}

/// 카테고리 카드·시트의 상태 줄. 가장 큰 감점 원인을 직접 보여 준다
({String text, Color color}) safetyCategoryStatus(
  BuildContext context,
  WalletHealthReport report,
  SafetyCategory category,
) {
  final colors = context.coconutColors;
  final c = t.wallet_health.category;
  final summary = t.wallet_health.summary;
  final score = report.categories[category];
  if (report.status == WalletHealthStatus.noWallet && category == SafetyCategory.app) {
    return (text: c.reason_checks_available, color: colors.success);
  }
  if (score?.score == null) {
    return (text: safetyWaitingText(category, score?.waitingReason), color: colors.secondaryText);
  }
  final issues = score!.issueCount;
  if (issues == 0) return (text: summary.no_issues_found, color: colors.success);
  final items = report.reviewItems.where((r) => r.id.category == category);
  int subjects(SafetyCheckId id) => items.where((r) => r.id == id).fold(0, (sum, r) => sum + r.subjects.length);
  final reused = subjects(SafetyCheckId.addressReuse);
  final dust = subjects(SafetyCheckId.possibleDusting);
  final conflicts = subjects(SafetyCheckId.txConflict);
  final wallets = {for (final r in items) r.walletId}.nonNulls.length;
  final text = switch (category) {
    SafetyCategory.privacy when reused > 0 => c.addresses_reused(n: reused),
    SafetyCategory.privacy when dust > 0 => c.possible_dusting(n: dust),
    SafetyCategory.activity when conflicts > 0 => c.replaced_incoming(n: conflicts),
    SafetyCategory.recovery when wallets > 1 => summary.wallets_need_attention(n: wallets),
    _ => summary.items_need_attention(n: issues),
  };
  return (text: text, color: colors.warningText);
}

// ── 위젯 ──

/// 목록 카드 안 한 행. 누르면 행 바탕만 눌림 색으로(줄어들지 않음)
class SafetyPressRow extends StatelessWidget {
  const SafetyPressRow({super.key, required this.background, required this.onTap, required this.child});

  final Color background;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      onPressed: onTap,
      defaultColor: background,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 0,
      animationEndValue: 1,
      child: child,
    );
  }
}

/// 머리 카드: 게이지 · 다시 검사(지갑 없음이면 지갑 추가) · 마지막 검사 · 점검 지갑 수 · 오프라인
class WalletHealthHeaderCard extends StatelessWidget {
  const WalletHealthHeaderCard({
    super.key,
    required this.report,
    required this.isChecking,
    required this.onCheckAgain,
    required this.onAddWallet,
  });

  final WalletHealthReport? report;
  final bool isChecking;
  final VoidCallback onCheckAgain;
  final VoidCallback onAddWallet;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final report = this.report;
    final noWallet = report?.status == WalletHealthStatus.noWallet;
    final hero = t.wallet_health.hero;
    final lineStyle = CoconutTypography.body3_12.setColor(colors.secondaryText);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          HealthGauge(report: report, isChecking: isChecking),
          CoconutLayout.spacing_200h,
          noWallet
              ? _AddWalletButton(onTap: onAddWallet)
              : _CheckAgainButton(isChecking: isChecking, onTap: onCheckAgain),
          if (report != null) ...[
            CoconutLayout.spacing_200h,
            Text(
              t.wallet_health.summary.last_checked(time: formatHomeRelativeTime(report.evaluatedAt, DateTime.now())),
              textAlign: TextAlign.center,
              style: lineStyle,
            ),
            if (!noWallet) ...[
              CoconutLayout.spacing_100h,
              Text(
                [
                  hero.wallets_checked(n: report.walletCount),
                  if (report.fundedWalletCount > 0) hero.funded_wallets(n: report.fundedWalletCount),
                ].join(' · '),
                textAlign: TextAlign.center,
                style: lineStyle,
              ),
            ],
            // 점수를 제한하는 정보라 점수 바로 밑에 둔다
            if (!report.isConnected) ...[
              CoconutLayout.spacing_200h,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    FeatureConnectivityIconPath.cloudDisconnected,
                    width: 14,
                    height: 14,
                    colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                  ),
                  CoconutLayout.spacing_100w,
                  Flexible(child: Text(t.wallet_health.hero.offline_line, style: lineStyle)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// 카드 안에서 한 단계 들어간 회색 알약
class _CheckAgainButton extends StatelessWidget {
  const _CheckAgainButton({required this.isChecking, required this.onTap});

  final bool isChecking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      key: const Key('wallet-health-check-again'),
      onPressed: onTap,
      isActive: !isChecking,
      defaultColor: colors.homeBackground,
      // 기본 disabledColor(surface)는 다크에서 homeSurface와 같아 버튼이 사라진다
      disabledColor: colors.homeBackground,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44), // 누르는 높이 44(POLISH R7)
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isChecking) ...[
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.secondaryText,
                    value: safetyReduceMotion(context) ? 0.25 : null,
                  ),
                ),
                CoconutLayout.spacing_200w,
              ],
              Flexible(
                child: Text(
                  isChecking ? t.wallet_health.summary.checking : t.wallet_health.summary.check_again,
                  textAlign: TextAlign.center,
                  style: CoconutTypography.body3_12_Bold.setColor(colors.primaryText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 지갑이 없을 때의 주 버튼
class _AddWalletButton extends StatelessWidget {
  const _AddWalletButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      key: const Key('wallet-health-add-wallet'),
      onPressed: onTap,
      defaultColor: colors.buttonPrimaryBackground,
      pressedOverlayColor: colors.buttonPrimaryPressOverlay,
      pressedOverlayOpacity: colors.buttonPrimaryPressOverlayOpacity,
      borderRadius: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44), // 누르는 높이 44(POLISH R7)
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.add, size: 16, color: colors.buttonPrimaryForeground),
              CoconutLayout.spacing_100w,
              Flexible(
                child: Text(
                  t.home_widgets.add_wallet,
                  style: CoconutTypography.body2_14_Bold.setColor(colors.buttonPrimaryForeground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카테고리 카드 2×2(복구 준비 · 지갑 활동 / 앱 보호 · 개인정보 보호)
class WalletHealthCategoryGrid extends StatelessWidget {
  const WalletHealthCategoryGrid({super.key, required this.report, required this.isChecking, required this.onTap});

  final WalletHealthReport? report;
  final bool isChecking;
  final ValueChanged<SafetyCategory> onTap;

  @override
  Widget build(BuildContext context) {
    Widget card(SafetyCategory category) =>
        Expanded(child: _CategoryCard(category: category, report: report, isChecking: isChecking, onTap: onTap));
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [card(SafetyCategory.recovery), CoconutLayout.spacing_300w, card(SafetyCategory.activity)],
          ),
        ),
        CoconutLayout.spacing_300h,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [card(SafetyCategory.app), CoconutLayout.spacing_300w, card(SafetyCategory.privacy)],
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.report, required this.isChecking, required this.onTap});

  final SafetyCategory category;
  final WalletHealthReport? report;
  final bool isChecking;
  final ValueChanged<SafetyCategory> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final report = this.report;
    final name = safetyCategoryName(category);
    Widget? result;
    var semantics = '$name, ${t.wallet_health.summary.checking}';
    if (report != null) {
      final score = report.categories[category]?.score;
      final status = safetyCategoryStatus(context, report, category);
      // 지갑 0개의 앱 보호는 숫자 대신 "사용 가능"(SPEC NW)
      final available = report.status == WalletHealthStatus.noWallet && category == SafetyCategory.app;
      final bigText =
          available
              ? t.wallet_health.category.available
              : score == null
              ? t.wallet_health.category.waiting
              : '$score';
      // 한 줄 이름·숫자는 줄여 맞춘다(POLISH R2): 좁은 카드에서 단어 중간에 줄이 바뀌지 않게
      final big = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          bigText,
          style:
              available
                  ? CoconutTypography.heading3_21_Bold.setColor(colors.primaryText)
                  : score == null
                  ? CoconutTypography.heading3_21_Bold.setColor(colors.secondaryText)
                  : CoconutTypography.heading3_21_NumberBold.setColor(colors.primaryText),
        ),
      );
      result = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HomeWidgetHeader와 같은 모양
          Row(
            children: [
              SvgPicture.asset(
                safetyCategoryIconPath(category),
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
              ),
              CoconutLayout.spacing_150w,
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(name, style: CoconutTypography.body3_12_Bold.setColor(colors.primaryText)),
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_200h,
          big,
          CoconutLayout.spacing_50h,
          Text(
            status.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CoconutTypography.body3_12.setColor(status.color),
          ),
        ],
      );
      if (!isChecking) {
        semantics =
            score == null || available
                ? '$name, $bigText, ${status.text}'
                : t.wallet_health.category.a11y(name: name, score: score, status: status.text);
      }
    }
    // 다시 검사하는 동안 결과가 있으면 그 틀을 유지한다(카드 높이가 튀지 않게)
    final content =
        result == null
            ? const _CardSkeleton()
            : !isChecking
            ? result
            : Stack(
              children: [
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: result,
                ),
                const Positioned.fill(child: _CardSkeleton()),
              ],
            );
    return ShrinkAnimationButton(
      key: Key('wallet-health-category-${category.name}'),
      onPressed: () => onTap(category),
      defaultColor: colors.homeSurface,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 20,
      child: Semantics(
        label: semantics,
        child: ExcludeSemantics(child: Padding(padding: const EdgeInsets.all(16), child: content)),
      ),
    );
  }
}

/// 검사 중 카드 내용(HomeWidgetSkeleton과 같은 막대·반짝임)
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      // surfaceSkeletonBase는 homeSurface와 같아(어두움·코코넛 1.00) 동작 줄이기에서 안 보인다(POLISH R6)
      child: Container(
        height: height,
        decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(4)),
      ),
    );
    final bars = Column(
      key: const Key('wallet-health-card-skeleton'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [bar(0.7, 12), CoconutLayout.spacing_300h, bar(0.4, 20), CoconutLayout.spacing_200h, bar(0.6, 10)],
    );
    if (safetyReduceMotion(context)) return bars;
    return Shimmer.fromColors(
      baseColor: colors.surfaceMuted,
      highlightColor: colors.surfaceSkeletonHighlight,
      child: bars,
    );
  }
}

/// 검토 필요 행(Wallet Health "검토 필요"·🔔 "확인할 항목" 공용): ⚠ + 지갑 + 문제 + 알약.
/// 알약만 따로 누르지 않고 행 전체가 그 점검의 동작을 한다(점검 → 문구·알약·동작 매핑을 이 위젯 하나에 둔다)
class SafetyReviewRow extends StatelessWidget {
  const SafetyReviewRow({super.key, required this.check, this.onTap});

  final SafetyCheckResult check;

  /// 기본은 점검별 동작([openSafetyCheckAction])
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = safetyWalletLine(context, check.walletId);
    return SafetyPressRow(
      key: Key('wallet-health-review-${check.key}'),
      background: colors.homeSurface,
      onTap: onTap ?? () => openSafetyCheckAction(context, check),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            SvgPicture.asset(
              CommonStateIconPath.triangleWarning,
              width: 16,
              colorFilter: ColorFilter.mode(colors.warningText, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_300w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wallet != null) Text(wallet, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                  Text(safetyIssueText(check), style: CoconutTypography.body2_14.setColor(colors.primaryText)),
                ],
              ),
            ),
            CoconutLayout.spacing_200w,
            SafetyActionPill(text: safetyCtaText(check)),
          ],
        ),
      ),
    );
  }
}

/// 정상 항목 행(누르지 않음). 직접 확인한 항목은 초록 대신 회색
class SafetyPassedRow extends StatelessWidget {
  const SafetyPassedRow({super.key, required this.item});

  final SafetyCheckResult item;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final result = safetyPassedText(item);
    final color = result.byUser ? colors.secondaryText : colors.success;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SvgPicture.asset(
            CommonFormIconPath.circleCheck,
            width: 18,
            height: 18,
            semanticsLabel: safetyEvidenceA11y(byUser: result.byUser),
            colorFilter: ColorFilter.mode(result.byUser ? colors.iconSecondary : colors.success, BlendMode.srcIn),
          ),
          CoconutLayout.spacing_300w,
          Expanded(
            child: Text(safetyCheckName(item.id), style: CoconutTypography.body2_14.setColor(colors.primaryText)),
          ),
          CoconutLayout.spacing_200w,
          // 값은 오른쪽 끝(느슨한 Flexible이면 줄 가운데에 멈춘다)
          Expanded(
            child: Text(result.text, textAlign: TextAlign.end, style: CoconutTypography.body3_12.setColor(color)),
          ),
        ],
      ),
    );
  }
}

/// 아직 포함되지 않은 점검(🕒) + 회색 띠
class WalletHealthNotIncludedCard extends StatelessWidget {
  const WalletHealthNotIncludedCard({super.key, required this.items, required this.footer, this.showReasons = true});

  final List<SafetyCheckResult> items;
  final String footer;
  final bool showReasons;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final style = CoconutTypography.body3_12.setColor(colors.secondaryText);
    return SafetyListCard(
      rows: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(CupertinoIcons.clock, size: 18, color: colors.iconSecondary),
                CoconutLayout.spacing_300w,
                Expanded(
                  child: Text(
                    safetyCheckName(item.id),
                    style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                  ),
                ),
                if (showReasons && item.reason != null) ...[
                  CoconutLayout.spacing_200w,
                  Flexible(child: Text(safetyReasonText(item.reason!), textAlign: TextAlign.end, style: style)),
                ],
              ],
            ),
          ),
        Container(
          width: double.infinity,
          color: colors.surfaceMuted,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          // 꼭 읽어야 하는 띠 글: 코코넛 secondaryText는 이 바탕에서 2.65:1(POLISH R5)
          child: Text(footer, style: CoconutTypography.body3_12.setColor(colors.secondaryTextStrong)),
        ),
      ],
    );
  }
}

/// 지갑 0개(S0)에서 Premium 카드 대신 보이는 안내. 할 일 목록이라 완료 체크가 아니라 중립 동그라미를 쓴다
class WalletHealthUnlockCard extends StatelessWidget {
  const WalletHealthUnlockCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final s = t.wallet_health.section;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                CommonStateIconPath.bulb,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
              ),
              CoconutLayout.spacing_200w,
              Expanded(child: Text(s.unlock_more, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText))),
            ],
          ),
          CoconutLayout.spacing_300h,
          for (final (i, text) in [s.unlock_add_wallet, s.unlock_verify_watch_only, s.unlock_use_bitcoin].indexed) ...[
            if (i > 0) CoconutLayout.spacing_150h,
            _CheckLine(text: text, color: colors.iconSecondary, iconPath: CommonFormIconPath.circle),
          ],
        ],
      ),
    );
  }
}

/// 아이콘 + 한 줄. Premium 혜택 목록은 체크, 지갑 0개 안내는 중립 동그라미
class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.text,
    required this.color,
    this.iconPath = CommonActionIconPath.check,
    this.textColor,
  });

  final String text;
  final Color color;
  final String iconPath;

  /// 없으면 primaryText(Premium 바탕 위 보조 글은 secondaryTextStrong)
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: safetyFirstLineTop(context, CoconutTypography.body3_12, 14)),
          child: SvgPicture.asset(
            iconPath,
            width: 14,
            height: 14,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
        CoconutLayout.spacing_200w,
        Expanded(
          child: Text(text, style: CoconutTypography.body3_12.setColor(textColor ?? context.coconutColors.primaryText)),
        ),
      ],
    );
  }
}

/// Free Premium 카드. 위급(WH-S3)에서는 "비트코인을 보호하세요" 변형으로, 무료 대응 버튼 아래에만 둔다
class WalletHealthPremiumCard extends StatelessWidget {
  const WalletHealthPremiumCard({super.key, required this.onTap, this.critical = false});

  final VoidCallback onTap;
  final bool critical;

  /// Free 판매 카드(POLISH §2.4): 카드 전체가 버튼 하나(의미 라벨도 하나). 평소에는 1px 로고 링, 위급(S3)은 링 없이
  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final card = t.premium.card;
    final secondary = CoconutTypography.body3_12.setColor(colors.secondaryTextStrong);
    return PremiumSurface(
      key: const Key('wallet-health-premium-card'),
      radius: 20,
      ringWidth: critical ? 0 : 1,
      padding: const EdgeInsets.all(20),
      onPressed: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 칩은 없다(Premium 바탕 위에서는 묻히고 젬이 두 번 나온다)
          Row(
            children: [
              const PremiumMark(size: 20),
              CoconutLayout.spacing_200w,
              Expanded(
                child: Text(
                  critical ? card.critical_title : card.title,
                  style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText),
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_300h,
          if (critical) Text(card.critical_body, style: secondary),
          if (!critical) ...[
            for (final (i, text) in [card.point_prepare, card.point_rescue, card.point_guide].indexed) ...[
              if (i > 0) CoconutLayout.spacing_150h,
              _CheckLine(text: text, color: colors.premiumText, textColor: colors.secondaryTextStrong),
            ],
          ],
          CoconutLayout.spacing_300h,
          // 오른쪽 아래 꼬리표: 안쪽 버튼 대신(카드 전체가 버튼)
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(card.explore, style: CoconutTypography.body3_12_Bold.setColor(colors.primaryText)),
                CoconutLayout.spacing_100w,
                SvgPicture.asset(
                  CommonNavigationIconPath.arrowRight,
                  width: 6,
                  height: 10,
                  colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
