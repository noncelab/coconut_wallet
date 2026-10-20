import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/services/safety/safety_inputs_collector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../repository/realm/test_realm_manager.dart';
import '../services/safety/safety_fakes.dart';

/// 구성이 온전한 2-of-2 다중서명 지갑
MultisigWalletItem _multisig({int id = 1}) {
  final keys = [
    for (final byte in [1, 2])
      KeyStore.fromSeed(Seed.fromEntropy(Uint8List.fromList(List.filled(16, byte))), AddressType.p2wsh),
  ];
  return MultisigWalletItem(
    id: id,
    name: 'Multi',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: MultisignatureVault.fromKeyStoreList(keys, 2).descriptor,
    signers: [MultisigSigner(), MultisigSigner()],
    requiredSignatureCount: 2,
  );
}

class _Provider extends SafetyProvider {
  _Provider({
    required super.walletProvider,
    required super.nodeProvider,
    required super.authProvider,
    required super.connectivityProvider,
    required super.realmManager,
    required super.analytics,
    required super.store,
    required super.now,
    super.checkAppUpdate,
    super.probeServerCert,
  });
  int vibrations = 0;
  bool isDisposed = false;
  @override
  void vibrateForIncident() => vibrations++;
  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestRealmManager realm;
  late SafetyWalletsFake wallets;
  late SafetyNodeFake node;
  late SafetyAuthFake auth;
  late SafetyConnectivityFake connectivity;
  late SafetyStoreFake store;
  late SafetyAnalyticsFake analytics;
  late _Provider provider;
  setUp(() {
    NetworkType.setNetworkType(NetworkType.testnet);
    realm = TestRealmManager();
    wallets = SafetyWalletsFake([safetyWallet()]);
    node = SafetyNodeFake();
    auth = SafetyAuthFake();
    connectivity = SafetyConnectivityFake();
    store = SafetyStoreFake();
    analytics = SafetyAnalyticsFake();
  });
  tearDown(() {
    if (!provider.isDisposed) provider.dispose();
    wallets.dispose();
    node.dispose();
    auth.dispose();
    connectivity.dispose();
    realm.dispose();
  });
  void create(
    WidgetTester tester, {
    bool checksThrow = false,
    Future<ServerCertObservation?> Function(NodeProvider)? probe,
  }) {
    provider = _Provider(
      walletProvider: wallets,
      nodeProvider: node,
      authProvider: auth,
      connectivityProvider: connectivity,
      realmManager: realm,
      analytics: analytics,
      store: store,
      now: () => tester.binding.clock.now(),
      checkAppUpdate: () async {
        if (checksThrow) throw StateError('offline');
        return AppUpdateStatus.upToDate;
      },
      probeServerCert:
          probe ??
          (_) async {
            if (checksThrow) throw StateError('offline');
            return const ServerCertObservation(applicable: false, caValid: false);
          },
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  SafetyIncident incident(String txid) => SafetyIncident(walletId: 1, txid: txid, detectedAt: DateTime(2026));

  testWidgets('debounce coalesces bursts and identical reports do not notify', (tester) async {
    create(tester);
    await settle(tester);
    var notifications = 0;
    provider.addListener(() => notifications++);
    final before = wallets.collections;
    wallets.notifyListeners();
    auth.notifyListeners();
    connectivity.notifyListeners();
    await tester.pump(const Duration(milliseconds: 399));
    expect(wallets.collections, before);
    await tester.pump(const Duration(milliseconds: 1));
    expect(wallets.collections, before + 1);
    expect(notifications, 0);
  });
  testWidgets('does not evaluate until wallets load', (tester) async {
    wallets.walletLoadStateNotifier.value = WalletLoadState.loadingFromDB;
    create(tester);
    await settle(tester);
    expect(provider.report, isNull);
    expect(wallets.collections, 0);
    expect(store.writes, 0);
    wallets.walletLoadStateNotifier.value = WalletLoadState.loadCompleted;
    await settle(tester);
    expect(provider.report, isNotNull);
  });
  testWidgets('height zero never establishes baseline or successful sync', (tester) async {
    node.height = 0;
    create(tester);
    node.sync.add(NodeSyncState.completed);
    await settle(tester);
    expect(store.state.baselines, isEmpty);
    expect(store.state.lastSuccessfulSyncAt, isNull);
  });
  testWidgets('completed first sync waits for a positive block height without losing its timestamp', (tester) async {
    node.height = 0;
    create(tester);
    final completedAt = tester.binding.clock.now();
    node.sync.add(NodeSyncState.completed);
    await settle(tester);
    expect(store.state.lastSuccessfulSyncAt, isNull);
    await provider.refresh();
    expect(store.state.lastSuccessfulSyncAt, isNull);
    node.height = 100;
    node.currentBlockNotifier.value = BlockTimestamp(100, completedAt);
    await settle(tester);
    expect(store.state.baselines.keys, [1]);
    expect(store.state.lastSuccessfulSyncAt, completedAt);
  });
  for (final change in ['server', 'connection', 'internet', 'sync session']) {
    testWidgets('pending sync completion is invalidated by a $change change', (tester) async {
      node.height = 0;
      create(tester);
      node.sync.add(NodeSyncState.completed);
      await settle(tester);
      switch (change) {
        case 'server':
          node.host = 'new.invalid';
          node.notifyListeners();
        case 'connection':
          node.connected = false;
          node.notifyListeners();
          node.connected = true;
        case 'internet':
          connectivity.connected = false;
          connectivity.notifyListeners();
          connectivity.connected = true;
        case 'sync session':
          node.sync.add(NodeSyncState.syncing);
          await tester.pump();
      }
      node.height = 100;
      node.currentBlockNotifier.value = BlockTimestamp(100, DateTime(2026));
      await settle(tester);
      expect(store.state.lastSuccessfulSyncAt, isNull);
      node.sync.add(NodeSyncState.completed);
      await settle(tester);
      expect(store.state.lastSuccessfulSyncAt, isNotNull);
    });
  }
  testWidgets('offline initial completed is not a successful sync', (tester) async {
    node.connected = false;
    create(tester);
    node.sync.add(NodeSyncState.completed);
    await settle(tester);
    expect(store.state.baselines, isEmpty);
    expect(store.state.lastSuccessfulSyncAt, isNull);
    node.connected = true;
    node.notifyListeners();
    await settle(tester);
    expect(store.state.lastSuccessfulSyncAt, isNull);
    node.sync.add(NodeSyncState.completed);
    await settle(tester);
    expect(store.state.baselines.keys, [1]);
    expect(store.state.lastSuccessfulSyncAt, isNotNull);
  });
  testWidgets('connected initial completed without registration is not successful', (tester) async {
    node.state = NodeProviderState.initial();
    create(tester);
    node.sync.add(NodeSyncState.completed);
    await settle(tester);
    expect(store.state.baselines, isEmpty);
    expect(store.state.lastSuccessfulSyncAt, isNull);
  });
  testWidgets('new critical incident vibrates once and persistence survives reevaluation', (tester) async {
    create(tester);
    await settle(tester);
    wallets.records[1] = [safetyTx('outgoing')];
    await provider.refresh();
    expect(provider.vibrations, 1);
    expect(store.state.incidents.single.txid, 'outgoing');
    expect(provider.hasUnreadAlerts, isTrue);
    await provider.refresh();
    await provider.refresh();
    expect(provider.vibrations, 1);
    await provider.markAlertsRead();
    expect(provider.hasUnreadAlerts, isFalse);
    expect(store.state.readItemIds, contains('incident:1:outgoing'));
  });
  testWidgets('previously persisted incidents do not vibrate again at startup', (tester) async {
    store.state = SafetyState(incidents: [incident('known')]);
    wallets.records[1] = [safetyTx('known')];
    create(tester);
    await settle(tester);
    expect(provider.vibrations, 0);
  });
  testWidgets('recognize persists state and exclusion txid', (tester) async {
    store.state = SafetyState(incidents: [incident('known')]);
    wallets.records[1] = [safetyTx('known')];
    create(tester);
    await settle(tester);
    await provider.recognizeIncident('1:known');
    expect(store.state.incidents.single.state, IncidentState.recognized);
    expect(store.state.recognizedTxids, {'known'});
    expect(provider.incidentFor(1, 'known')!.isOpen, isFalse);
    expect(provider.incidentFor(1, 'missing'), isNull);
  });
  testWidgets('recognizing a shared transaction closes every open incident across wallets', (tester) async {
    wallets.walletItemListNotifier.value = [safetyWallet(hot: true), safetyWallet(id: 2)];
    store.state = SafetyState(
      incidents: [
        incident('shared'),
        SafetyIncident(walletId: 2, txid: 'shared', detectedAt: DateTime(2026)).respond(IncidentResponseMode.free),
      ],
    );
    wallets.records[1] = [safetyTx('shared')];
    wallets.records[2] = [safetyTx('shared')];
    create(tester);
    await settle(tester);
    await provider.recognizeIncident('1:shared');
    expect(store.state.incidents.map((i) => i.state), everyElement(IncidentState.recognized));
    expect(store.state.incidents.map((i) => i.resolvedAt).toSet().length, 1);
    expect(store.state.recognizedTxids, {'shared'});
  });
  testWidgets('completing a shared transaction stays per incident and recognition preserves closed incidents', (
    tester,
  ) async {
    wallets.walletItemListNotifier.value = [safetyWallet(hot: true), safetyWallet(id: 2)];
    store.state = SafetyState(
      incidents: [
        incident('shared').respond(IncidentResponseMode.free),
        SafetyIncident(walletId: 2, txid: 'shared', detectedAt: DateTime(2026)),
      ],
    );
    wallets.records[1] = [safetyTx('shared')];
    wallets.records[2] = [safetyTx('shared')];
    create(tester);
    await settle(tester);
    await provider.completeIncident('1:shared');
    expect(provider.incidentFor(1, 'shared')!.state, IncidentState.completed);
    expect(provider.incidentFor(2, 'shared')!.isOpen, isTrue);
    await provider.recognizeIncident('2:shared');
    expect(provider.incidentFor(1, 'shared')!.state, IncidentState.completed);
    expect(provider.incidentFor(2, 'shared')!.state, IncidentState.recognized);
  });
  testWidgets('baseline pending review can be acknowledged without inventing an incident', (tester) async {
    wallets.records[1] = [safetyTx('baseline')];
    create(tester);
    await settle(tester);
    expect(provider.state.incidents, isEmpty);
    expect(provider.report!.reviewItems.any((item) => item.id == SafetyCheckId.pendingOutgoingAtBaseline), isTrue);
    await provider.recognizeIncident('1:baseline');
    expect(store.state.recognizedTxids, {'baseline'});
    expect(provider.report!.reviewItems.any((item) => item.id == SafetyCheckId.pendingOutgoingAtBaseline), isFalse);
    await expectLater(provider.recognizeIncident('1:unknown'), throwsStateError);
  });
  testWidgets('an unexpected self transfer after the baseline can be acknowledged as a review item', (tester) async {
    create(tester);
    await settle(tester);
    wallets.records[1] = [safetyTx('self', type: TransactionType.self)];
    await provider.refresh();
    expect(provider.report!.reviewItems.any((item) => item.id == SafetyCheckId.unexpectedSelfTransfer), isTrue);
    await provider.recognizeIncident('1:self');
    expect(store.state.recognizedTxids, contains('self'));
    expect(store.state.incidents, isEmpty);
    expect(provider.report!.reviewItems.any((item) => item.id == SafetyCheckId.unexpectedSelfTransfer), isFalse);
  });
  testWidgets('app-created transaction recorded for another wallet is excluded', (tester) async {
    create(tester);
    await settle(tester);
    // 앱 생성 기록은 모든 지갑 공용(어느 지갑에서 만들었든 같은 txid면 조용)
    store.state = store.state.copyWith(appTxidPrefixes: {SafetyState.txidPrefix('shared')});
    wallets.records[1] = [safetyTx('shared')];
    await provider.refresh();
    expect(store.state.incidents, isEmpty);
    expect(provider.vibrations, 0);
  });
  testWidgets('baseline pending outgoing can start one persisted incident response', (tester) async {
    wallets.records[1] = [safetyTx('baseline')];
    create(tester);
    await settle(tester);
    await provider.markIncidentUnrecognized('1:baseline', IncidentResponseMode.free);
    expect(store.state.incidents.single.txid, 'baseline');
    expect(store.state.incidents.single.state, IncidentState.responding);
    expect(analytics.events.single.name, AnalyticsEventNames.incidentResponseStarted);
    await expectLater(provider.markIncidentUnrecognized('1:unknown', IncidentResponseMode.free), throwsStateError);
    expect(store.state.incidents.length, 1);
    expect(analytics.events.length, 1);
  });
  for (final alias in ['01:baseline', '+1:baseline']) {
    testWidgets('baseline incident actions reject noncanonical id $alias', (tester) async {
      wallets.records[1] = [safetyTx('baseline')];
      create(tester);
      await settle(tester);
      final before = store.state;
      await expectLater(provider.recognizeIncident(alias), throwsStateError);
      await expectLater(provider.markIncidentUnrecognized(alias, IncidentResponseMode.free), throwsStateError);
      expect(store.state, before);
      expect(analytics.events, isEmpty);
      await provider.markIncidentUnrecognized('1:baseline', IncidentResponseMode.free);
      expect(store.state.incidents.single.id, '1:baseline');
    });
  }
  testWidgets('mode switch preserves guide progress and does not start another response', (tester) async {
    store.state = SafetyState(incidents: [incident('known')]);
    wallets.records[1] = [safetyTx('known')];
    create(tester);
    await settle(tester);
    await provider.markIncidentUnrecognized('1:known', IncidentResponseMode.free);
    await provider.setIncidentGuideStep('1:known', 2, assistStartedAt: DateTime(2026));
    await provider.markIncidentUnrecognized('1:known', IncidentResponseMode.premium);
    expect(store.state.incidents.single.guideStep, 2);
    expect(store.state.incidents.single.assistStartedAt, DateTime(2026));
    expect(analytics.events.length, 1);
    await provider.completeIncident('1:known');
    expect(analytics.events.last.parameters, {'response_mode': 'premium'});
  });
  testWidgets('failed probe keeps the last certificate observation for the same server', (tester) async {
    store.state = SafetyState(
      serverCert: ServerCertRecord(
        host: node.host,
        port: node.port,
        fingerprint: 'AA:BB',
        caValid: false,
        observedAt: DateTime(2026),
      ),
    );
    create(tester, probe: (_) async => const ServerCertObservation(applicable: true, caValid: false));
    await settle(tester);
    expect(
      provider.report!.reviewItems.any(
        (item) => item.id == SafetyCheckId.serverCert && item.severity == SafetySeverity.critical,
      ),
      isTrue,
    );
  });
  testWidgets('changing servers while probing discards the old result and checks the new server', (tester) async {
    final first = Completer<ServerCertObservation?>();
    var probes = 0;
    create(
      tester,
      probe: (_) {
        probes++;
        return probes == 1
            ? first.future
            : Future.value(const ServerCertObservation(applicable: true, actual: 'new', pinned: 'new', caValid: true));
      },
    );
    node.host = 'new.invalid';
    node.notifyListeners();
    first.complete(const ServerCertObservation(applicable: true, actual: 'old', caValid: false));
    await settle(tester);
    expect(probes, 2);
    expect(store.state.serverCert!.host, 'new.invalid');
    expect(store.state.serverCert!.fingerprint, 'new');
  });
  test('owned TLS probe closes stalled transports on server switch and provider disposal', () async {
    final firstPeer = await SafetySilentTlsPeer.start();
    final secondPeer = await SafetySilentTlsPeer.start();
    addTearDown(firstPeer.close);
    addTearDown(secondPeer.close);
    node.host = '127.0.0.1';
    node.port = firstPeer.port;
    provider = _Provider(
      walletProvider: wallets,
      nodeProvider: node,
      authProvider: auth,
      connectivityProvider: connectivity,
      realmManager: realm,
      analytics: analytics,
      store: store,
      now: DateTime.now,
      checkAppUpdate: () async => AppUpdateStatus.upToDate,
    );
    await firstPeer.accepted.future.timeout(const Duration(seconds: 2));
    node.port = secondPeer.port;
    node.notifyListeners();
    await firstPeer.disconnected.future.timeout(const Duration(seconds: 1));
    await secondPeer.accepted.future.timeout(const Duration(seconds: 2));
    provider.dispose();
    await secondPeer.disconnected.future.timeout(const Duration(seconds: 1));
    expect(store.state.serverCert, isNull);
    expect(node.pinnedCertFingerprint, 'pin');
  });
  for (final mode in IncidentResponseMode.values) {
    testWidgets('response, guide step and completion persist and log only mode (${mode.name})', (tester) async {
      store.state = SafetyState(incidents: [incident('known')]);
      wallets.records[1] = [safetyTx('known')];
      create(tester);
      await settle(tester);
      await provider.markIncidentUnrecognized('1:known', mode);
      final started = DateTime(2026, 3);
      await provider.setIncidentGuideStep('1:known', 2, assistStartedAt: started);
      expect(store.state.incidents.single.guideStep, 2);
      expect(store.state.incidents.single.assistStartedAt, started);
      await provider.completeIncident('1:known');
      expect(store.state.incidents.single.state, IncidentState.completed);
      expect(store.state.incidents.single.responseMode, mode);
      expect(analytics.events.map((event) => event.name), [
        AnalyticsEventNames.incidentResponseStarted,
        AnalyticsEventNames.incidentResponseCompleted,
      ]);
      expect(analytics.events.map((event) => event.parameters), everyElement({'response_mode': mode.name}));
      await expectLater(provider.completeIncident('1:known'), throwsStateError);
      expect(analytics.events.length, 2);
    });
  }
  testWidgets('caution, verification records, recommendations and hint persist', (tester) async {
    create(tester);
    await settle(tester);
    await provider.setCaution(1, true);
    expect(provider.isCaution(1), isTrue);
    await provider.setCaution(1, false);
    expect(provider.isCaution(1), isFalse);
    await provider.recordPassphraseVerified(1);
    await provider.recordWatchOnlyVerification(
      1,
      method: VerificationMethod.qr,
      result: VerificationResult.match,
      matchedIndex: 19,
    );
    await provider.recordBsmsVerification(1, matched: true, configHash: 'config');
    await provider.setRecommendedDone(RecommendedCheckId.hotPhysicalBackup, true);
    expect(store.state.passphraseVerifiedAt[1], isNotNull);
    expect(
      store.state.watchOnlyVerifications[1]!.descriptorHash,
      WalletVerification.descriptorHash(wallets.walletItemList.single.descriptor),
    );
    expect(store.state.watchOnlyVerifications[1]!.matchedIndex, 19);
    expect(store.state.bsms[1]!.configHash, 'config');
    expect(store.state.recommendedDoneAt, contains(RecommendedCheckId.hotPhysicalBackup.key));
    await provider.setRecommendedDone(RecommendedCheckId.hotPhysicalBackup, false);
    expect(store.state.recommendedDoneAt, isEmpty);
    expect(provider.showsHomeHint, isTrue);
    await provider.dismissHomeHint();
    expect(provider.showsHomeHint, isFalse);
    expect(store.state.hintDismissed, isTrue);
  });
  testWidgets(
    'BSMS export keeps the collector\'s descriptor hash, shows exported · not verified, never verifies (R30)',
    (tester) async {
      wallets.walletItemListNotifier.value = [_multisig()];
      create(tester);
      await settle(tester);
      await provider.recordBsmsExport(1);
      final inputs = SafetyInputsCollector(
        walletProvider: wallets,
        nodeProvider: node,
        authProvider: auth,
        connectivityProvider: connectivity,
        realmManager: realm,
      ).collect(state: provider.state, now: DateTime(2026));
      expect(store.state.bsmsExports[1]!.configHash, inputs.wallets.single.descriptorHash);
      expect(store.state.bsms, isEmpty, reason: 'an export is not a verification');
      final bsms = provider.report!.reviewItems.singleWhere((item) => item.id == SafetyCheckId.bsmsBackup);
      expect(bsms.detail, SafetyCheckDetail.exportedNotVerified);
    },
  );
  testWidgets('recovery review keeps the status and the wallet kind\'s material, never moves the response (R33)', (
    tester,
  ) async {
    store.state = SafetyState(incidents: [incident('known')]);
    wallets.records[1] = [safetyTx('known')];
    create(tester);
    await settle(tester);
    await provider.markIncidentUnrecognized('1:known', IncidentResponseMode.free);
    await provider.setIncidentGuideStep('1:known', 4);
    // 노출 의심: 안내만 연다. 상태·단계·모드는 그대로
    await provider.recordRecoveryReview('1:known', RecoveryReviewStatus.exposureSuspected);
    final suspected = store.state.incidents.single;
    expect(
      (suspected.recoveryReview, suspected.recoveryMaterial),
      (RecoveryReviewStatus.exposureSuspected, RecoveryMaterialType.signerRecoveryMaterial),
      reason: 'watch-only wallet',
    );
    expect(
      (suspected.state, suspected.guideStep, suspected.responseMode),
      (IncidentState.responding, 4, IncidentResponseMode.free),
    );
    expect(provider.state.incidents.single.recoveryReview, RecoveryReviewStatus.exposureSuspected);
    // 종류는 기록할 때 지갑 종류에서 정한다
    for (final (wallet, material) in [
      (safetyWallet(hot: true), RecoveryMaterialType.mnemonic),
      (_multisig(), RecoveryMaterialType.multisigRecoveryMaterial),
    ]) {
      wallets.walletItemListNotifier.value = [wallet];
      await provider.recordRecoveryReview('1:known', RecoveryReviewStatus.completedByUser);
      final saved = store.state.incidents.single;
      expect((saved.recoveryReview, saved.recoveryMaterial), (RecoveryReviewStatus.completedByUser, material));
    }
    await expectLater(
      provider.recordRecoveryReview('1:missing', RecoveryReviewStatus.completedByUser),
      throwsStateError,
    );
  });
  testWidgets('h-notation descriptor hashes match the original stored wallet descriptor', (tester) async {
    final body = wallets.walletItemList.single.descriptor.split('#').first.replaceAll("'", 'h');
    final descriptor = '$body#${Checksum.getChecksum(body)}';
    wallets.walletItemListNotifier.value = [
      SinglesigWalletItem(id: 1, name: 'H notation', colorIndex: 0, iconIndex: 0, descriptor: descriptor),
    ];
    create(tester);
    await settle(tester);
    await provider.recordWatchOnlyVerification(
      1,
      method: VerificationMethod.qr,
      result: VerificationResult.match,
      matchedIndex: 0,
    );
    final inputs = SafetyInputsCollector(
      walletProvider: wallets,
      nodeProvider: node,
      authProvider: auth,
      connectivityProvider: connectivity,
      realmManager: realm,
    ).collect(state: provider.state, now: DateTime(2026));
    expect(store.state.watchOnlyVerifications[1]!.descriptorHash, inputs.wallets.single.descriptorHash);
    expect(inputs.wallets.single.descriptorHash, WalletVerification.descriptorHash(descriptor));
    expect(provider.report!.allGoodItems.any((item) => item.id == SafetyCheckId.watchOnlyVerify), isTrue);
  });
  testWidgets('failed persistence does not report a completed incident response', (tester) async {
    store.state = SafetyState(incidents: [incident('known')]);
    wallets.records[1] = [safetyTx('known')];
    create(tester);
    await settle(tester);
    store.failWrites = true;
    await expectLater(provider.markIncidentUnrecognized('1:known', IncidentResponseMode.free), throwsStateError);
    expect(analytics.events, isEmpty);
    expect(provider.state.incidents.single.state, IncidentState.detected);
  });
  testWidgets('checkAgain reconnects, coalesces duplicate requests, and lasts at least 1.2 seconds', (tester) async {
    create(tester);
    await settle(tester);
    final first = provider.checkAgain();
    expect(provider.checkAgain(), same(first));
    await tester.pump(const Duration(milliseconds: 1199));
    expect(provider.isChecking, isTrue);
    expect(node.reconnects, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await first;
    expect(provider.isChecking, isFalse);
    expect(analytics.events.map((event) => event.name), [
      AnalyticsEventNames.safetyCheckStarted,
      AnalyticsEventNames.safetyCheckCompleted,
    ]);
    expect(analytics.events.every((event) => event.parameters == null), isTrue);
  });
  testWidgets('checkAgain publishes its shared future before listeners can reenter', (tester) async {
    create(tester);
    await settle(tester);
    Future<void>? reentered;
    var entered = false;
    provider.addListener(() {
      if (!entered && provider.isChecking) {
        entered = true;
        reentered = provider.checkAgain();
      }
    });
    final first = provider.checkAgain();
    expect(entered, isTrue);
    expect(reentered, same(first));
    await tester.pump(const Duration(milliseconds: 1200));
    await first;
    expect(node.reconnects, 1);
    expect(analytics.events.map((event) => event.name), [
      AnalyticsEventNames.safetyCheckStarted,
      AnalyticsEventNames.safetyCheckCompleted,
    ]);
  });
  testWidgets('refresh publishes its shared future before listeners can reenter', (tester) async {
    create(tester);
    await settle(tester);
    Future<void>? reentered;
    var entered = false;
    provider.addListener(() {
      if (!entered) {
        entered = true;
        reentered = provider.refresh();
      }
    });
    auth.enabled = false;
    final first = provider.refresh();
    expect(entered, isTrue);
    expect(reentered, same(first));
    await first;
    expect(provider.report!.reviewItems.any((item) => item.id == SafetyCheckId.appLock), isTrue);
  });
  testWidgets('back-to-back refreshes keep changes made after an evaluation body finishes', (tester) async {
    create(tester);
    await settle(tester);
    auth.enabled = false;
    final first = provider.refresh();
    auth.enabled = true;
    final second = provider.refresh();
    await Future.wait([first, second]);
    expect(provider.report!.allGoodItems.any((item) => item.id == SafetyCheckId.appLock), isTrue);
  });
  testWidgets('checkAgain still evaluates stored data when network checks fail', (tester) async {
    node.reconnectThrows = true;
    create(tester, checksThrow: true);
    await settle(tester);
    final done = provider.checkAgain();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await done;
    expect(provider.isChecking, isFalse);
    expect(provider.report, isNotNull);
  });
  testWidgets('WalletRemoved cleans persisted state', (tester) async {
    create(tester);
    await settle(tester);
    await provider.setCaution(1, true);
    wallets.walletItemListNotifier.value = [];
    wallets.events.add(const WalletRemoved(1));
    await tester.pump();
    await settle(tester);
    expect(store.removed, [1]);
    expect(store.state.cautionWalletIds, isEmpty);
    expect(store.state.baselines, isEmpty);
    expect(provider.report!.status, WalletHealthStatus.noWallet);
  });
  testWidgets('fixed report only counts unread critical and action needed, never recommended or info', (tester) async {
    create(tester);
    await settle(tester);
    final info = incident('dropped').withTxState(IncidentTxState.dropped);
    final fixed = SafetyProvider.fixed(
      WalletHealthReport(
        status: WalletHealthStatus.notEnoughData,
        profile: WeightProfile.watchOnlyOnly,
        evaluatedAt: DateTime(2026),
        infoIncidents: [info],
        recommended: const [RecommendedItem(id: RecommendedCheckId.hotPhysicalBackup)],
        reviewItems: const [
          SafetyCheckResult(SafetyCheckId.metadataBackup, SafetyOutcome.failed, severity: SafetySeverity.recommended),
        ],
      ),
    );
    expect(fixed.alertItems.length, 1);
    expect(fixed.hasUnreadAlerts, isFalse);
    fixed.dispose();
    final action = SafetyProvider.fixed(
      WalletHealthReport(
        status: WalletHealthStatus.notEnoughData,
        profile: WeightProfile.watchOnlyOnly,
        evaluatedAt: DateTime(2026),
        reviewItems: const [
          SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.failed, severity: SafetySeverity.actionNeeded),
        ],
      ),
    );
    expect(action.hasUnreadAlerts, isTrue);
    await action.markAlertsRead();
    expect(action.hasUnreadAlerts, isFalse);
    action.dispose();
  });
  testWidgets('full release version comparison includes minor and patch and ignores build metadata', (tester) async {
    create(tester);
    await settle(tester);
    expect(SafetyProvider.compareAppVersions('0.20.0', '0.20.1'), AppUpdateStatus.available);
    expect(SafetyProvider.compareAppVersions('0.20.9', '0.21.0'), AppUpdateStatus.available);
    expect(SafetyProvider.compareAppVersions('1.0.0', '0.99.0'), AppUpdateStatus.upToDate);
    expect(SafetyProvider.compareAppVersions('0.20.0+90', '0.20.0+91'), AppUpdateStatus.upToDate);
    expect(SafetyProvider.compareAppVersions('invalid', '0.20.0'), AppUpdateStatus.unknown);
    expect(SafetyProvider.compareAppVersions('0.20.0', 'garbage'), AppUpdateStatus.unknown);
  });
}
