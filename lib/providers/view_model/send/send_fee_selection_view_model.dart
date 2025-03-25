import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class SendFeeSelectionViewModel extends ChangeNotifier {
  final SendInfoProvider _sendInfoProvider;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;

  late final WalletListItemBase _walletListItemBase;
  late AddressType _walletAddressType;
  late int _confirmedBalance;
  late int? _bitcoinPriceKrw;
  late bool _isMultisigWallet;
  late bool _isMaxMode;
  late int _walletId;
  late double _amount;
  String? _recipientAddress;
  late bool? _isNetworkOn;
  late bool _isBatchTx = false;

  SendFeeSelectionViewModel(this._sendInfoProvider, this._walletProvider,
      this._nodeProvider, this._bitcoinPriceKrw, this._isNetworkOn) {
    _walletListItemBase =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _walletAddressType =
        _walletListItemBase.walletType == WalletType.singleSignature
            ? AddressType.p2wpkh
            : AddressType.p2wsh;
    _confirmedBalance = _walletProvider
        .getUtxoList(_sendInfoProvider.walletId!)
        .fold<int>(0, (sum, utxo) {
      if (utxo.status == UtxoStatus.unspent) {
        return sum + utxo.amount;
      }
      return sum;
    });
    _isMultisigWallet =
        _walletListItemBase.walletType == WalletType.multiSignature;
    _bitcoinPriceKrw = _bitcoinPriceKrw;
    _walletId = _sendInfoProvider.walletId!;
    if (_sendInfoProvider.recipientsForBatch != null) {
      _isBatchTx = true;
      _setBatchTxParams();
    } else {
      _setSingleTxParams();
    }
    _isNetworkOn = isNetworkOn;
    _updateSendInfoProvider();
  }

  double get amount => _amount;
  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  bool get isNetworkOn => _isNetworkOn == true;
  WalletProvider get walletProvider => _walletProvider;
  NodeProvider get nodeprovider => _nodeProvider;

  int estimateFee(int satsPerVb) {
    final transaction = _createTransaction(satsPerVb);

    if (_isMultisigWallet) {
      final multisigWallet =
          _walletListItemBase.walletBase as MultisignatureWallet;
      return transaction.estimateFee(satsPerVb.toDouble(), _walletAddressType,
          requiredSignature: multisigWallet.requiredSignature,
          totalSigner: multisigWallet.totalSigner);
    }

    return transaction.estimateFee(satsPerVb.toDouble(), _walletAddressType);
  }

  Transaction _createTransaction(int satsPerVb) {
    final utxoPool =
        _walletProvider.getUtxoListByStatus(_walletId, UtxoStatus.unspent);
    final wallet = _walletProvider.getWalletById(_walletId);
    final changeAddress = _walletProvider.getChangeAddress(_walletId);
    final amount = UnitUtil.bitcoinToSatoshi(_amount);

    if (_isBatchTx) {
      return Transaction.forBatchPayment(
          TransactionUtil.selectOptimalUtxos(
              utxoPool, amount, satsPerVb, _walletAddressType),
          _sendInfoProvider.recipientsForBatch!.map(
              (key, value) => MapEntry(key, UnitUtil.bitcoinToSatoshi(value))),
          changeAddress.derivationPath,
          satsPerVb.toDouble(),
          _walletListItemBase.walletBase);
    }

    return _isMaxMode
        ? Transaction.forSweep(utxoPool, _recipientAddress!,
            satsPerVb.toDouble(), wallet.walletBase)
        : Transaction.forSinglePayment(
            TransactionUtil.selectOptimalUtxos(
                utxoPool, amount, satsPerVb, _walletAddressType),
            _recipientAddress!,
            changeAddress.derivationPath,
            amount,
            satsPerVb.toDouble(),
            _walletListItemBase.walletBase);
  }

  void _setSingleTxParams() {
    _amount = _sendInfoProvider.amount!;
    _recipientAddress = _sendInfoProvider.recipientAddress!;
    _isMaxMode = _confirmedBalance == UnitUtil.bitcoinToSatoshi(_amount);
  }

  void _setBatchTxParams() {
    _amount = _sendInfoProvider.recipientsForBatch!.values
        .fold(0, (sum, value) => sum + value);
    //_recipientAddresses = _sendInfoProvider.recipientsForBatch!.keys.toList();
    _isMaxMode = false;
  }

  // double getAmount(int estimatedFee) {
  //   return _isMaxMode
  //       ? UnitUtil.satoshiToBitcoin(_confirmedBalance - estimatedFee)
  //       : amount;
  // }

  bool isBalanceEnough(int? estimatedFee) {
    if (estimatedFee == null || estimatedFee == 0) return false;
    if (_isMaxMode) return (_confirmedBalance - estimatedFee) > dustLimit;
    Logger.log(
        '--> ${UnitUtil.bitcoinToSatoshi(amount)} $estimatedFee $_confirmedBalance');
    return (UnitUtil.bitcoinToSatoshi(amount) + estimatedFee) <=
        _confirmedBalance;
  }

  void setBitcoinPriceKrw(int price) {
    _bitcoinPriceKrw = price;
    notifyListeners();
  }

  void saveFinalSendInfo(int estimatedFee, int satsPerVb) {
    double finalAmount = _isMaxMode
        ? UnitUtil.satoshiToBitcoin(_confirmedBalance - estimatedFee)
        : _amount;
    _sendInfoProvider.setAmount(finalAmount);
    _sendInfoProvider.setEstimatedFee(estimatedFee);
    _sendInfoProvider.setTransaction(_createTransaction(satsPerVb));
    _sendInfoProvider.setFeeBumpfingType(null);
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void _updateSendInfoProvider() {
    _sendInfoProvider.setIsMultisig(_isMultisigWallet);
    _sendInfoProvider.setIsMaxMode(_isMaxMode);
  }
}
