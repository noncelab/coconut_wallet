import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
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
    _transactionList = [
      TransactionDetail(_txProvider.getTransaction(_walletId, _txHash)),
      TransactionDetail(
        TransactionRecord.fromTransactions(
          transactionHash: "a1b2c3d4e5f6g7h8i9j0",
          timestamp:
              DateTime.now().subtract(const Duration(days: 1)), // 하루 전 거래
          blockHeight: 123456,
          transactionType: "RECEIVED",
          amount: 500000, // 500,000 sats (0.005 BTC)
          fee: 1000, // 1,000 sats
          inputAddressList: [
            TransactionAddress("bc1qexamplefrom", 500000),
          ],
          outputAddressList: [
            TransactionAddress(
                "bcrt1qxmqqt7r959ekepyl03nu0jd3hsfm54d2n88ds2", 499000),
            TransactionAddress("bc1qexamplefrom", 499000),
          ],
          vSize: 225,
          memo: "Received payment",
        ),
      ), // FIXME 임시 데이터
      TransactionDetail(
        TransactionRecord.fromTransactions(
          transactionHash: "a2b1c3d4e5f6g7h8i9j0",
          timestamp:
              DateTime.now().subtract(const Duration(days: 1)), // 하루 전 거래
          blockHeight: 123456,
          transactionType: "RECEIVED",
          amount: 500000, // 500,000 sats (0.005 BTC)
          fee: 1000, // 1,000 sats
          inputAddressList: [
            TransactionAddress("bc1qexamplefrom", 500000),
          ],
          outputAddressList: [
            TransactionAddress(
                "bcrt1qxmqqt7r959ekepyl03nu0jd3hsfm54d2n88ds2", 499000),
            TransactionAddress("bc1qexamplefrom", 499000),
          ],
          vSize: 225,
          memo: "Received payment",
        ),
      ), // FIXME 임시 데이터
    ];
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

  void init() {
    _transactionList![0].setCanSeeMoreInputs(false);
    _transactionList![0].setCanSeeMoreOutputs(false);
    _transactionList![0].setInputCountToShow(0);
    _transactionList![0].setOutputCountToShow(0);
  }

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
      notifyListeners();
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
