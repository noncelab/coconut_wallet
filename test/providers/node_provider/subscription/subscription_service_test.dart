import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../services/shared_prefs_service_test.mocks.dart';

/// _subscribeWallet의 "warm restart" 경로(사용 이력이 이미 알려진 지갑)가
/// dormant(사용됐지만 잔액 없는) 주소는 재구독하지 않고, 활성 사용 주소 + gap limit
/// 트레일링 윈도우만 구독하는지 검증한다.
void main() {
  const walletId = 901;

  group('SubscriptionService._subscribeWallet warm restart 테스트', () {
    setUp(() {
      ScriptSyncServiceMock.init();
    });

    tearDown(() {
      ScriptSyncServiceMock.realmManager?.reset();
      ScriptSyncServiceMock.realmManager?.dispose();
    });

    test('사용 이력이 이미 있는 지갑은 dormant 주소를 재구독하지 않고, 활성 주소 + gap 윈도우만 구독한다', () async {
      // Given: index 0(dormant, 잔액 0)과 index 1(active, 잔액 있음)이 이미 사용된 지갑.
      final wallet = WalletMock.createSingleSigWalletItem(id: walletId, name: 'warm_wallet');

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
      await ScriptSyncServiceMock.addressRepository.ensureAddressesExist(
        walletItemBase: wallet,
        cursor: 0,
        count: 25,
        isChange: false,
      );

      await ScriptSyncServiceMock.addressRepository.setWalletAddressUsed(wallet, 0, false);
      await ScriptSyncServiceMock.addressRepository.setWalletAddressUsed(wallet, 1, false);
      // index 0: dormant (사용됐지만 잔액 없음) - 기본값(confirmed=0, unconfirmed=0)이라 별도 조정 불필요.
      // index 1: active (잔액 있음)
      ScriptSyncServiceMock.addressRepository.updateAddressBalance(
        walletId: wallet.id,
        index: 1,
        isChange: false,
        balance: Balance(1000, 0),
      );

      wallet.receiveUsedIndex = 1;

      final electrumService = ScriptSyncServiceMock.electrumService;
      final subscribedAddresses = <String>[];
      when(electrumService.subscribeScript(any, any, onUpdate: anyNamed('onUpdate'))).thenAnswer((invocation) async {
        final address = invocation.positionalArguments[1] as String;
        subscribedAddresses.add(address);
        return null;
      });

      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
      final subscriptionRepository = SubscriptionRepository(ScriptSyncServiceMock.realmManager!);
      final subscriptionService = SubscriptionService(
        electrumService,
        ScriptSyncServiceMock.stateManager,
        ScriptSyncServiceMock.addressRepository,
        subscriptionRepository,
        scriptSyncService,
      );

      // When
      await subscriptionService.subscribeWallet(wallet);

      // Then
      final dormantAddress = wallet.walletBase.getAddress(0, isChange: false);
      final activeAddress = wallet.walletBase.getAddress(1, isChange: false);

      expect(subscribedAddresses.contains(dormantAddress), isFalse, reason: 'dormant 주소(index 0)는 재구독되면 안 된다.');
      expect(subscribedAddresses.contains(activeAddress), isTrue, reason: '활성 주소(index 1)는 구독되어야 한다.');

      // gap limit 트레일링 윈도우(index 2~21)는 구독되어야 한다.
      for (var i = 2; i <= 21; i++) {
        final address = wallet.walletBase.getAddress(i, isChange: false);
        expect(subscribedAddresses.contains(address), isTrue, reason: 'gap 윈도우 주소(index $i)는 구독되어야 한다.');
      }
    });
  });
}
