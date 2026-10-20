import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/services/safety/incident_detector.dart';
import 'package:coconut_wallet/services/safety/safety_inputs_collector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repository/realm/test_realm_manager.dart';
import 'safety_fakes.dart';

/// 리뷰 R3: 로컬에서 대체 표시된 원거래 X가 실제로 확정되면(대기 X → Y가 대체 → X 확정) 감지에 들어와야 한다.
/// 저장소는 확정할 때 replaceByTransactionHash를 지우지 않는다(transaction_repository.dart:256) — 그 상태를 Realm에 직접 만든다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestRealmManager realm;
  late SafetyWalletsFake wallets;
  late SafetyNodeFake node;
  late SafetyAuthFake auth;
  late SafetyConnectivityFake connectivity;
  late SafetyInputsCollector collector;
  setUp(() {
    NetworkType.setNetworkType(NetworkType.testnet);
    realm = TestRealmManager();
    wallets = SafetyWalletsFake([safetyWallet()]);
    node = SafetyNodeFake();
    auth = SafetyAuthFake();
    connectivity = SafetyConnectivityFake();
    collector = SafetyInputsCollector(
      walletProvider: wallets,
      nodeProvider: node,
      authProvider: auth,
      connectivityProvider: connectivity,
      realmManager: realm,
    );
  });
  tearDown(() {
    wallets.dispose();
    node.dispose();
    auth.dispose();
    connectivity.dispose();
    realm.dispose();
  });

  void storeRow(String txid, {required int height, String? replacedBy}) {
    realm.realm.write(
      () => realm.realm.add(
        RealmTransaction(
          txid.hashCode,
          txid,
          1,
          DateTime(2026, 2),
          height,
          TransactionType.sent.name,
          1000,
          100,
          100,
          DateTime(2026),
          replaceByTransactionHash: replacedBy,
        ),
      ),
    );
  }

  SafetyInputs collect(SafetyState state) => collector.collect(state: state, now: DateTime(2026, 3));

  test('a confirmed original still marked replaced enters the snapshot as confirmed and becomes an incident', () {
    storeRow('x', height: 101, replacedBy: 'y'); // X 확정, 대체 표시 남음
    storeRow('z', height: 0, replacedBy: 'w'); // 대기 중 대체된 거래는 계속 빠진다
    wallets.records[1] = [safetyTx('y')]; // 목록 조회는 대체 표시 없는 것만
    final state = SafetyState(
      baselines: {1: WalletBaseline(height: 100, at: DateTime(2026))},
      appTxidPrefixes: const {'y'},
    );
    final inputs = collect(state);
    expect(inputs.wallets.single.txs.map((t) => (t.txid, t.type, t.blockHeight)), [
      ('y', TransactionType.sent, 0),
      ('x', TransactionType.sent, 101),
    ]);
    final created = IncidentDetector.detect(inputs).created;
    expect(created.map((i) => (i.txid, i.txState)), [('x', IncidentTxState.confirmed)]);
  });

  test('an open incident on such a tx is confirmed (critical), not replaced (info)', () {
    final incident = SafetyIncident(
      walletId: 1,
      txid: 'x',
      detectedAt: DateTime(2026),
      txState: IncidentTxState.replaced,
    );
    final state = SafetyState(baselines: {1: WalletBaseline(height: 100, at: DateTime(2026))}, incidents: [incident]);
    storeRow('x', height: 101, replacedBy: 'y');
    expect(IncidentDetector.detect(collect(state)).txStates, {'1:x': IncidentTxState.confirmed});
  });

  test('the tracked-incident fallback honours a retained row: confirmed, replaced or dropped', () {
    final state = SafetyState(incidents: [SafetyIncident(walletId: 1, txid: 'x', detectedAt: DateTime(2026))]);
    wallets.replaced['x'] = safetyTx('x', height: 101);
    expect(collect(state).wallets.single.trackedTxStates, {'x': IncidentTxState.confirmed});
    wallets.replaced['x'] = safetyTx('x');
    expect(collect(state).wallets.single.trackedTxStates, {'x': IncidentTxState.replaced});
    wallets.replaced.remove('x');
    expect(collect(state).wallets.single.trackedTxStates, {'x': IncidentTxState.dropped});
  });
}
