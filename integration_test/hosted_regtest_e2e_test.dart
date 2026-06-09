import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/wallet_home_screen.dart';
import 'package:coconut_wallet/services/faucet_service.dart';
import 'package:coconut_wallet/services/model/error/default_error_response.dart';
import 'package:coconut_wallet/services/model/request/faucet_request.dart';
import 'package:coconut_wallet/services/model/response/faucet_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'integration_test_utils.dart';
import 'package:coconut_wallet/main.dart' as app;

const int _minimumSendSats = 10000;
const double _feeRate = 1.0;

/// Hosted NonceLab regtest end-to-end smoke test.
///
/// This test intentionally does not print seed material, raw PSBTs, signed
/// transactions, or private keys. It only records public txids on failure.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late RealmManager realmManager;

  setUp(() async {
    realmManager = RealmManager();
    realmManager.reset();

    final prefs = SharedPrefsRepository();
    await prefs.init();
    await prefs.clearSharedPref();
    await SecureStorageRepository().deleteAll();
    await skipTutorial(true);
  });

  tearDown(() async {
    realmManager.realm.close();
  });

  testWidgets('fund, sign, and broadcast via hosted regtest', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    final walletHomeScreen = find.byType(WalletHomeScreen);
    await waitForWidget(
      tester,
      walletHomeScreen,
      timeoutMessage: 'WalletHomeScreen not found after 60 seconds',
    );

    final context = tester.element(walletHomeScreen);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final nodeProvider = Provider.of<NodeProvider>(context, listen: false);
    final utxoRepository = Provider.of<UtxoRepository>(context, listen: false);

    await _waitForNodeReady(nodeProvider);

    final fundingVault = SingleSignatureVault.random(
      addressType: AddressType.p2wpkh,
    );
    final recipientVault = SingleSignatureVault.random(
      addressType: AddressType.p2wpkh,
    );

    final addResult = await walletProvider.syncFromCoconutVault(
      WatchOnlyWallet(
        'hosted regtest e2e',
        0,
        0,
        fundingVault.descriptor,
        null,
        null,
        WalletImportSource.coconutVault.name,
      ),
    );

    expect(addResult.result, WalletSyncResult.newWalletAdded);
    expect(addResult.walletId, isNotNull);

    final walletId = addResult.walletId!;
    final wallet = walletProvider.getWalletById(walletId);
    final receiveAddress = walletProvider.getReceiveAddress(walletId).address;

    final subscribeResult = await nodeProvider.subscribeWallet(wallet);
    expect(
      subscribeResult.isSuccess,
      true,
      reason: 'wallet subscription failed',
    );

    final faucet = Faucet();
    final faucetStatus = await faucet.getStatus();
    expect(faucetStatus.totalBalance, greaterThan(0));

    final faucetAmountBtc = _selectFaucetAmount(
      faucetStatus.minLimit,
      faucetStatus.maxLimit,
    );
    final faucetResponse = await faucet.getTestCoin(
      FaucetRequest(address: receiveAddress, amount: faucetAmountBtc),
    );

    if (faucetResponse is DefaultErrorResponse) {
      fail('faucet rejected request: ${faucetResponse.message}');
    }
    expect(faucetResponse, isA<FaucetResponse>());
    final fundingTxHash = (faucetResponse as FaucetResponse).txHash;
    expect(fundingTxHash, isNotEmpty);
    printOnFailure('funding txid: $fundingTxHash');

    final fundedUtxos = await _waitForFundedUtxos(
      nodeProvider: nodeProvider,
      utxoRepository: utxoRepository,
      walletId: walletId,
      wallet: wallet,
    );

    final totalInputSats = fundedUtxos.fold<int>(
      0,
      (sum, utxo) => sum + utxo.amount,
    );
    expect(totalInputSats, greaterThan(_minimumSendSats));

    final sendAmountSats = _selectSendAmount(totalInputSats);
    final changeDerivationPath = '${fundingVault.derivationPath}/1/0';
    final transactionBuildResult =
        TransactionBuilder(
          availableUtxos: fundedUtxos,
          recipients: {recipientVault.getAddress(0): sendAmountSats},
          feeRate: _feeRate,
          changeDerivationPath: changeDerivationPath,
          walletListItemBase: wallet,
          isFeeSubtractedFromAmount: false,
          isUtxoFixed: true,
        ).build();

    expect(
      transactionBuildResult.isSuccess,
      true,
      reason: transactionBuildResult.exception?.toString(),
    );

    final unsignedPsbt = Psbt.fromTransaction(
      transactionBuildResult.transaction!,
      wallet.walletBase,
    );
    final signedPsbt = fundingVault.addSignatureToPsbt(
      unsignedPsbt.serialize(),
    );
    final signedTransaction = Psbt.parse(
      signedPsbt,
    ).getSignedTransaction(wallet.walletType.addressType);

    final broadcastResult = await nodeProvider.broadcast(signedTransaction);
    expect(
      broadcastResult.isSuccess,
      true,
      reason: broadcastResult.isFailure ? broadcastResult.error.message : null,
    );
    printOnFailure('broadcast txid: ${broadcastResult.value}');

    final broadcastedTx = await nodeProvider.getTransaction(
      broadcastResult.value,
    );
    expect(
      broadcastedTx.isSuccess,
      true,
      reason: broadcastedTx.isFailure ? broadcastedTx.error.message : null,
    );
  });
}

Future<void> _waitForNodeReady(NodeProvider nodeProvider) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  Object? lastError;

  while (DateTime.now().isBefore(deadline)) {
    try {
      await nodeProvider.initialize();
      final blockResult = await nodeProvider.getLatestBlock();
      if (blockResult.isSuccess && blockResult.value.height > 0) {
        return;
      }
      if (blockResult.isFailure) {
        lastError = blockResult.error.message;
      }
    } catch (error) {
      lastError = error;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  fail('node did not become ready within 60 seconds: $lastError');
}

Future<List<UtxoState>> _waitForFundedUtxos({
  required NodeProvider nodeProvider,
  required UtxoRepository utxoRepository,
  required int walletId,
  required WalletListItemBase wallet,
}) async {
  final deadline = DateTime.now().add(const Duration(minutes: 3));

  while (DateTime.now().isBefore(deadline)) {
    await nodeProvider.subscribeWallet(wallet);
    final walletState = nodeProvider.state.registeredWallets[walletId];
    final utxos =
        utxoRepository
            .getUtxoStateList(walletId)
            .where(
              (utxo) =>
                  utxo.amount > 0 &&
                  utxo.status != UtxoStatus.outgoing &&
                  utxo.status != UtxoStatus.locked,
            )
            .toList();

    if (utxos.isNotEmpty && walletState?.utxo == WalletSyncState.completed) {
      return utxos;
    }

    await Future<void>.delayed(const Duration(seconds: 5));
  }

  fail('no funded hosted-regtest UTXO appeared within 3 minutes');
}

double _selectFaucetAmount(double minLimit, double maxLimit) {
  final lowerBound = minLimit > 0 ? minLimit : 0.001;
  final upperBound = maxLimit > 0 ? maxLimit : lowerBound;
  final desired = lowerBound < 0.001 ? 0.001 : lowerBound;
  return desired > upperBound ? upperBound : desired;
}

int _selectSendAmount(int totalInputSats) {
  final half = totalInputSats ~/ 2;
  if (half > _minimumSendSats) {
    return half;
  }
  return _minimumSendSats;
}
