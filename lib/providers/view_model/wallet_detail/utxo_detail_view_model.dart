import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/mempool_api_service.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class UtxoDetailViewModel extends ChangeNotifier {
  static const int kInputMaxCount = 3;
  static const int kOutputMaxCount = 2;

  late final int _walletId;
  late final String _utxoId;
  late UtxoState _utxo;
  late final String _txHash;
  late final UtxoTagProvider _tagProvider;
  late final TransactionProvider _txProvider;
  late final WalletProvider _walletProvider;
  late final AddressRepository _addressRepository;
  late final BlockExplorerProvider _blockExplorerProvider;
  final Stream<WalletUpdateInfo> _syncWalletStateStream;
  StreamSubscription<WalletUpdateInfo>? _syncWalletStateSubscription;

  bool _isFetchingFromMempool = false;
  bool _disposed = false;

  List<UtxoTag> _utxoTagList = [];
  List<UtxoTag> _appliedUtxoTagList = [];
  late List<String> _dateString;
  TransactionRecord? _transaction;

  int _utxoInputMaxCount = 0;
  int _utxoOutputMaxCount = 0;

  String get mempoolHost => _blockExplorerProvider.blockExplorerUrl;
  bool get isFetchingFromMempool => _isFetchingFromMempool;
  List<UtxoTag> get appliedUtxoTagList => _appliedUtxoTagList;
  String get walletName => _walletProvider.getWalletById(_walletId).name;
  String get walletNameDisplay => TextUtils.ellipsisIfLonger(walletName, maxLength: 15);

  UtxoDetailViewModel(
    this._walletId,
    this._utxo,
    this._tagProvider,
    this._txProvider,
    this._walletProvider,
    this._addressRepository,
    this._syncWalletStateStream,
    this._blockExplorerProvider,
  ) {
    _txHash = _utxo.transactionHash;
    _utxoId = _utxo.utxoId;
    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);
    _appliedUtxoTagList = _tagProvider.getUtxoTagsByUtxoId(_walletId, _utxoId);
    _syncTransactionDisplayState();

    if (_transaction != null && _transaction!.inputAddressList.isEmpty && !_isFetchingFromMempool) {
      _fetchTransactionFromMempoolAndUpdate();
    }

    _syncWalletStateSubscription = _syncWalletStateStream.listen(_onWalletUpdate);
  }

  void _onWalletUpdate(WalletUpdateInfo info) {
    final updatedUtxo = _walletProvider.getUtxoState(_walletId, _utxoId);
    if (updatedUtxo != null) {
      _utxo = updatedUtxo;
      notifyListeners();
    }
  }

  UtxoStatus _setUtxoStateToggled() {
    if (_utxo.status == UtxoStatus.locked) {
      return UtxoStatus.unspent;
    } else if (_utxo.status == UtxoStatus.unspent) {
      return UtxoStatus.locked;
    }
    return _utxo.status;
  }

  Future<bool> toggleUtxoLockStatus() async {
    try {
      await _walletProvider.toggleUtxoLockStatus(_walletId, _utxo.utxoId);
    } catch (e) {
      Logger.error('❌ toggleUtxoLockStatus error: $e');
      return false;
    }

    _utxo.status = _setUtxoStateToggled();
    notifyListeners();
    return true;
  }

  List<String> get dateString => _dateString;
  List<UtxoTag> get selectedUtxoTagList => _appliedUtxoTagList;
  UtxoTagProvider? get tagProvider => _tagProvider;

  TransactionRecord? get transaction => _transaction;

  void _syncTransactionDisplayState() {
    _transaction = _txProvider.getTransaction(_walletId, _utxo.transactionHash);
    _dateString = _transaction != null ? DateTimeUtil.formatTimestamp(_transaction!.timestamp) : ['-', '-'];
    _initUtxoInOutputList();
  }

  void refreshTransaction() {
    _syncTransactionDisplayState();
    if (_transaction != null && _transaction!.inputAddressList.isEmpty && !_isFetchingFromMempool) {
      _fetchTransactionFromMempoolAndUpdate();
    }
    notifyListeners();
  }

  void _safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _fetchTransactionFromMempoolAndUpdate() async {
    if (_disposed) return;

    _isFetchingFromMempool = true;
    _safeNotifyListeners();
    final mempoolApi = MempoolApi();
    try {
      final txJson = await mempoolApi.fetchTx(_txHash);

      if (_disposed) return;

      final currentTx = _txProvider.getTransactionRecord(_walletId, _txHash);
      final txRecord = _transactionRecordFromMempoolResponse(txJson, currentTx);
      if (txRecord != null) {
        await _txProvider.updateTransaction(_walletId, _txHash, txRecord);
        _syncTransactionDisplayState();
      }
    } catch (e) {
      Logger.error('[_fetchTransactionFromMempool] Failed to fetch tx from mempool: $_txHash, error=$e');
    } finally {
      mempoolApi.close();
      _isFetchingFromMempool = false;
      if (!_disposed) _safeNotifyListeners();
    }
  }

  TransactionRecord? _transactionRecordFromMempoolResponse(Map<String, dynamic> txJson, TransactionRecord? existingTx) {
    try {
      final txid = txJson['txid'] as String? ?? _txHash;
      final vin = txJson['vin'] as List<dynamic>? ?? [];
      final vout = txJson['vout'] as List<dynamic>? ?? [];
      final fee = (txJson['fee'] as num?)?.toInt() ?? 0;
      final weight = (txJson['weight'] as num?)?.toDouble() ?? 0;
      final vSize = weight > 0 ? weight / 4 : 0.0;

      final status = txJson['status'] as Map<String, dynamic>?;
      final blockHeight = (status?['block_height'] as num?)?.toInt() ?? 0;
      final blockTime = (status?['block_time'] as num?)?.toInt();
      final timestamp =
          blockTime != null
              ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000, isUtc: true).toLocal()
              : (existingTx?.timestamp ?? DateTime.now());

      final inputAddressList = <TransactionAddress>[];
      int selfInputCount = 0;
      int amount = 0;

      for (final input in vin) {
        final prevout = input is Map ? input['prevout'] as Map<String, dynamic>? : null;
        if (prevout == null) continue;

        final address = prevout['scriptpubkey_address'] as String? ?? '';
        final value = (prevout['value'] as num?)?.toInt() ?? 0;
        inputAddressList.add(TransactionAddress(address, value));

        if (_addressRepository.containsAddress(_walletId, address)) {
          selfInputCount++;
          amount -= value;
        }
      }

      final outputAddressList = <TransactionAddress>[];
      int selfOutputCount = 0;

      for (final output in vout) {
        final address = output is Map ? output['scriptpubkey_address'] as String? ?? '' : '';
        final value = output is Map ? (output['value'] as num?)?.toInt() ?? 0 : 0;
        outputAddressList.add(TransactionAddress(address, value));

        if (_addressRepository.containsAddress(_walletId, address)) {
          selfOutputCount++;
          amount += value;
        }
      }

      final txType = _determineTransactionType(
        selfInputCount,
        selfOutputCount,
        inputAddressList.length,
        outputAddressList.length,
      );

      return TransactionRecord(
        txid,
        timestamp,
        blockHeight,
        txType,
        existingTx?.memo,
        amount,
        fee,
        inputAddressList,
        outputAddressList,
        vSize,
        existingTx?.createdAt ?? DateTime.now(),
        rbfHistoryList: existingTx?.rbfHistoryList,
        cpfpHistory: existingTx?.cpfpHistory,
      );
    } catch (e) {
      Logger.error('[_transactionRecordFromMempoolResponse] Failed to parse: $e');
      return null;
    }
  }

  TransactionType _determineTransactionType(int selfInputCount, int selfOutputCount, int inputCount, int outputCount) {
    if (selfInputCount == 0) return TransactionType.received;
    if (selfOutputCount < outputCount) return TransactionType.sent;
    if (selfOutputCount == outputCount && selfInputCount == inputCount) return TransactionType.self;
    return TransactionType.received;
  }

  int get utxoInputMaxCount => _utxoInputMaxCount;
  int get utxoOutputMaxCount => _utxoOutputMaxCount;
  List<UtxoTag> get utxoTagList => _utxoTagList;
  UtxoStatus get utxoStatus => _utxo.status;

  String getInputAddress(int index) => TransactionUtil.getInputAddress(_transaction, index);
  int getInputAmount(int index) => TransactionUtil.getInputAmount(_transaction, index);
  String getOutputAddress(int index) => TransactionUtil.getOutputAddress(_transaction, index);
  int getOutputAmount(int index) => TransactionUtil.getOutputAmount(_transaction, index);

  void _initUtxoInOutputList() {
    final tx = _transaction;
    if (tx == null) return;

    _utxoInputMaxCount = tx.inputAddressList.length <= kInputMaxCount ? tx.inputAddressList.length : kInputMaxCount;
    _utxoOutputMaxCount =
        tx.outputAddressList.length <= kOutputMaxCount ? tx.outputAddressList.length : kOutputMaxCount;
    if (tx.inputAddressList.length <= utxoInputMaxCount) {
      _utxoInputMaxCount = tx.inputAddressList.length;
    }
    if (tx.outputAddressList.length <= utxoOutputMaxCount) {
      _utxoOutputMaxCount = tx.outputAddressList.length;
    }
  }

  List<UtxoTag> refreshTagList() {
    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);
    _appliedUtxoTagList = _tagProvider.getUtxoTagsByUtxoId(_walletId, _utxoId);
    _safeNotifyListeners();
    return _utxoTagList;
  }

  @override
  void dispose() {
    _disposed = true;
    _syncWalletStateSubscription?.cancel();
    super.dispose();
  }
}
