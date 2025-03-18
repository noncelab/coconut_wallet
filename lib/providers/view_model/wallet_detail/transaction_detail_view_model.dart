import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

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

  BlockTimestamp? _currentBlock;

  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _loadCompletedNotifier = ValueNotifier(false);

  Utxo? _currentUtxo;
  Utxo? get currentUtxo => _currentUtxo;

  List<TransactionDetail>? _transactionList;
  List<TransactionDetail>? get transactionList => _transactionList;

  int _selectedTransactionIndex = 0; // RBF history chip 선택 인덱스
  int get selectedTransactionIndex => _selectedTransactionIndex;

  int _previousTransactionIndex = 0; // 이전 인덱스 (애니메이션 방향 결정용)
  int get previousTransactionIndex => _previousTransactionIndex;

  TransactionDetailViewModel(this._walletId, this._txHash, this._walletProvider,
      this._txProvider, this._nodeProvider, this._addressRepository) {
    _initTransactionList();
    _initViewMoreButtons();
  }

  BlockTimestamp? get currentBlock => _currentBlock;

  ValueNotifier<bool> get loadCompletedNotifier => _loadCompletedNotifier;
  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;

  DateTime? get timestamp {
    final blockHeight = _txProvider.transaction?.blockHeight;
    return (blockHeight != null && blockHeight > 0)
        ? _txProvider.transaction!.timestamp
        : null;
  }

  void _initTransactionList() {
    final currentTransaction =
        _txProvider.getTransactionRecord(_walletId, _txHash);
    _transactionList = [TransactionDetail(currentTransaction)];
    debugPrint('_txHash : $_txHash');
    debugPrint(
        '(1) currentTransaction.feerate: ${currentTransaction!.feeRate}');
    debugPrint(
        '(2) currentTransaction.inputaddress: ${currentTransaction.inputAddressList.map((e) => e.address.toString())}');
    debugPrint(
        '(3) rbfHistoryList.length : ${_transactionList!.last.transaction!.rbfHistoryList?.length}');
    // rbfHistory가 존재하면 순차적으로 _transactionList에 추가
    if (currentTransaction.cpfpHistory == null &&
        currentTransaction.rbfHistoryList != null &&
        currentTransaction.rbfHistoryList!.isNotEmpty) {
      // rbfHistoryList를 역순으로 정렬
      var reversedRbfHistoryList = currentTransaction.rbfHistoryList!.reversed;
      for (var rbfTx in reversedRbfHistoryList) {
        var rbfTxTransaction =
            _txProvider.getTransactionRecord(_walletId, rbfTx.transactionHash);
        _transactionList!.add(TransactionDetail(rbfTxTransaction));
        debugPrint('(4) rbfHistory::: ${rbfTx.feeRate}');
      }
    } else if (currentTransaction.cpfpHistory != null) {
      // cpfpHistory가 존재하면 _transactionList에 추가
      _transactionList = [
        TransactionDetail(_txProvider.getTransactionRecord(
            _walletId, currentTransaction.cpfpHistory!.parentTransactionHash)),
        TransactionDetail(_txProvider.getTransactionRecord(
            _walletId, currentTransaction.cpfpHistory!.childTransactionHash)),
      ];

      debugPrint('(3) cpfpHistoryList.length::: ${_transactionList!.length}');
    }
    debugPrint('(5) _transactionList.length::: ${_transactionList!.length}');

    debugPrint(
        '====================================================================');
    for (var transaction in _transactionList!) {
      debugPrint('transaction feeRate: ${transaction._transaction!.feeRate}}');
      debugPrint('transaction fee: ${transaction._transaction.fee}}');
      debugPrint(
          'transaction blockHeight: ${transaction._transaction.blockHeight}}');
      debugPrint('transaction amount: ${transaction._transaction.amount}}');
      debugPrint(
          'transaction createdAt: ${transaction._transaction.createdAt}}');
      debugPrint(
          'transaction transactionHash: ${transaction._transaction.transactionHash}}');
      debugPrint(
          'transaction transactionType: ${transaction._transaction.transactionType}}');
      debugPrint('transaction vSize: ${transaction._transaction.vSize}}');
      debugPrint(
          'transaction rbfHistoryList.length: ${transaction._transaction.rbfHistoryList?.length}}');
      debugPrint(
          '////////////////////////////////////////////////////////////');
      if (transaction._transaction.rbfHistoryList != null) {
        for (var a in transaction._transaction.rbfHistoryList!) {
          debugPrint(
              'rbfHistory[${transaction._transaction.rbfHistoryList!.indexOf(a)}] feeRate: ${a.feeRate}');
          debugPrint(
              'rbfHistory[${transaction._transaction.rbfHistoryList!.indexOf(a)}] timestamp: ${a.timestamp}');
          debugPrint(
              'rbfHistory[${transaction._transaction.rbfHistoryList!.indexOf(a)}] transactionHash: ${a.transactionHash}');
          debugPrint(
              '-------------------------------------------------------------');
        }
      }
      debugPrint(
          '////////////////////////////////////////////////////////////');
    }
    debugPrint(
        '====================================================================');
  }

  // void init() {
  //   _transactionList![0].setCanSeeMoreInputs(false);
  //   _transactionList![0].setCanSeeMoreOutputs(false);
  //   _transactionList![0].setInputCountToShow(0);
  //   _transactionList![0].setOutputCountToShow(0);
  // }

  bool isSameAddress(String address, int index) {
    bool isContainAddress = _walletProvider.containsAddress(_walletId, address);

    if (isContainAddress) {
      var amount = getInputAmount(index);
      var derivationPath =
          _addressRepository.getDerivationPath(_walletId, address);
      _currentUtxo = Utxo(_txHash, index, amount, derivationPath);
      return true;
    }
    return false;
  }

  void setSelectedTransactionIndex(int index) {
    _selectedTransactionIndex = index;
    notifyListeners();
  }

  void setPreviousTransactionIndex() {
    _previousTransactionIndex = _selectedTransactionIndex;
  }

  void onTapViewMoreInputs() {
    // ignore: no_leading_underscores_for_local_identifiers
    if (transactionList?[selectedTransactionIndex] == null) return;
    TransactionDetail transactionDetail =
        _transactionList![selectedTransactionIndex];

    transactionDetail.setInputCountToShow(
        (transactionDetail.inputCountToShow + kViewMoreCount)
            .clamp(0, transactionDetail.transaction!.inputAddressList.length));
    if (transactionDetail.inputCountToShow ==
        transactionDetail.transaction!.inputAddressList.length) {
      transactionDetail.setCanSeeMoreInputs(false);
    }
    notifyListeners();
  }

  void onTapViewMoreOutputs() {
    if (_transactionList?[selectedTransactionIndex] == null) return;

    TransactionDetail transactionDetail =
        _transactionList![selectedTransactionIndex];

    transactionDetail.setOutputCountToShow(
        (transactionDetail.outputCountToShow + kViewMoreCount)
            .clamp(0, transactionDetail.transaction!.outputAddressList.length));
    if (transactionDetail.outputCountToShow ==
        transactionDetail.transaction!.outputAddressList.length) {
      transactionDetail.setCanSeeMoreOutputs(false);
    }
    notifyListeners();
  }

  void updateProvider() {
    if (_walletProvider.walletItemList.isNotEmpty) {
      _setCurrentBlockHeight();
      _txProvider.initTransaction(_walletId, _txHash);

      if (_initViewMoreButtons() == false) {
        _showDialogNotifier.value = true;
      }
    }
    notifyListeners();
  }

  bool updateTransactionMemo(String memo) {
    final result = _txProvider.updateTransactionMemo(_walletId, _txHash, memo);
    if (result) {
      _transactionList![_selectedTransactionIndex] =
          TransactionDetail(_txProvider.getTransaction(_walletId, _txHash));
      notifyListeners();
    }
    return result;
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

    final status = TransactionUtil.getStatus(
        _transactionList![_selectedTransactionIndex].transaction!);

    final isRbfType = [
      TransactionStatus.sending,
      TransactionStatus.sent,
      TransactionStatus.self,
      TransactionStatus.selfsending,
    ].contains(status);

    int initialInputMaxCount =
        isRbfType ? kNotReceiveInputCount : kReceiveInputCount;
    int initialOutputMaxCount =
        isRbfType ? kNotReceiveOutputCount : kReceiveOutputCount;

    if (_transactionList![_selectedTransactionIndex]
            .transaction!
            .inputAddressList
            .length <=
        initialInputMaxCount) {
      _transactionList![_selectedTransactionIndex].setCanSeeMoreInputs(false);
      _transactionList![_selectedTransactionIndex].setInputCountToShow(
          _transactionList![_selectedTransactionIndex]
              .transaction!
              .inputAddressList
              .length);
    } else {
      _transactionList![_selectedTransactionIndex].setCanSeeMoreInputs(true);
      _transactionList![_selectedTransactionIndex]
          .setInputCountToShow(initialInputMaxCount);
    }
    if (_transactionList![_selectedTransactionIndex]
            .transaction!
            .outputAddressList
            .length <=
        initialOutputMaxCount) {
      _transactionList![_selectedTransactionIndex].setCanSeeMoreOutputs(false);
      _transactionList![_selectedTransactionIndex].setOutputCountToShow(
          _transactionList![_selectedTransactionIndex]
              .transaction!
              .outputAddressList
              .length);
    } else {
      _transactionList![_selectedTransactionIndex].setCanSeeMoreOutputs(true);
      _transactionList![_selectedTransactionIndex]
          .setOutputCountToShow(initialOutputMaxCount);
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

  String getWalletName() => _walletProvider.getWalletById(_walletId).name;

  String getInputAddress(int index) => TransactionUtil.getInputAddress(
      _transactionList![_selectedTransactionIndex].transaction!, index);

  String getOutputAddress(int index) => TransactionUtil.getOutputAddress(
      _transactionList![_selectedTransactionIndex].transaction!, index);

  int getInputAmount(int index) => TransactionUtil.getInputAmount(
      _transactionList![_selectedTransactionIndex].transaction!, index);

  int getOutputAmount(int index) => TransactionUtil.getOutputAmount(
      _transactionList![_selectedTransactionIndex].transaction!, index);
  String getDerivationPath(String address) {
    return _addressRepository.getDerivationPath(_walletId, address);
  }
}

class TransactionDetail {
  final TransactionRecord? _transaction;

  TransactionRecord? get transaction => _transaction;

  bool _canSeeMoreInputs = false;
  bool _canSeeMoreOutputs = false;

  int _inputCountToShow = 0;
  int _outputCountToShow = 0;
  bool get canSeeMoreInputs => _canSeeMoreInputs;
  bool get canSeeMoreOutputs => _canSeeMoreOutputs;
  int get inputCountToShow => _inputCountToShow;
  int get outputCountToShow => _outputCountToShow;
  TransactionDetail(this._transaction);

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
