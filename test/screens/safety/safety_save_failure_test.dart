import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/safety_store.dart';
import 'package:coconut_wallet/screens/safety/security_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repository/realm/test_realm_manager.dart';
import '../../services/safety/safety_fakes.dart';
import 'safety_test_harness.dart' as guide;

/// 진짜 SafetyProvider. 감지기 재평가만 멈춘다(이 경로 밖이고, 사건 상태를 그대로 두려고)
class _Provider extends SafetyProvider {
  _Provider(SafetyStore store, SafetyWalletsFake wallets, TestRealmManager realm)
    : super(
        walletProvider: wallets,
        nodeProvider: SafetyNodeFake(),
        authProvider: SafetyAuthFake(),
        connectivityProvider: SafetyConnectivityFake(),
        realmManager: realm,
        analytics: SafetyAnalyticsFake(),
        store: store,
        checkAppUpdate: () async => AppUpdateStatus.upToDate,
        probeServerCert: (_) async => const ServerCertObservation(applicable: false, caValid: false),
      );

  @override
  Future<void> refresh() async {}
}

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  late TestRealmManager realm;
  late SafetyWalletsFake wallets;
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    realm = TestRealmManager();
    wallets = SafetyWalletsFake([safetyWallet(id: 1, hot: true)]);
  });
  tearDown(() {
    realm.dispose();
    SafetyStore.resetForTest();
  });

  /// 사고 지갑(1)의 가이드 STEP3까지 연다
  Future<(SafetyDiskFake, _Provider)> openStep3(WidgetTester tester) async {
    guide.usePhoneSize(tester);
    final disk = SafetyDiskFake();
    final store = await disk.open();
    final incident = SafetyIncident(
      walletId: 1,
      txid: 'aa' * 32,
      detectedAt: DateTime(2026, 11, 10),
      state: IncidentState.responding,
      responseMode: IncidentResponseMode.free,
      guideStep: 3,
    );
    await store.updateConfirmed((s) => s.copyWith(incidents: [incident]));
    final safety = _Provider(store, wallets, realm);
    await tester.pumpWidget(
      guide.safetyTestApp(guide.origin(), safety: safety, wallets: wallets, preferences: guide.FakePreferences()),
    );
    unawaited(SecurityGuide.resume(guide.originContext(tester), incident.id));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step3')), findsOneWidget);
    return (disk, safety);
  }

  Future<void> close(WidgetTester tester, _Provider safety) async {
    await tester.pump(const Duration(seconds: 5)); // 토스트 닫힘
    await tester.pumpWidget(const SizedBox());
    safety.dispose();
  }

  // M08: 기기가 답하지 않으면(멈춘 저장) 3초 뒤 실패를 알리고 STEP3에 남는다(사용 주의는 표시되지 않는다)
  testWidgets('M08 STEP3: a save with no answer within 3 s says so and stays on STEP3', (tester) async {
    final (disk, safety) = await openStep3(tester);
    disk.hold = Completer<void>().future;
    await guide.tapVisible(tester, guide.findText(t.safety_guide.step3.mark));
    expect(guide.findText(t.wallet_health.save_failed), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(guide.findText(t.wallet_health.save_failed), findsOneWidget);
    expect(find.byKey(const Key('safety-guide-step3-marked')), findsNothing);
    expect(safety.isCaution(1), isFalse);
    await close(tester, safety);
  });

  // M08: 저장이 느릴 때 버튼을 두 번 눌러도 "표시했어요"는 한 장만 열린다(저장하는 동안 버튼이 다시 받지 않는다)
  testWidgets('M08 STEP3: a double tap during a slow save opens one marked page', (tester) async {
    final (disk, safety) = await openStep3(tester);
    final reply = Completer<void>();
    disk.hold = reply.future;
    final mark = guide.findText(t.safety_guide.step3.mark);
    await guide.tapVisible(tester, mark);
    await tester.pump(const Duration(milliseconds: 100));
    await guide.tapVisible(tester, mark);
    disk.hold = null;
    reply.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step3-marked'), skipOffstage: false), findsOneWidget);
    expect(disk.durable.cautionWalletIds, {1});
    await close(tester, safety);
  });

  // M08: 가이드 STEP3 "사용 주의로 표시"를 기기가 저장하지 못하면(저장 공간 가득 등) "표시했어요"로 가지 않는다.
  // 실패를 알리고 STEP3에 남으며, 표시는 메모리에도 디스크에도 없다(앱을 다시 켜면 사라질 표시를 한 것처럼 보이지 않게).
  // 저장은 진짜 길(SafetyProvider → SafetyStore → shared_preferences → 기기 저장소)이고 기기만 거절하게 바꾼다
  testWidgets('M08 STEP3: a rejected caution mark says so, stays on STEP3 and does not look saved', (tester) async {
    guide.usePhoneSize(tester);
    final disk = SafetyDiskFake();
    final store = await disk.open();
    final incident = SafetyIncident(
      walletId: 1,
      txid: 'aa' * 32,
      detectedAt: DateTime(2026, 11, 10),
      state: IncidentState.responding,
      responseMode: IncidentResponseMode.free,
      guideStep: 3,
    );
    await store.update((s) => s.copyWith(incidents: [incident]));
    final safety = _Provider(store, wallets, realm);
    await tester.pumpWidget(
      guide.safetyTestApp(guide.origin(), safety: safety, wallets: wallets, preferences: guide.FakePreferences()),
    );
    unawaited(SecurityGuide.resume(guide.originContext(tester), incident.id));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step3')), findsOneWidget);

    disk.accept = false;
    await guide.tapVisible(tester, guide.findText(t.safety_guide.step3.mark));
    await tester.pump(const Duration(milliseconds: 300));
    expect(guide.findText(t.wallet_health.save_failed), findsOneWidget);
    expect(find.byKey(const Key('safety-guide-step3-marked')), findsNothing);
    expect(find.byKey(const Key('safety-guide-step3')), findsOneWidget);
    expect(safety.isCaution(1), isFalse);
    expect(disk.durable.cautionWalletIds, isEmpty);
    expect(disk.durable.incidents.single.guideStep, 3);

    // 공간이 생기면 같은 단계에서 다시 눌러 저장된다
    await tester.pump(const Duration(seconds: 5));
    disk.accept = true;
    await guide.tapVisible(tester, guide.findText(t.safety_guide.step3.mark));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step3-marked')), findsOneWidget);
    expect(safety.isCaution(1), isTrue);
    expect(disk.durable.cautionWalletIds, {1});
    expect(disk.durable.incidents.single.guideStep, 4);

    await tester.pumpWidget(const SizedBox());
    safety.dispose();
  });
}
