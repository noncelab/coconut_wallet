import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/rescue/rescue_ready_screen.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_safety_status_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Rescue extends ChangeNotifier implements RescueReadyProvider {
  String? label;
  @override
  String? destinationLabel(int walletId) => label;
  @override
  RescueDestination? destinationOf(int walletId) =>
      label == null ? null : RescueDestination(walletId: 2, setAt: DateTime(2026));
  void rename(String? value) {
    label = value;
    notifyListeners();
  }

  /// RescueReadyScreen이 그릴 때 읽는다(Premium 안내 한 줄)
  @override
  bool get lacksPremium => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletHealthReport _report({List<SafetyCheckResult> issues = const [], bool checked = true}) => WalletHealthReport(
  status: WalletHealthStatus.scored,
  profile: WeightProfile.watchOnlyOnly,
  evaluatedAt: DateTime(2026),
  reviewItems: issues,
  allGoodItems:
      checked ? [const SafetyCheckResult(SafetyCheckId.watchOnlyVerify, SafetyOutcome.passed, walletId: 1)] : [],
);

void main() {
  for (final locale in [AppLocale.ko, AppLocale.en]) {
    for (final theme in CoconutThemeVariant.values) {
      Future<void> mount(
        WidgetTester tester,
        SafetyProvider? safety, {
        bool destination = false,
        EntitlementService? entitlement,
        RescueReadyProvider? rescue,
      }) async {
        LocaleSettings.setLocaleSync(locale);
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (safety != null) addTearDown(safety.dispose);
        Widget app = MaterialApp(
          theme: buildCoconutThemeData(variant: theme),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: Scaffold(
            body:
                destination ? const WalletRescueDestinationRow(walletId: 1) : const WalletSafetyStatusRow(walletId: 1),
          ),
        );
        if (safety != null) app = ChangeNotifierProvider<SafetyProvider>.value(value: safety, child: app);
        if (entitlement != null) app = Provider<EntitlementService>.value(value: entitlement, child: app);
        if (rescue != null) app = ChangeNotifierProvider<RescueReadyProvider>.value(value: rescue, child: app);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
      }

      testWidgets('${locale.name} ${theme.name} at 320 dp: no provider renders nothing', (tester) async {
        await mount(tester, null);
        expect(find.byKey(const Key('wallet-safety-status-row')), findsNothing);
        expect(tester.takeException(), isNull);
      });
      testWidgets('${locale.name} ${theme.name} at 320 dp: pending and checked status use distinct tokens', (
        tester,
      ) async {
        await mount(tester, SafetyProvider.fixed(null));
        expect(find.text(t.wallet_health.wallet_info.waiting), findsOneWidget);
        await mount(tester, SafetyProvider.fixed(_report()));
        final text = tester.widget<Text>(find.text(t.wallet_health.wallet_info.no_issues));
        expect(text.style!.color, resolveCoconutThemeExtension(variant: theme).colors.success);
      });
      testWidgets('${locale.name} ${theme.name} at 320 dp: only this wallet contributes to the attention count', (
        tester,
      ) async {
        await mount(
          tester,
          SafetyProvider.fixed(
            _report(
              issues: const [
                SafetyCheckResult(
                  SafetyCheckId.watchOnlyVerify,
                  SafetyOutcome.failed,
                  walletId: 1,
                  severity: SafetySeverity.actionNeeded,
                ),
                SafetyCheckResult(
                  SafetyCheckId.addressReuse,
                  SafetyOutcome.failed,
                  walletId: 2,
                  severity: SafetySeverity.warning,
                ),
                SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.failed, severity: SafetySeverity.actionNeeded),
              ],
            ),
          ),
        );
        final text = tester.widget<Text>(find.text(t.wallet_health.wallet_info.needs_attention(n: 1)));
        expect(text.style!.color, resolveCoconutThemeExtension(variant: theme).colors.warningText);
        expect(tester.takeException(), isNull);
      });
      testWidgets('${locale.name} ${theme.name} at 320 dp: critical takes priority over caution', (tester) async {
        await mount(
          tester,
          SafetyProvider.fixed(
            _report(
              issues: const [
                SafetyCheckResult(
                  SafetyCheckId.watchOnlyVerify,
                  SafetyOutcome.failed,
                  walletId: 1,
                  severity: SafetySeverity.critical,
                ),
              ],
            ),
            state: SafetyState.initial().copyWith(cautionWalletIds: {1}),
          ),
        );
        final text = tester.widget<Text>(find.text(t.wallet_health.wallet_info.critical));
        expect(text.style!.color, resolveCoconutThemeExtension(variant: theme).colors.dangerText);
        expect(find.text(t.wallet_health.wallet_info.caution), findsNothing);
      });
      testWidgets('${locale.name} ${theme.name} at 320 dp: caution is visible before a report exists', (tester) async {
        await mount(tester, SafetyProvider.fixed(null, state: SafetyState.initial().copyWith(cautionWalletIds: {1})));
        expect(find.text(t.wallet_health.wallet_info.caution), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${locale.name} ${theme.name} at 320 dp: destination requires both optional providers', (
        tester,
      ) async {
        final entitlement = FakeEntitlementService(initial: const PremiumState(PremiumStatus.active));
        final rescue = _Rescue();
        addTearDown(entitlement.dispose);
        addTearDown(rescue.dispose);
        await mount(tester, null, destination: true, entitlement: entitlement);
        expect(find.byKey(const Key('wallet-rescue-destination-row')), findsNothing);
        await mount(tester, null, destination: true, rescue: rescue);
        expect(find.byKey(const Key('wallet-rescue-destination-row')), findsNothing);
        expect(tester.takeException(), isNull);
      });
      testWidgets('${locale.name} ${theme.name} at 320 dp: destination follows Premium and wraps its name', (
        tester,
      ) async {
        final entitlement = FakeEntitlementService();
        final rescue = _Rescue();
        addTearDown(entitlement.dispose);
        addTearDown(rescue.dispose);
        await mount(tester, null, destination: true, entitlement: entitlement, rescue: rescue);
        final row = find.byKey(const Key('wallet-rescue-destination-row'));
        expect(row, findsNothing);
        entitlement.emit(const PremiumState(PremiumStatus.active));
        await tester.pumpAndSettle();
        expect(find.text(t.premium.rescue.destination), findsOneWidget);
        expect(find.text(t.premium.rescue.not_set), findsOneWidget);
        final name = locale == AppLocale.ko ? '아주 긴 이름의 비상 목적지 지갑' : 'A very long emergency destination wallet name';
        rescue.rename(name);
        await tester.pumpAndSettle();
        expect(find.text(name), findsOneWidget);
        expect(tester.getSize(row).width, 320);
        expect(tester.takeException(), isNull);
        for (final status in [
          PremiumStatus.verifying,
          PremiumStatus.pending,
          PremiumStatus.expired,
          PremiumStatus.none,
        ]) {
          entitlement.emit(PremiumState(status));
          await tester.pumpAndSettle();
          expect(row, findsOneWidget);
        }
        rescue.rename(null);
        await tester.pumpAndSettle();
        expect(row, findsNothing);
      });
      testWidgets('${locale.name} ${theme.name} at 320 dp: expired destination stays reachable until cleared', (
        tester,
      ) async {
        final entitlement = FakeEntitlementService(initial: const PremiumState(PremiumStatus.expired));
        final rescue = _Rescue();
        addTearDown(entitlement.dispose);
        addTearDown(rescue.dispose);
        await mount(tester, null, destination: true, entitlement: entitlement, rescue: rescue);
        final row = find.byKey(const Key('wallet-rescue-destination-row'));
        expect(row, findsNothing);
        rescue.rename('Emergency wallet');
        await tester.pumpAndSettle();
        expect(row, findsOneWidget);
        expect(find.text('Emergency wallet'), findsOneWidget);
        await tester.tap(row);
        await tester.pumpAndSettle();
        final screen = find.byType(RescueReadyScreen);
        expect(tester.widget<RescueReadyScreen>(screen).walletId, 1);
        Navigator.pop(tester.element(screen));
        await tester.pumpAndSettle();
        rescue.rename(null);
        await tester.pumpAndSettle();
        expect(row, findsNothing);
        entitlement.emit(const PremiumState(PremiumStatus.active));
        await tester.pumpAndSettle();
        expect(row, findsOneWidget);
        expect(find.text(t.premium.rescue.not_set), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      testWidgets('${locale.name} ${theme.name} at 320 dp: destination opens RescueReady for this wallet', (
        tester,
      ) async {
        final entitlement = FakeEntitlementService(initial: const PremiumState(PremiumStatus.active));
        final rescue = _Rescue();
        addTearDown(entitlement.dispose);
        addTearDown(rescue.dispose);
        await mount(tester, null, destination: true, entitlement: entitlement, rescue: rescue);
        await tester.tap(find.byKey(const Key('wallet-rescue-destination-row')));
        await tester.pumpAndSettle();
        expect(tester.widget<RescueReadyScreen>(find.byType(RescueReadyScreen)).walletId, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
