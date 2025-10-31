import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_detail_screen.dart';
import 'package:coconut_wallet/services/block_explorer_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final String _txHash;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final TransactionProvider _txProvider;
  final AddressRepository _addressRepository;
  final ConnectivityProvider _connectivityProvider;
  final SendInfoProvider _sendInfoProvider;

  BlockTimestamp? _currentBlock;

  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);

  Utxo? _currentUtxo;
  List<TransactionRecord>? _transactionList;
  List<FeeHistory> _feeBumpingHistoryList = [];

  int _selectedTransactionIndex = 0; // RBF history chip 선택 인덱스
  int _previousTransactionIndex = 0; // 이전 인덱스 (애니메이션 방향 결정용)

  TransactionStatus? _transactionStatus = TransactionStatus.receiving;
  bool _isSendType = false;

  bool? _canBumpingTx;
  bool get canBumpingTx => _canBumpingTx == true;

  bool _disposed = false;
  bool get isDisposed => _disposed;

  String _mempoolHost = '';
  String get mempoolHost => _mempoolHost;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  TransactionDetailViewModel(
    this._walletId,
    this._txHash,
    this._walletProvider,
    this._txProvider,
    this._nodeProvider,
    this._addressRepository,
    this._connectivityProvider,
    this._sendInfoProvider,
  ) {
    _setCanBumpingTx();
    _initTransactionList();
    _loadMempoolHost();
  }

  void _loadMempoolHost() async {
    _mempoolHost = await BlockExplorerService.getExplorerUrl();
  }

  void _setCanBumpingTx() {
    final wallet = _walletProvider.getWalletById(_walletId);
    if (wallet is MultisigWalletListItem) {
      _canBumpingTx = true;
      return;
    }

    final masterFingerprint = (wallet.walletBase as SingleSignatureWallet).keyStore.masterFingerprint;
    _canBumpingTx = masterFingerprint != "00000000";
  }

  BlockTimestamp? get currentBlock => _currentBlock;

  Utxo? get currentUtxo => _currentUtxo;
  bool get isNetworkOn => _connectivityProvider.isNetworkOn == true;
  bool? get isSendType => _isSendType;

  int get previousTransactionIndex => _previousTransactionIndex;
  int get selectedTransactionIndex => _selectedTransactionIndex;

  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;

  DateTime? get timestamp {
    final blockHeight = _txProvider.transaction?.blockHeight;
    return (blockHeight != null && blockHeight > 0) ? _txProvider.transaction!.timestamp : null;
  }

  List<TransactionRecord>? get transactionList => _transactionList;
  List<FeeHistory>? get feeBumpingHistoryList => _feeBumpingHistoryList;

  TransactionStatus? get transactionStatus => _transactionStatus;

  void safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  /// 트랜잭션 내용이 변경될 때마다 다른 키를 반환하여 위젯이 강제로 재생성되도록 합니다.
  String getTransactionKey(int index) {
    if (_transactionList == null || index >= _transactionList!.length) {
      return 'empty_$index';
    }

    final tx = _transactionList![index];
    return tx.contentKey;
  }

  void clearSendInfo() {
    _sendInfoProvider.clear();
  }

  void clearTransationList() {
    _transactionList?.clear();
  }

  String getDerivationPath(String address) {
    return _addressRepository.getDerivationPath(_walletId, address);
  }

  String getInputAddress(int index) =>
      TransactionUtil.getInputAddress(_transactionList![_selectedTransactionIndex], index);

  int getInputAmount(int index) => TransactionUtil.getInputAmount(_transactionList![_selectedTransactionIndex], index);

  String getOutputAddress(int index) =>
      TransactionUtil.getOutputAddress(_transactionList![_selectedTransactionIndex], index);

  int getOutputAmount(int index) =>
      TransactionUtil.getOutputAmount(_transactionList![_selectedTransactionIndex], index);

  String getWalletName() => _walletProvider.getWalletById(_walletId).name;

  bool isSameAddress(String address, int index) {
    bool isContainAddress = _walletProvider.containsAddress(_walletId, address);

    if (isContainAddress) {
      var amount = getInputAmount(index);
      var derivationPath = _addressRepository.getDerivationPath(_walletId, address);
      _currentUtxo = Utxo(_txHash, index, amount, derivationPath);
      return true;
    }
    return false;
  }

  void updateTransactionIndex(int newIndex) {
    _previousTransactionIndex = _selectedTransactionIndex;
    _selectedTransactionIndex = newIndex;
    safeNotifyListeners();
  }

  void setTransactionStatus(TransactionStatus? status) {
    _transactionStatus = status;
    _setSendType(status);
    safeNotifyListeners();
  }

  void _setPreviousTransactionIndex(int newIndex) {
    _previousTransactionIndex = newIndex;
  }

  void _setSelectedTransactionIndex(int newIndex) {
    _selectedTransactionIndex = newIndex;
  }

  void updateProvider() {
    if (_walletProvider.walletItemList.isNotEmpty) {
      _setCurrentBlockHeight();
      _txProvider.initTransaction(_walletId, _txHash);
      TransactionRecord? updatedTx = _txProvider.transaction;

      if (updatedTx == null) return;

      TransactionRecord currentTx = transactionList!.first;
      if (updatedTx.blockHeight != currentTx.blockHeight || updatedTx.transactionHash != currentTx.transactionHash) {
        _initTransactionList();
        _setPreviousTransactionIndex(0);
        _setSelectedTransactionIndex(0);
      }
      // if (_initViewMoreButtons() == false) {
      //   _showDialogNotifier.value = true;
      // }
      // _previousCanSeeMoreInputs ??= _transactionList![selectedTransactionIndex].canSeeMoreInputs;
      // _previousCanSeeMoreOutputs ??= _transactionList![selectedTransactionIndex].canSeeMoreOutputs;
    }
    safeNotifyListeners();
  }

  bool updateTransactionMemo(String memo) {
    final result = _txProvider.updateTransactionMemo(_walletId, _txHash, memo);
    if (result) {
      final updatedTx = _txProvider.getTransactionRecord(_walletId, _txHash);
      if (updatedTx == null) return false;
      _transactionList![0] = updatedTx;
      safeNotifyListeners();
    }
    return result;
  }

  String? fetchTransactionMemo() {
    for (var transaction in _transactionList!) {
      // transactionList를 순회하면서 가장 최근의 txMemo값을 반환
      if (transaction.memo != null) {
        return transaction.memo!;
      }
    }
    return null;
  }

  void _initTransactionList() {
    final currentTransaction = _txProvider.getTransactionRecord(_walletId, _txHash);
    if (currentTransaction == null) {
      debugPrint('❌ currentTransaction IS NULL');
      return;
    }
    _transactionList = [currentTransaction];

    debugPrint('🚀 [Transaction Initialization] 🚀');
    debugPrint('----------------------------------------');
    debugPrint('🔹 Transaction Hash: $_txHash');
    debugPrint('🔹 currentTransaction transactionType: ${currentTransaction.transactionType}');
    debugPrint('🔹 Current Transaction FeeRate: ${currentTransaction.feeRate}');
    debugPrint(
      '🔹 Input Addresses: ${currentTransaction.inputAddressList.map((e) => e.address.toString()).join(", ")}',
    );

    // rbfHistory가 존재하면 높은 fee rate부터 _transactionList에 추가
    if ((currentTransaction.transactionType == TransactionType.sent ||
            currentTransaction.transactionType == TransactionType.self) &&
        currentTransaction.rbfHistoryList != null &&
        currentTransaction.rbfHistoryList!.isNotEmpty) {
      debugPrint('🔹 RBF History Count: ${currentTransaction.rbfHistoryList?.length}');
      debugPrint('----------------------------------------');

      for (var rbfTx in currentTransaction.rbfHistoryList!) {
        if (rbfTx.transactionHash == currentTransaction.transactionHash) {
          continue;
        }
        var rbfTxTransaction = _txProvider.getTransactionRecord(_walletId, rbfTx.transactionHash);
        if (rbfTxTransaction == null) {
          debugPrint('❌ RBF Transaction IS NULL');
          continue;
        }
        _transactionList!.add(rbfTxTransaction);
      }

      _transactionList!.sort((a, b) => b.feeRate.compareTo(a.feeRate));
      debugPrint('🚨 _transactionList : ${_transactionList!.map((s) => s.feeRate)}');
    } else if (currentTransaction.transactionType == TransactionType.received &&
        currentTransaction.cpfpHistory != null) {
      debugPrint('🔹 CPFP History: ${_transactionList?[_selectedTransactionIndex].cpfpHistory}');
      debugPrint('----------------------------------------');
      _transactionList = [
        _txProvider.getTransactionRecord(_walletId, currentTransaction.cpfpHistory!.parentTransactionHash)!,
        _txProvider.getTransactionRecord(_walletId, currentTransaction.cpfpHistory!.childTransactionHash)!,
      ];
    }

    debugPrint('📌 Updated Transaction List Length: ${_transactionList!.length}');
    debugPrint('----------------------------------------');

    for (var transaction in _transactionList!) {
      debugPrint('📍 Transaction Details:');
      debugPrint('  - Fee Rate: ${transaction.feeRate}');
      debugPrint('  - Fee: ${transaction.fee}');
      debugPrint('  - Block Height: ${transaction.blockHeight}');
      debugPrint('  - Amount: ${transaction.amount}');
      debugPrint('  - Created At: ${transaction.createdAt}');
      debugPrint('  - Hash: ${transaction.transactionHash}');
      debugPrint('  - Type: ${transaction.transactionType.name}');
      debugPrint('  - vSize: ${transaction.vSize}');
      debugPrint('  - RBF History Count: ${transaction.rbfHistoryList?.length}');
      debugPrint('----------------------------------------');

      if (transaction.rbfHistoryList != null) {
        for (var a in transaction.rbfHistoryList!) {
          debugPrint('🔄 RBF History Entry:');
          debugPrint('  - Fee Rate: ${a.feeRate}');
          debugPrint('  - Timestamp: ${a.timestamp}');
          debugPrint('  - Transaction Hash: ${a.transactionHash}');
          debugPrint('----------------------------------------');
        }
      }
    }

    debugPrint('✅ Transaction Initialization Complete');
    debugPrint('====================================================================');
    _syncFeeHistoryList();
    safeNotifyListeners();
  }

  void _syncFeeHistoryList() {
    if (transactionList == null || transactionList!.isEmpty) {
      return;
    }
    _feeBumpingHistoryList =
        transactionList!.map((transactionDetail) {
          return FeeHistory(
            feeRate: transactionDetail.feeRate,
            isSelected: selectedTransactionIndex == transactionList!.indexOf(transactionDetail),
          );
        }).toList();
  }

  void _setCurrentBlockHeight() async {
    final result = await _nodeProvider.getLatestBlock();
    if (result.isSuccess) {
      _currentBlock = result.value;
      safeNotifyListeners();
    }
  }

  void _setSendType(TransactionStatus? status) {
    _isSendType =
        status == TransactionStatus.sending ||
        status == TransactionStatus.selfsending ||
        status == TransactionStatus.self ||
        status == TransactionStatus.sent;
  }

  Future<void> onRefresh() async {
    Logger.log('Transaction Detail Force Refresh: $_txHash');
    final walletItem = _walletProvider.getWalletById(_walletId);
    final updatedTxResult = await _nodeProvider.getTransactionRecord(walletItem, _txHash);

    if (updatedTxResult.isSuccess) {
      await _txProvider.updateTransaction(_walletId, _txHash, updatedTxResult.value);

      _initTransactionList();
      _setPreviousTransactionIndex(0);
      _setSelectedTransactionIndex(0);

      safeNotifyListeners();
    } else {
      Logger.log('❌ updatedTxResult IS FAILED: ${updatedTxResult.error}');
    }
  }
}
