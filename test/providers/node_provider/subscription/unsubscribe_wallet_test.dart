// Deleting a wallet must not silence another wallet that watches the same addresses (e.g. its watch-only copy).
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/wallet_mock.dart';

void main() {
  setUp(ScriptSyncServiceMock.init);
  tearDown(() {
    ScriptSyncServiceMock.realmManager?.dispose();
    ScriptSyncServiceMock.realmManager = null;
  });

  test('unsubscribeWallet removes only this wallet\'s subscriptions', () async {
    const walletId = 907;
    final wallet = WalletMock.createSingleSigWalletItem(id: walletId);
    final electrum = ScriptSyncServiceMock.electrumService;
    when(electrum.unsubscribeScriptForWallet(any, any, walletId: anyNamed('walletId'))).thenAnswer((_) async => true);
    final subscriptions = SubscriptionService(
      electrum,
      ScriptSyncServiceMock.stateManager,
      ScriptSyncServiceMock.addressRepository,
      SubscriptionRepository(ScriptSyncServiceMock.realmManager!),
      ScriptSyncServiceMock.createMockScriptSyncService(),
    );

    await subscriptions.unsubscribeWallet(wallet);

    verify(electrum.unsubscribeScriptForWallet(any, any, walletId: walletId)).called(greaterThan(0));
    verifyNever(electrum.unsubscribeScript(any, any));
  });
}
