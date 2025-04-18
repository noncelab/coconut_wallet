import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_detail_screen.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class TransactionDetail {
  final TransactionRecord? _transaction;

  bool _canSeeMoreInputs = false;

  bool _canSeeMoreOutputs = false;
  int _inputCountToShow = 0;

  int _outputCountToShow = 0;

  TransactionDetail(this._transaction);
  TransactionDetail.copy(TransactionDetail original)
      : _transaction = original._transaction,
        _canSeeMoreInputs = original._canSeeMoreInputs,
        _canSeeMoreOutputs = original._canSeeMoreOutputs,
        _inputCountToShow = original._inputCountToShow,
        _outputCountToShow = original._outputCountToShow;

  bool get canSeeMoreInputs => _canSeeMoreInputs;
  bool get canSeeMoreOutputs => _canSeeMoreOutputs;
  int get inputCountToShow => _inputCountToShow;
  int get outputCountToShow => _outputCountToShow;
  TransactionRecord? get transaction => _transaction;

  void setCanSeeMoreInputs(bool value) {
    _canSeeMoreInputs = value;
  }

  void setCanSeeMoreOutputs(bool value) {
    _canSeeMoreOutputs = value;
  }

  void setInputCountToShow(int value) {
    _inputCountToShow = value;
  }

  void setOutputCountToShow(int value) {
    _outputCountToShow = value;
  }
}

class TransactionDetailViewModel extends ChangeNotifier {
  static const int kReceiveInputCount = 3;
  static const int kNotReceiveInputCount = 5;
  static const int kReceiveOutputCount = 4;
  static const int kNotReceiveOutputCount = 2;
  static const int kViewMoreCount = 5;
  static const int kInputMaxCount = 3;
  static const int kOutputMaxCount = 2;

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
  final ValueNotifier<bool> _loadCompletedNotifier = ValueNotifier(false);

  Utxo? _currentUtxo;
  List<TransactionDetail>? _transactionList;
  List<FeeHistory> _feeBumpingHistoryList = [];

  int _selectedTransactionIndex = 0; // RBF history chip 선택 인덱스
  int _previousTransactionIndex = 0; // 이전 인덱스 (애니메이션 방향 결정용)

  int? _previousInputCountToShow;
  int? _previousOutputCountToShow;
  bool? _previousCanSeeMoreInputs;
  bool? _previousCanSeeMoreOutputs;

  TransactionStatus? _transactionStatus = TransactionStatus.receiving;
  bool _isSendType = false;

  TransactionDetailViewModel(
      this._walletId,
      this._txHash,
      this._walletProvider,
      this._txProvider,
      this._nodeProvider,
      this._addressRepository,
      this._connectivityProvider,
      this._sendInfoProvider) {
    _initTransactionList();
    _initViewMoreButtons();
  }
  BlockTimestamp? get currentBlock => _currentBlock;

  Utxo? get currentUtxo => _currentUtxo;
  bool get isNetworkOn => _connectivityProvider.isNetworkOn == true;
  bool? get isSendType => _isSendType;
  ValueNotifier<bool> get loadCompletedNotifier => _loadCompletedNotifier;

  int get previousTransactionIndex => _previousTransactionIndex;
  int get selectedTransactionIndex => _selectedTransactionIndex;
  int? get previousInputCountToShow => _previousInputCountToShow;
  int? get previousOutputCountToShow => _previousOutputCountToShow;
  bool? get previousCanSeeMoreInputs => _previousCanSeeMoreInputs;
  bool? get previousCanSeeMoreOutputs => _previousCanSeeMoreOutputs;

  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;

  DateTime? get timestamp {
    final blockHeight = _txProvider.transaction?.blockHeight;
    return (blockHeight != null && blockHeight > 0) ? _txProvider.transaction!.timestamp : null;
  }

  List<TransactionDetail>? get transactionList => _transactionList;
  List<FeeHistory>? get feeBumpingHistoryList => _feeBumpingHistoryList;

  TransactionStatus? get transactionStatus => _transactionStatus;

  void clearSendInfo() {
    _sendInfoProvider.clear();
  }

  void clearTransationList() {
    _transactionList?.clear();
  }

  String getDerivationPath(String address) {
    return _addressRepository.getDerivationPath(_walletId, address);
  }

  String getInputAddress(int index) => TransactionUtil.getInputAddress(
      _transactionList![_selectedTransactionIndex].transaction!, index);

  int getInputAmount(int index) => TransactionUtil.getInputAmount(
      _transactionList![_selectedTransactionIndex].transaction!, index);

  String getOutputAddress(int index) => TransactionUtil.getOutputAddress(
      _transactionList![_selectedTransactionIndex].transaction!, index);

  int getOutputAmount(int index) => TransactionUtil.getOutputAmount(
      _transactionList![_selectedTransactionIndex].transaction!, index);

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

  void resetPreviousCountValues() {
    _previousInputCountToShow = null;
    _previousOutputCountToShow = null;
    _previousCanSeeMoreInputs = null;
    _previousCanSeeMoreOutputs = null;
  }

  void onTapViewMoreInputs() {
    // ignore: no_leading_underscores_for_local_identifiers
    if (transactionList?[selectedTransactionIndex] == null) return;
    TransactionDetail transactionDetail = _transactionList![selectedTransactionIndex];

    transactionDetail.setInputCountToShow((transactionDetail.inputCountToShow + kViewMoreCount)
        .clamp(0, transactionDetail.transaction!.inputAddressList.length));
    _previousInputCountToShow = transactionDetail.inputCountToShow;

    if (transactionDetail.inputCountToShow ==
        transactionDetail.transaction!.inputAddressList.length) {
      transactionDetail.setCanSeeMoreInputs(false);
      _previousCanSeeMoreInputs = false;
    }
    notifyListeners();
  }

  void onTapViewMoreOutputs() {
    if (_transactionList?[selectedTransactionIndex] == null) return;

    TransactionDetail transactionDetail = _transactionList![selectedTransactionIndex];

    transactionDetail.setOutputCountToShow((transactionDetail.outputCountToShow + kViewMoreCount)
        .clamp(0, transactionDetail.transaction!.outputAddressList.length));
    _previousOutputCountToShow = transactionDetail.outputCountToShow;

    if (transactionDetail.outputCountToShow ==
        transactionDetail.transaction!.outputAddressList.length) {
      transactionDetail.setCanSeeMoreOutputs(false);
      _previousCanSeeMoreOutputs = false;
    }
    notifyListeners();
  }

  void updateTransactionIndex(int newIndex) {
    _previousTransactionIndex = _selectedTransactionIndex;
    _selectedTransactionIndex = newIndex;
    notifyListeners();
  }

  void setTransactionStatus(TransactionStatus? status) {
    _transactionStatus = status;
    _setSendType(status);
    notifyListeners();
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

      TransactionRecord currentTx = transactionList!.first.transaction!;
      if (updatedTx.blockHeight != currentTx.blockHeight ||
          updatedTx.transactionHash != currentTx.transactionHash) {
        _initTransactionList();
        _setPreviousTransactionIndex(0);
        _setSelectedTransactionIndex(0);
      }
      if (_initViewMoreButtons() == false) {
        _showDialogNotifier.value = true;
      }
      _previousCanSeeMoreInputs ??= _transactionList![selectedTransactionIndex].canSeeMoreInputs;
      _previousCanSeeMoreOutputs ??= _transactionList![selectedTransactionIndex].canSeeMoreOutputs;
    }
    notifyListeners();
  }

  bool updateTransactionMemo(String memo) {
    final result = _txProvider.updateTransactionMemo(_walletId, _txHash, memo);
    if (result) {
      _transactionList![0] = TransactionDetail(_txProvider.getTransaction(_walletId, _txHash));
      notifyListeners();
    }
    return result;
  }

  String? fetchTransactionMemo() {
    for (var transaction in _transactionList!) {
      // transactionList를 순회하면서 가장 최근의 txMemo값을 반환
      if (transaction._transaction!.memo != null) {
        return transaction._transaction.memo!;
      }
    }
    return null;
  }

  void _initTransactionList() {
    final currentTransaction = _txProvider.getTransactionRecord(_walletId, _txHash);
    _transactionList = [TransactionDetail(currentTransaction)];

    if (currentTransaction == null) {
      debugPrint('❌ currentTransaction IS NULL');
      return;
    }

    debugPrint('🚀 [Transaction Initialization] 🚀');
    debugPrint('----------------------------------------');
    debugPrint('🔹 Transaction Hash: $_txHash');
    debugPrint('🔹 currentTransaction transactionType: ${currentTransaction.transactionType}');
    debugPrint('🔹 Current Transaction FeeRate: ${currentTransaction.feeRate}');
    debugPrint(
        '🔹 Input Addresses: ${currentTransaction.inputAddressList.map((e) => e.address.toString()).join(", ")}');

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
        _transactionList!.add(TransactionDetail(rbfTxTransaction));
      }

      _transactionList!.sort((a, b) => b.transaction!.feeRate.compareTo(a.transaction!.feeRate));
      debugPrint('🚨 _transactionList : ${_transactionList!.map((s) => s.transaction!.feeRate)}');
    } else if (currentTransaction.transactionType == TransactionType.received &&
        currentTransaction.cpfpHistory != null) {
      debugPrint(
          '🔹 CPFP History: ${_transactionList?[_selectedTransactionIndex].transaction!.cpfpHistory}');
      debugPrint('----------------------------------------');
      _transactionList = [
        TransactionDetail(_txProvider.getTransactionRecord(
            _walletId, currentTransaction.cpfpHistory!.parentTransactionHash)),
        TransactionDetail(_txProvider.getTransactionRecord(
            _walletId, currentTransaction.cpfpHistory!.childTransactionHash)),
      ];
    }

    debugPrint('📌 Updated Transaction List Length: ${_transactionList!.length}');
    debugPrint('----------------------------------------');

    for (var transaction in _transactionList!) {
      debugPrint('📍 Transaction Details:');
      debugPrint('  - Fee Rate: ${transaction._transaction!.feeRate}');
      debugPrint('  - Fee: ${transaction._transaction.fee}');
      debugPrint('  - Block Height: ${transaction._transaction.blockHeight}');
      debugPrint('  - Amount: ${transaction._transaction.amount}');
      debugPrint('  - Created At: ${transaction._transaction.createdAt}');
      debugPrint('  - Hash: ${transaction._transaction.transactionHash}');
      debugPrint('  - Type: ${transaction._transaction.transactionType.name}');
      debugPrint('  - vSize: ${transaction._transaction.vSize}');
      debugPrint('  - RBF History Count: ${transaction._transaction.rbfHistoryList?.length}');
      debugPrint('----------------------------------------');

      if (transaction._transaction.rbfHistoryList != null) {
        for (var a in transaction._transaction.rbfHistoryList!) {
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

    notifyListeners();
  }

  void _syncFeeHistoryList() {
    if (transactionList == null || transactionList!.isEmpty) {
      return;
    }
    _feeBumpingHistoryList = transactionList!.map((transactionDetail) {
      return FeeHistory(
        feeRate: transactionDetail.transaction!.feeRate,
        isSelected: selectedTransactionIndex == transactionList!.indexOf(transactionDetail),
      );
    }).toList();
  }

  bool _initViewMoreButtons() {
    if (_transactionList?[_selectedTransactionIndex] == null) {
      _transactionList![_selectedTransactionIndex].setCanSeeMoreInputs(false);
      _transactionList![_selectedTransactionIndex].setCanSeeMoreOutputs(false);
      _transactionList![_selectedTransactionIndex].setInputCountToShow(0);
      _transactionList![_selectedTransactionIndex].setOutputCountToShow(0);
      notifyListeners();
      return false;
    }

    final status =
        TransactionUtil.getStatus(_transactionList![_selectedTransactionIndex].transaction!);

    final isRbfType = [
      TransactionStatus.sending,
      TransactionStatus.sent,
      TransactionStatus.self,
      TransactionStatus.selfsending,
    ].contains(status);

    int initialInputMaxCount = isRbfType ? kNotReceiveInputCount : kReceiveInputCount;
    int initialOutputMaxCount = isRbfType ? kNotReceiveOutputCount : kReceiveOutputCount;

    if (_transactionList![_selectedTransactionIndex].transaction!.inputAddressList.length <=
        initialInputMaxCount) {
      _transactionList![_selectedTransactionIndex].setCanSeeMoreInputs(false);
      _transactionList![_selectedTransactionIndex].setInputCountToShow(
          _transactionList![_selectedTransactionIndex].transaction!.inputAddressList.length);
    } else {
      _transactionList![_selectedTransactionIndex].setCanSeeMoreInputs(true);
      _transactionList![_selectedTransactionIndex].setInputCountToShow(initialInputMaxCount);
    }
    if (_transactionList![_selectedTransactionIndex].transaction!.outputAddressList.length <=
        initialOutputMaxCount) {
      _transactionList![_selectedTransactionIndex].setCanSeeMoreOutputs(false);
      _transactionList![_selectedTransactionIndex].setOutputCountToShow(
          _transactionList![_selectedTransactionIndex].transaction!.outputAddressList.length);
    } else {
      _transactionList![_selectedTransactionIndex].setCanSeeMoreOutputs(true);
      _transactionList![_selectedTransactionIndex].setOutputCountToShow(initialOutputMaxCount);
    }

    notifyListeners();
    return true;
  }

  void _setCurrentBlockHeight() async {
    final result = await _nodeProvider.getLatestBlock();

    if (result.isSuccess) {
      _currentBlock = result.value;
    }
  }

  void _setSendType(TransactionStatus? status) {
    _isSendType = status == TransactionStatus.sending ||
        status == TransactionStatus.selfsending ||
        status == TransactionStatus.self ||
        status == TransactionStatus.sent;
  }
}
