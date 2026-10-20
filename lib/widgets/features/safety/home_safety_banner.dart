import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/analytics/backup_analytics.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_security_warning_policy.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/safety/incident_sheets.dart';
import 'package:coconut_wallet/screens/safety/safety_alerts_screen.dart';
import 'package:coconut_wallet/screens/safety/security_guide_screen.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart' show openSafetyCheckAction;
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart' show kEntryPointWalletHome;
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/card/home_alert_card.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_score_gauge.dart' show safetyCriticalTitle;
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 위급 상태 한 줄 요약과 누르면 갈 곳. 홈 배너와 Safety Status 위젯(W3)이 같이 쓴다.
typedef SafetyCriticalAlert = ({String key, String title, String body, Future<void> Function(BuildContext) open});

/// 위급이 아니면 null. 사건 하나 → 사건 상세(대응 중이면 가이드 이어서), 여럿 → 🔔 목록.
/// 사건 밖 위급은 엔진 순서(보기 전용 불일치 > 다중서명 불일치 > 서버 신원)의 첫 항목 하나: 서버 신원 → 일렉트럼 서버 설정,
/// 그 밖은 Wallet Health 검토 행과 같은 동작(보기 전용 검증, 지갑 정보 구성).
SafetyCriticalAlert? safetyCriticalAlertOf(WalletHealthReport? report, String Function(int walletId) walletName) {
  if (report == null || !report.isCritical) return null;
  final title = safetyCriticalTitle(report);
  final incidents = report.criticalIncidents;
  if (incidents.length > 1) {
    return (
      key: 'incidents',
      title: title,
      body: t.wallet_health.incident.outgoing_multiple_body,
      open: SafetyAlertsScreen.open,
    );
  }
  if (incidents.length == 1) {
    final incident = incidents.single;
    return (
      key: incident.id,
      title: title,
      // 「。」 뒤 띄어쓰기가 언어마다 달라 탭 안내는 줄을 바꿔 붙인다
      body:
          '${t.wallet_health.incident.outgoing_body(wallet: walletName(incident.walletId))}\n'
          '${t.wallet_health.incident.tap_to_review}',
      open:
          (context) =>
              incident.state == IncidentState.responding
                  ? SecurityGuide.resume(context, incident.id)
                  : openSafetyIncident(context, walletId: incident.walletId, txid: incident.txid),
    );
  }
  final check = report.reviewItems.where((item) => item.severity == SafetySeverity.critical).firstOrNull;
  final wallet = check?.walletId == null ? '' : walletName(check!.walletId!);
  final body = switch (check?.id) {
    SafetyCheckId.serverCert => t.wallet_health.incident.server_identity_body,
    SafetyCheckId.watchOnlyVerify => t.wallet_health.incident.watch_only_mismatch_body(wallet: wallet),
    SafetyCheckId.multisigConfig => t.wallet_health.incident.multisig_mismatch_body(wallet: wallet),
    _ => t.wallet_health.critical.title,
  };
  return (
    key: check?.key ?? 'critical',
    title: title,
    body: body,
    open: switch (check) {
      SafetyCheckResult(id: SafetyCheckId.serverCert) =>
        (context) => Navigator.pushNamed<void>(context, AppRouteNames.electrumServer),
      final check? => (context) => openSafetyCheckAction(context, check),
      null => WalletHealthScreen.open,
    },
  );
}

String Function(int walletId) walletNameLookup(List<WalletItemBase> wallets) =>
    (id) => wallets.where((wallet) => wallet.id == id).firstOrNull?.name ?? '';

/// 홈 그리드 위 시스템 배너 하나. 위급 사건 > 백업 안 된 잔액 핫월렛 > 앱 잠금 꺼짐(구 홈과 같은 순서).
/// 위급은 닫을 수 없고, 백업·앱 잠금은 구 홈·지갑 상세와 같은 7일 숨김을 쓴다. 정렬 중에는 그리지 않는다.
class HomeSafetyBanner extends StatefulWidget {
  const HomeSafetyBanner({super.key, this.isArranging = false});

  final bool isArranging;

  @override
  State<HomeSafetyBanner> createState() => _HomeSafetyBannerState();
}

class _HomeSafetyBannerState extends State<HomeSafetyBanner> {
  /// 백업 경고를 닫은 뒤 앱 잠금 경고를 이어 보일 때
  static const _nextWarningDelay = Duration(milliseconds: 200);
  static const _warningDelay = Duration(seconds: 2);

  late final _policy = HomeSecurityWarningPolicy();

  Widget _icon(String path, Color color) =>
      SvgPicture.asset(path, width: 20, height: 20, colorFilter: ColorFilter.mode(color, BlendMode.srcIn));

  @override
  Widget build(BuildContext context) {
    final safety = context.watch<SafetyProvider?>();
    if (safety == null || widget.isArranging) return const SizedBox.shrink();
    final walletProvider = context.watch<WalletProvider?>();
    final wallets = walletProvider?.walletItemList ?? const <WalletItemBase>[];
    final colors = context.coconutColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);

    final critical = safetyCriticalAlertOf(safety.report, walletNameLookup(wallets));
    if (critical != null) {
      void open() => critical.open(context);
      return Semantics(
        container: true,
        button: true,
        label: '${t.wallet_health.incident.alert_a11y(title: critical.title)}\n${critical.body}',
        onTap: open,
        excludeSemantics: true,
        child: HomeAlertCard.security(
          key: ValueKey('home-safety-banner-${critical.key}'),
          type: HomeAlertCardType.securityIncident,
          showDelay: Duration.zero,
          title: critical.title,
          description: critical.body,
          icon: _icon(CommonStateIconPath.siren, colors.iconOnDanger),
          onTap: open,
          onClosed: null,
        ),
      );
    }

    int balanceOf(WalletItemBase wallet) => walletProvider?.getWalletBalance(wallet.id).total ?? 0;
    final unbacked =
        wallets
            .where(
              (wallet) =>
                  wallet.hasLocalKey && !(wallet.hotWalletMetadata?.backupVerified ?? false) && balanceOf(wallet) > 0,
            )
            .firstOrNull;
    final hasHotWalletWithBalance = wallets.any((wallet) => wallet.hasLocalKey && balanceOf(wallet) > 0);
    final isAppLockEnabled = context.watch<AuthProvider?>()?.isAuthEnabled ?? true;
    final state = _policy.resolve(
      unbackedHotWalletId: unbacked?.id,
      hasHotWalletWithBalance: hasHotWalletWithBalance,
      isAppLockEnabled: isAppLockEnabled,
      shouldShowOpenStoreIntro: false,
    );
    final warning = state.visibleWarning;
    if (warning == null) return const SizedBox.shrink();

    final isBackup = warning == HomeSecurityWarningType.unbackedHotWallet;
    // 새 홈은 CupertinoPageScaffold 안이라 Material이 없다. 닫기 X(InkWell)가 Material 조상을 찾게 투명 Material로 감싼다
    return Material(
      type: MaterialType.transparency,
      child: HomeAlertCard.security(
        key: ValueKey('home-safety-banner-${warning.name}'),
        type: isBackup ? HomeAlertCardType.mnemonicBackup : HomeAlertCardType.appLock,
        showDelay:
            reduceMotion
                ? Duration.zero
                : state.showWarningAfterPrevious
                ? _nextWarningDelay
                : _warningDelay,
        title:
            isBackup
                ? t.wallet_home_screen.unbacked_hot_wallet_warning.title
                : t.wallet_home_screen.app_lock_warning.title,
        description:
            isBackup
                ? t.wallet_home_screen.unbacked_hot_wallet_warning.description
                : t.wallet_home_screen.app_lock_warning.description,
        icon:
            isBackup
                ? _icon(CommonStateIconPath.triangleWarning, colors.iconOnDanger)
                : _icon(CommonStateIconPath.shieldWarning, colors.appLockWarningForeground),
        onTap: isBackup ? () => _openBackup(unbacked!) : _openAppLockSettings,
        onClosed: () async {
          await _policy.dismiss(
            warning,
            hasHotWalletWithBalance: hasHotWalletWithBalance,
            isAppLockEnabled: isAppLockEnabled,
          );
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _openBackup(WalletItemBase wallet) {
    context.read<AnalyticsService>().logBackupPromptTapped(BackupPromptLocation.homeCard);
    Navigator.pushNamed(
      context,
      AppRouteNames.walletInfo,
      arguments: WalletInfoRouteArgs(
        id: wallet.id,
        walletType: wallet.walletType,
        entryPoint: kEntryPointWalletHome,
        highlightMnemonicBackup: true,
      ),
    );
  }

  void _openAppLockSettings() {
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      screenName: AnalyticsScreenNames.walletHomeAppSettingsSheet,
      child: const AppSettingsScreen(),
      heightRatio: 0.9,
    );
  }
}
