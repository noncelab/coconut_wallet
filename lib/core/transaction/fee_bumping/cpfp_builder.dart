import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:flutter/foundation.dart';

class CpfpTransactionResult {
  final Transaction transaction;
  final String recipientAddress;
  final double amount;

  CpfpTransactionResult({
    required this.transaction,
    required this.recipientAddress,
    required this.amount,
  });
}

class CpfpBuilder {
  final Function(int, String) _containsAddress;
  final Function(int) _getReceiveAddress;
  final TransactionRecord _pendingTx;
  final int _walletId;
  final double feeRate;
  final UtxoRepository _utxoRepository;
  final WalletListItemBase _walletListItemBase;

  Transaction? _bumpingTransaction;
  bool _insufficientUtxos = false;
  bool get insufficientUtxos => _insufficientUtxos;

  CpfpBuilder(
    this._containsAddress,
    this._getReceiveAddress,
    this._pendingTx,
    this._walletId,
    this.feeRate,
    this._utxoRepository,
    this._walletListItemBase,
  );

  Future<CpfpTransactionResult?> build() async {
    await _initializeTransaction(feeRate);
    if (_bumpingTransaction == null) return null;

    return _createTransactionResult();
  }

  CpfpBuilder copyWith({
    Function(int)? getReceiveAddress,
    Function(int, String)? containsAddress,
  }) {
    return CpfpBuilder(
      containsAddress ?? _containsAddress,
      getReceiveAddress ?? _getReceiveAddress,
      _pendingTx,
      _walletId,
      feeRate,
      _utxoRepository,
      _walletListItemBase,
    );
  }

  CpfpTransactionResult _createTransactionResult() {
    return CpfpTransactionResult(
      transaction: _bumpingTransaction!,
      recipientAddress: _getReceiveAddress(_walletId).address,
      amount: _bumpingTransaction!.outputs[0].amount.toDouble(),
    );
  }

  Future<void> _initializeTransaction(double newFeeRate) async {
    final myAddressList = _getMyOutputs();
    int amount = myAddressList.fold(0, (sum, output) => sum + output.amount);
    final List<Utxo> utxoList = [];

    // 내 주소와 일치하는 utxo 찾기
    for (var myAddress in myAddressList) {
      final utxoStateList = _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.incoming);
      for (var utxoState in utxoStateList) {
        if (myAddress.address == utxoState.to &&
            myAddress.amount == utxoState.amount &&
            _pendingTx.transactionHash == utxoState.transactionHash &&
            _pendingTx.outputAddressList[utxoState.index].address == utxoState.to) {
          utxoList.add(utxoState);
        }
      }
    }

    assert(utxoList.isNotEmpty);

    // Transaction 생성
    final recipient = _getReceiveAddress(_walletId).address;
    double estimatedVSize;
    try {
      _bumpingTransaction =
          Transaction.forSweep(utxoList, recipient, newFeeRate, _walletListItemBase.walletBase);
      estimatedVSize = _estimateVirtualByte(_bumpingTransaction!);
    } catch (e) {
      // insufficient utxo for sweep
      double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
      estimatedVSize = _pendingTx.vSize.toDouble();

      debugPrint(
          '😇 CPFP utxo (${utxoList.length})개 input: $inputSum / output: $amount / 👉🏻 입력한 fee rate: $newFeeRate');
      if (!_ensureSufficientUtxos(utxoList, amount.toDouble(), estimatedVSize, newFeeRate)) {
        debugPrint('❌ 사용할 수 있는 추가 UTXO가 없음!');
        return;
      }

      _bumpingTransaction =
          Transaction.forSweep(utxoList, recipient, newFeeRate, _walletListItemBase.walletBase);
    }

    debugPrint('😇 CPFP utxo (${utxoList.length})개');
    _setInsufficientUtxo(false);
  }

  List<TransactionAddress> _getMyOutputs() => _pendingTx.outputAddressList
      .where((output) => _containsAddress(_walletId, output.address))
      .toList();

  void _setInsufficientUtxo(bool value) {
    _insufficientUtxos = value;
  }

  double _estimateVirtualByte(Transaction transaction) {
    return TransactionUtil.estimateVirtualByteByWallet(_walletListItemBase, transaction);
  }

  bool _ensureSufficientUtxos(
      List<Utxo> utxoList, double outputSum, double estimatedVSize, double newFeeRate) {
    double inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    double requiredAmount = outputSum + estimatedVSize * newFeeRate;

    List<UtxoState> unspentUtxos = _utxoRepository.getUtxosByStatus(_walletId, UtxoStatus.unspent);
    unspentUtxos.sort((a, b) => b.amount.compareTo(a.amount));
    int sublistIndex = 0; // for unspentUtxos
    while (inputSum <= requiredAmount && sublistIndex < unspentUtxos.length) {
      final additionalUtxos =
          _getAdditionalUtxos(unspentUtxos.sublist(sublistIndex), outputSum - inputSum);
      if (additionalUtxos.isEmpty) {
        debugPrint('❌ 사용할 수 있는 추가 UTXO가 없음!');
        _setInsufficientUtxo(true);
        return false;
      }
      utxoList.addAll(additionalUtxos);
      sublistIndex += additionalUtxos.length;

      int additionalVSize = _getVSizeIncreasement() * additionalUtxos.length;
      requiredAmount = outputSum + (estimatedVSize + additionalVSize) * newFeeRate;
      inputSum = utxoList.fold(0, (sum, utxo) => sum + utxo.amount);
    }

    if (inputSum <= requiredAmount) {
      _setInsufficientUtxo(true);
      return false;
    }

    _setInsufficientUtxo(false);
    return true;
  }

  int _getVSizeIncreasement() {
    switch (_walletListItemBase.walletType) {
      case WalletType.singleSignature:
        return 68;
      case WalletType.multiSignature:
        final wallet = _walletListItemBase.walletBase as MultisignatureWallet;
        final m = wallet.requiredSignature;
        final n = wallet.totalSigner;
        return 1 + (m * 73) + (n * 34) + 2;
      default:
        return 68;
    }
  }

  // todo: utxo lock 기능 추가 시 utxo 제외 로직 필요
  List<Utxo> _getAdditionalUtxos(List<Utxo> unspentUtxo, double requiredAmount) {
    List<Utxo> additionalUtxos = [];
    double sum = 0;
    if (unspentUtxo.isNotEmpty) {
      for (var utxo in unspentUtxo) {
        sum += utxo.amount;
        additionalUtxos.add(utxo);
        if (sum >= requiredAmount) {
          break;
        }
      }
    }

    if (sum < requiredAmount) {
      return [];
    }

    return additionalUtxos;
  }
}
