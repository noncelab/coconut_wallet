import 'package:coconut_wallet/constants/address.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../mock/script_sync_service_mock.dart';
import '../../../../mock/wallet_mock.dart';
import '../../../../services/shared_prefs_service_test.mocks.dart';

/// gap limit(kSubscriptionGapLimit) 밖의 주소를 스크롤로 조회했을 때, 그 주소에 잔액이 발견되면
/// usedIndex(모니터링 윈도우)는 그대로 둔 채 그 주소만 개별적으로 사용됨으로 표시하고
/// 구독 대상에 추가하는지 검증한다.
void main() {
  const walletId = 910;

  group('syncViewedAddresses 테스트', () {
    setUp(() {
      ScriptSyncServiceMock.init();
    });

    tearDown(() {
      ScriptSyncServiceMock.realmManager?.reset();
      ScriptSyncServiceMock.realmManager?.dispose();
    });

    test('gap 윈도우 밖 주소에서 잔액이 발견되면 usedIndex는 그대로 두고 그 주소만 사용됨 + 구독 대상으로 추가한다', () async {
      // Given: 지갑을 생성하고, gap 윈도우(0~19) 밖인 index 25 주소를 포함해 30개 주소를 미리 생성한다.
      final wallet = WalletMock.createSingleSigWalletItem(id: walletId, name: 'viewed_wallet');

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

      const farIndex = kSubscriptionGapLimit + 5; // 25, gap 윈도우(0~19) 밖
      await ScriptSyncServiceMock.addressRepository.ensureAddressesExist(
        walletItemBase: wallet,
        cursor: -1,
        count: farIndex + 5,
        isChange: false,
      );
      final addressList = await ScriptSyncServiceMock.addressRepository.getWalletAddressList(
        wallet,
        -1,
        farIndex + 5,
        false,
        false,
      );
      final farAddress = addressList.firstWhere((a) => a.index == farIndex);

      expect(farAddress.isUsed, isFalse, reason: '생성 직후에는 사용된 적 없는 주소여야 한다.');

      when(
        ScriptSyncServiceMock.electrumService.getBalance(any, farAddress.address),
      ).thenAnswer((_) async => GetBalanceRes(confirmed: 50000, unconfirmed: 0));

      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
      scriptSyncService.subscribeWallet = ScriptSyncServiceMock.subscribeWallet;
      scriptSyncService.unsubscribeAddress = ScriptSyncServiceMock.unsubscribeAddress;
      scriptSyncService.subscribeAddress = ScriptSyncServiceMock.subscribeAddress;

      // When: 사용자가 주소 목록 화면을 스크롤해 gap 윈도우 밖의 이 주소까지 조회한다.
      await scriptSyncService.syncViewedAddresses(wallet, [farAddress]);

      // Then: 주소는 사용됨으로 표시되고, 개별 구독 대상에 추가된다.
      expect(
        ScriptSyncServiceMock.addressRepository.isAddressActive(wallet.id, farAddress.address),
        isTrue,
        reason: '잔액이 발견됐으므로 주소 상태가 active여야 한다.',
      );
      expect(
        ScriptSyncServiceMock.subscribedAddresses,
        contains(farAddress.address),
        reason: 'gap 윈도우 밖이라도 잔액이 발견된 주소는 개별적으로 구독 대상에 추가되어야 한다.',
      );

      // But: usedIndex(모니터링 윈도우)는 옮겨지지 않는다.
      final refreshedWallet = ScriptSyncServiceMock.walletRepository.getWalletBase(wallet.id);
      expect(refreshedWallet.usedReceiveIndex, -1, reason: '모니터링 윈도우는 이동하지 않아야 한다(usedReceiveIndex 그대로).');
    });
  });
}
