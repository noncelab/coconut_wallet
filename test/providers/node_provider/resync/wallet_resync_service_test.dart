import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/resync/wallet_resync_service.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../services/shared_prefs_service_test.mocks.dart';

/// 재동기화 실패가 다른 경로(NodeProvider.raceResyncAgainstConnectionLoss, node_provider_test.dart 참고)로
/// 조기 반환된 뒤에도, 백그라운드 isolate에는 이전 시도가 여전히 살아있을 수 있다(취소하지 않으므로).
/// 이 상태에서 사용자가 "다시 시도"를 눌러 같은 지갑에 대해 resyncWallet이 다시 호출돼도, 두 번째
/// 호출이 wipe/prefill/scan을 별도로 다시 시작해서 같은 Realm 데이터를 동시에 건드리면 안 된다
/// (.claude/HANDOFF_2026-08-21.md 6번 항목, 어제 발견된 크래시/ANR과 같은 유형의 레이스).
void main() {
  const walletId = 902;

  group('WalletResyncService 지갑별 직렬화 가드 테스트', () {
    setUp(() {
      ScriptSyncServiceMock.init();
    });

    tearDown(() {
      ScriptSyncServiceMock.realmManager?.reset();
      ScriptSyncServiceMock.realmManager?.dispose();
    });

    test('같은 지갑에 대해 겹쳐 들어온 두 번째 resyncWallet 호출은 새로 시작하지 않고 첫 번째 결과를 그대로 공유한다', () async {
      // Given
      final wallet = WalletMock.createSingleSigWalletItem(id: walletId, name: 'resync_guard_wallet');

      final sharedPrefsRepository = SharedPrefsRepository()..setSharedPreferencesForTest(MockSharedPreferences());
      when(sharedPrefsRepository.getInt(SharedPrefKeys.kNextIdField)).thenAnswer((_) => wallet.id);
      when(sharedPrefsRepository.setInt(SharedPrefKeys.kNextIdField, wallet.id + 1)).thenAnswer((_) async => true);

      await ScriptSyncServiceMock.walletRepository.addSinglesigWallet(
        WatchOnlyWallet(
          wallet.name,
          wallet.colorIndex,
          wallet.iconIndex,
          wallet.descriptor,
          null,
          null,
          WalletImportSource.coconutVault.name,
        ),
      );
      await ScriptSyncServiceMock.addressRepository.ensureAddressesInit(walletItemBase: wallet);

      final electrumService = ScriptSyncServiceMock.electrumService;
      when(electrumService.subscribeScript(any, any, onUpdate: anyNamed('onUpdate'))).thenAnswer((_) async => null);

      final subscriptionService = SubscriptionService(
        electrumService,
        ScriptSyncServiceMock.stateManager,
        ScriptSyncServiceMock.addressRepository,
        SubscriptionRepository(ScriptSyncServiceMock.realmManager!),
        ScriptSyncServiceMock.createMockScriptSyncService(),
      );

      final resyncService = WalletResyncService(
        ScriptSyncServiceMock.walletRepository,
        ScriptSyncServiceMock.utxoRepository,
        ScriptSyncServiceMock.addressRepository,
        subscriptionService,
        IsolateStateManager(null),
        ScriptSyncServiceMock.scriptCallbackService,
      );

      // When: 두 호출 사이에 await 없이(동기 구간에서) 바로 겹쳐서 호출한다 — 첫 번째 호출이
      // 첫 await에 도달하며 지갑을 "재동기화 중"으로 등록한 뒤에야 두 번째 호출로 넘어온다.
      final firstCall = resyncService.resyncWallet(wallet);
      final secondCall = resyncService.resyncWallet(wallet);

      final results = await Future.wait([firstCall, secondCall]);

      // Then: 두 번째 호출이 별도로 wipe/scan을 다시 시작한 게 아니라, 첫 번째 호출과 정확히
      // 같은 Result 인스턴스를 그대로 돌려받아야 한다(따로 실행됐다면 서로 다른 인스턴스가 된다).
      expect(results[0].isSuccess, true);
      expect(identical(results[0], results[1]), true, reason: '두 번째 호출은 첫 번째 결과를 그대로 공유해야 한다(중복 실행 금지).');
    });
  });
}
