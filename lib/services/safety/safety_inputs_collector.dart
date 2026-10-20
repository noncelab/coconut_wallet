import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/converter/transaction.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';

class SafetyInputsCollector {
  SafetyInputsCollector({
    required WalletProvider walletProvider,
    required NodeProvider nodeProvider,
    required AuthProvider authProvider,
    required ConnectivityProvider connectivityProvider,
    required RealmManager realmManager,
  }) : _wallets = walletProvider,
       _node = nodeProvider,
       _auth = authProvider,
       _connectivity = connectivityProvider,
       _realm = realmManager;

  final WalletProvider _wallets;
  final NodeProvider _node;
  final AuthProvider _auth;
  final ConnectivityProvider _connectivity;
  final RealmManager _realm;

  SafetyInputs collect({
    required SafetyState state,
    required DateTime now,
    AppUpdateStatus appUpdate = AppUpdateStatus.unknown,
    ServerCertObservation? serverCert,
  }) {
    _realm.realm.refresh();
    final connected = _node.isConnected && _connectivity.isInternetOn;
    var tagCount = 0;
    var memoCount = 0;
    final snapshots = <SafetyWalletSnapshot>[];
    for (final wallet in _wallets.walletItemList) {
      final id = wallet.id;
      final listed = _wallets.getTransactionRecordList(id);
      final listedTxids = {for (final tx in listed) tx.transactionHash};
      // 대체 표시가 남은 채로 실제 확정된 원거래도 본다. 확정돼도 replaceByTransactionHash가 지워지지 않아(transaction_repository.dart:256)
      // 목록 조회(:24)에서 빠지기 때문(리뷰 R3)
      final records = [
        ...listed,
        for (final row in _realm.realm.query<RealmTransaction>(
          r'walletId == $0 AND replaceByTransactionHash != null AND blockHeight > 0',
          [id],
        ))
          if (!listedTxids.contains(row.transactionHash)) mapRealmTransactionToTransaction(row),
      ];
      final utxos = _wallets.getUtxoList(id);
      final ownReceive = <String, bool>{};
      final receivedByAddress = <String, Set<String>>{};
      final txs = <SafetyTx>[];
      for (final tx in records) {
        final receiveOutputs = <String>{};
        for (final output in tx.outputAddressList) {
          if (output.amount > 0 &&
              ownReceive.putIfAbsent(
                output.address,
                () => _wallets.containsAddress(id, output.address, isChange: false),
              )) {
            receiveOutputs.add(output.address);
            receivedByAddress.putIfAbsent(output.address, () => {}).add(tx.transactionHash);
          }
        }
        txs.add((
          txid: tx.transactionHash,
          type: tx.transactionType,
          blockHeight: tx.blockHeight,
          amount: tx.amount,
          timestamp: tx.timestamp,
          createdAt: tx.createdAt,
          ownReceiveOutputs: receiveOutputs,
        ));
      }
      final currentTxids = txs.map((tx) => tx.txid).toSet();
      final trackedTxStates = <String, IncidentTxState>{};
      for (final incident in state.incidents.where((incident) => incident.walletId == id && incident.isOpen)) {
        if (!currentTxids.contains(incident.txid)) {
          final row = _wallets.getTransactionRecord(id, incident.txid);
          trackedTxStates[incident.txid] =
              row == null
                  ? IncidentTxState.dropped
                  : row.blockHeight > 0
                  ? IncidentTxState.confirmed
                  : IncidentTxState.replaced;
        }
      }
      final unspentAddresses = utxos.where((utxo) => utxo.status != UtxoStatus.outgoing).map((u) => u.to).toSet();
      final byHash = {for (final tx in records) tx.transactionHash: tx};
      final update = _node.state.registeredWallets[id];
      snapshots.add(
        SafetyWalletSnapshot(
          id: id,
          kind: _kind(wallet),
          balanceSats: _wallets.getWalletBalance(id).total,
          isSettled:
              connected &&
              _node.currentBlockHeight > 0 &&
              update != null &&
              update.subscription == WalletSyncState.completed &&
              update.balance == WalletSyncState.completed &&
              update.transaction == WalletSyncState.completed &&
              update.utxo == WalletSyncState.completed,
          lastResyncAt: _node.getLastResyncTimestamp(id),
          txs: txs,
          pendingSpentByTxids: {
            for (final utxo in utxos)
              if (utxo.status == UtxoStatus.outgoing && utxo.spentByTransactionHash != null)
                utxo.spentByTransactionHash!,
          },
          trackedTxStates: trackedTxStates,
          backupVerified: wallet.hotWalletMetadata?.backupVerified ?? false,
          passphraseOnSigning: wallet.hotWalletMetadata?.enterPassphraseWhenSigning ?? false,
          hasMfp: !isWalletWithoutMfp(wallet),
          descriptorHash: WalletVerification.descriptorHash(wallet.descriptor),
          multisigConfig: wallet is MultisigWalletItem ? _multisigConfig(wallet) : null,
          reusedAddressesWithUtxo: [
            for (final entry in receivedByAddress.entries)
              if (entry.value.length >= 2 && unspentAddresses.contains(entry.key)) entry.key,
          ]..sort(),
          unlockedDustUtxoIds: [
            for (final utxo in utxos)
              if (utxo.status != UtxoStatus.locked &&
                  utxo.status != UtxoStatus.outgoing &&
                  _wallets.isUtxoSuspicious(utxo, byHash[utxo.transactionHash]))
                utxo.utxoId,
          ]..sort(),
          hasReceiveHistory: txs.any((tx) => tx.type == TransactionType.received),
          hasUtxoHistory: utxos.isNotEmpty || receivedByAddress.isNotEmpty,
        ),
      );
      tagCount += _wallets.getUtxoTags(id).fold<int>(0, (sum, tag) => sum + tag.utxoIdList.length);
      memoCount += _wallets.getAllTransactionMemos(id).where((memo) => memo.memo.isNotEmpty).length;
    }
    return SafetyInputs(
      now: now,
      wallets: snapshots,
      state: state,
      appLockEnabled: _auth.isAuthEnabled,
      appUpdate: appUpdate,
      serverCert: serverCert,
      isConnected: connected,
      currentBlockHeight: _node.currentBlockHeight,
      labelTagCount: tagCount,
      labelMemoCount: memoCount,
    );
  }

  SafetyWalletKind _kind(WalletItemBase wallet) {
    if (wallet.hasLocalKey) return SafetyWalletKind.hot;
    return switch (wallet.walletType) {
      WalletType.singleSignature => SafetyWalletKind.watchOnly,
      WalletType.multiSignature => SafetyWalletKind.multisig,
      WalletType.taproot => SafetyWalletKind.taproot,
    };
  }

  MultisigConfigStatus _multisigConfig(MultisigWalletItem wallet) {
    final signers = wallet.signerBsmsList;
    if (signers.length < 2 ||
        wallet.requiredSignatureCount < 1 ||
        wallet.requiredSignatureCount > signers.length ||
        wallet.signers.length != signers.length ||
        signers.any((s) => s.fingerprint.isEmpty || s.derivationPath.isEmpty || s.extendedKey.isEmpty)) {
      return MultisigConfigStatus.incomplete;
    }
    try {
      final rebuilt = MultisignatureVault.fromKeyStoreList(
        signers.map((signer) => KeyStore.fromSignerBsms(signer.getSignerBsms())).toList(),
        wallet.requiredSignatureCount,
      );
      return rebuilt.getAddress(0) == wallet.walletBase.getAddress(0)
          ? MultisigConfigStatus.complete
          : MultisigConfigStatus.mismatch;
    } catch (_) {
      return MultisigConfigStatus.incomplete;
    }
  }
}
