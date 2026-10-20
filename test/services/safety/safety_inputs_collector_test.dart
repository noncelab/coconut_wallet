import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/services/safety/safety_inputs_collector.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repository/realm/test_realm_manager.dart';
import 'safety_fakes.dart';

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
  SafetyInputs collect({SafetyState? state}) =>
      collector.collect(state: state ?? SafetyState.initial(), now: DateTime(2026));
  UtxoState utxo(String hash, String address, {UtxoStatus status = UtxoStatus.unspent, String? spentBy}) => UtxoState(
    transactionHash: WalletVerification.descriptorHash(hash),
    index: 0,
    amount: 500,
    derivationPath: "m/84'/1'/0'/0/0",
    blockHeight: 1,
    to: address,
    timestamp: DateTime(2026),
    status: status,
    spentByTransactionHash: spentBy,
  );

  test('uses combined balance, metadata flags, descriptor hash and resync timestamp', () {
    wallets.walletItemListNotifier.value = [safetyWallet(hot: true, backedUp: true, passphrase: true)];
    wallets.balances[1] = Balance(2000, 500);
    node.resync[1] = DateTime(2025);
    final snapshot = collect().wallets.single;
    expect(snapshot.kind, SafetyWalletKind.hot);
    expect(snapshot.balanceSats, 2500);
    expect(snapshot.backupVerified, isTrue);
    expect(snapshot.passphraseOnSigning, isTrue);
    expect(snapshot.hasMfp, isTrue);
    expect(snapshot.lastResyncAt, DateTime(2025));
    expect(snapshot.descriptorHash, WalletVerification.descriptorHash(wallets.walletItemList.single.descriptor));
  });
  test('height zero, offline, unregistered and syncing wallets cannot establish a baseline', () {
    expect(collect().wallets.single.isSettled, isTrue);
    node.height = 0;
    expect(collect().wallets.single.isSettled, isFalse);
    node.height = 100;
    node.connected = false;
    expect(collect().wallets.single.isSettled, isFalse);
    node.connected = true;
    connectivity.connected = false;
    expect(collect().isConnected, isFalse);
    expect(collect().wallets.single.isSettled, isFalse);
    connectivity.connected = true;
    node.state.registeredWallets[1]!.transaction = WalletSyncState.syncing;
    expect(collect().wallets.single.isSettled, isFalse);
    node.state.registeredWallets.clear();
    expect(collect().wallets.single.isSettled, isFalse);
  });
  test('address reuse counts distinct txids, excludes change, and needs a remaining UTXO', () {
    wallets.ownedReceive.addAll(['receive', 'spent']);
    wallets.records[1] = [
      safetyTx(
        'one',
        type: TransactionType.received,
        outputs: [
          TransactionAddress('receive', 10),
          TransactionAddress('receive', 20),
          TransactionAddress('spent', 30),
          TransactionAddress('change', 30),
        ],
      ),
      safetyTx(
        'two',
        type: TransactionType.received,
        outputs: [TransactionAddress('receive', 10), TransactionAddress('spent', 20), TransactionAddress('change', 30)],
      ),
    ];
    wallets.utxos[1] = [utxo('one', 'receive'), utxo('other', 'spent', status: UtxoStatus.outgoing)];
    final snapshot = collect().wallets.single;
    expect(snapshot.reusedAddressesWithUtxo, ['receive']);
    expect(snapshot.txs.first.ownReceiveOutputs, {'receive', 'spent'});
    expect(wallets.addressLookups, 3);
    expect(snapshot.hasReceiveHistory, isTrue);
    expect(snapshot.hasUtxoHistory, isTrue);
    wallets.records[1] = [wallets.records[1]!.first];
    expect(collect().wallets.single.reusedAddressesWithUtxo, isEmpty);
  });
  test('outgoing UTXO hashes supplement direction; locked and outgoing dust is excluded', () {
    final unlocked = utxo('dust', 'receive');
    final locked = utxo('locked', 'receive', status: UtxoStatus.locked);
    final outgoing = utxo('spent', 'receive', status: UtxoStatus.outgoing, spentBy: 'sent');
    wallets.utxos[1] = [unlocked, locked, outgoing];
    wallets.suspicious.addAll([unlocked.utxoId, locked.utxoId, outgoing.utxoId]);
    final snapshot = collect().wallets.single;
    expect(snapshot.pendingSpentByTxids, {'sent'});
    expect(snapshot.unlockedDustUtxoIds, [unlocked.utxoId]);
  });
  test('missing open incidents distinguish replaced records from dropped ones', () {
    wallets.replaced['replaced'] = safetyTx('replaced');
    final state = SafetyState(
      incidents: [
        for (final id in ['replaced', 'dropped']) SafetyIncident(walletId: 1, txid: id, detectedAt: DateTime(2026)),
      ],
    );
    expect(collect(state: state).wallets.single.trackedTxStates, {
      'replaced': IncidentTxState.replaced,
      'dropped': IncidentTxState.dropped,
    });
  });
  test('createdAt is retained instead of mutable confirmation timestamp', () {
    wallets.records[1] = [safetyTx('one', height: 101, createdAt: DateTime(2025))];
    expect(collect().wallets.single.txs.single.createdAt, DateTime(2025));
  });
  test('counts tag links and non-empty memos consistently with export', () {
    wallets.tags[1] = [
      RealmUtxoTag('tag', 1, 'Label', 0, DateTime(2026), utxoIdList: ['a', 'b']),
    ];
    wallets.memos[1] = [
      RealmTransactionMemo(1, 'a', 1, 'Memo', DateTime(2026)),
      RealmTransactionMemo(2, 'b', 1, '', DateTime(2026)),
    ];
    final inputs = collect();
    expect(inputs.labelTagCount, 2);
    expect(inputs.labelMemoCount, 1);
  });
  test('no wallet collection has only app inputs', () {
    wallets.walletItemListNotifier.value = [];
    auth.enabled = false;
    expect(collect().wallets, isEmpty);
    expect(collect().appLockEnabled, isFalse);
  });
  test('multisig complete configuration reconstructs the same first address', () {
    final keys = [
      for (final byte in [1, 2])
        KeyStore.fromSeed(Seed.fromEntropy(Uint8List.fromList(List.filled(16, byte))), AddressType.p2wsh),
    ];
    final multisig = MultisignatureVault.fromKeyStoreList(keys, 2);
    final wallet = MultisigWalletItem(
      id: 1,
      name: 'Multi',
      colorIndex: 0,
      iconIndex: 0,
      descriptor: multisig.descriptor,
      signers: [MultisigSigner(), MultisigSigner()],
      requiredSignatureCount: 2,
    );
    wallets.walletItemListNotifier.value = [wallet];
    expect(collect().wallets.single.multisigConfig, MultisigConfigStatus.complete);
    wallet.signers.removeLast();
    expect(collect().wallets.single.multisigConfig, MultisigConfigStatus.incomplete);
  });
  test('multisig configuration disagrees with the actual wallet', () {
    final keys = [
      for (final byte in [1, 2])
        KeyStore.fromSeed(Seed.fromEntropy(Uint8List.fromList(List.filled(16, byte))), AddressType.p2wsh),
    ];
    final multisig = MultisignatureVault.fromKeyStoreList(keys, 2);
    final wallet = MultisigWalletItem(
      id: 1,
      name: 'Multi',
      colorIndex: 0,
      iconIndex: 0,
      descriptor: multisig.descriptor,
      signers: [MultisigSigner(), MultisigSigner()],
      requiredSignatureCount: 1,
    );
    wallets.walletItemListNotifier.value = [wallet];
    expect(collect().wallets.single.multisigConfig, MultisigConfigStatus.mismatch);
  });
}
