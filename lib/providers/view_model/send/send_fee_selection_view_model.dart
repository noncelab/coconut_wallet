import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class SendFeeSelectionViewModel extends ChangeNotifier {
  final SendInfoProvider _sendInfoProvider;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;

  late final WalletListItemBase _walletListItemBase;
  late int _confirmedBalance;
  late bool _isMaxMode;
  late int _walletId;
  late double _amount;
  late bool? _isNetworkOn;
  late TransactionBuilder _txBuilder;
  late List<UtxoState> _availableUtxos;
  TransactionBuildResult? _buildResultWithCustomFee;
  final List<TransactionBuildResult> _recommendedFeeTxResult = [];

  SendFeeSelectionViewModel(
      this._sendInfoProvider, this._walletProvider, this._nodeProvider, this._isNetworkOn) {
    _walletListItemBase = _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _walletId = _sendInfoProvider.walletId!;
    _availableUtxos = _walletProvider
        .getUtxoListByStatus(_walletId, UtxoStatus.unspent)
        .where((element) => element.status != UtxoStatus.locked)
        .toList();
    _confirmedBalance = _availableUtxos.fold<int>(0, (sum, utxo) {
      return sum + utxo.amount;
    });
    if (_sendInfoProvider.recipientsForBatch != null) {
      _setBatchTxParams();
    } else {
      _setSingleTxParams();
    }
    _isNetworkOn = isNetworkOn;
    _updateSendInfoProvider();
    _txBuilder = TransactionBuilder(
        availableUtxos: _availableUtxos,
        recipients: _sendInfoProvider.getRecipientMap()!,
        feeRate: 1,
        changeDerivationPath: _walletProvider.getChangeAddress(_walletId).derivationPath,
        walletListItemBase: _walletListItemBase,
        isFeeSubtractedFromAmount: _isMaxMode,
        isUtxoFixed: false);
  }

  double get amount => _amount;
  bool get isNetworkOn => _isNetworkOn == true;
  WalletProvider get walletProvider => _walletProvider;
  NodeProvider get nodeprovider => _nodeProvider;
  TransactionBuildResult? get buildResultWithCustomFee => _buildResultWithCustomFee;
  List<TransactionBuildResult> get recommendedFeeTxResult => _recommendedFeeTxResult;

  TransactionBuildResult getFinalBuildResult(TransactionFeeLevel? feeLevel) {
    if (feeLevel == null) {
      return _buildResultWithCustomFee!;
    } else {
      switch (feeLevel) {
        case TransactionFeeLevel.fastest:
          return _recommendedFeeTxResult.first;
        case TransactionFeeLevel.halfhour:
          return _recommendedFeeTxResult[1];
        case TransactionFeeLevel.hour:
          return _recommendedFeeTxResult.last;
      }
    }
  }

  List<TransactionBuildResult> setRecommendedFeeTxs(List<FeeInfoWithLevel> feeInfos) {
    for (var feeInfo in feeInfos) {
      _recommendedFeeTxResult.add(_txBuilder.copyWith(feeRate: feeInfo.satsPerVb).build());
    }
    return _recommendedFeeTxResult;
  }

  int estimateFeeWithCustomFee(double satsPerVb, {bool isUserSelection = false}) {
    final buildResult = _txBuilder.copyWith(feeRate: satsPerVb).build();
    if (isUserSelection) {
      _buildResultWithCustomFee = buildResult;
    }
    if (buildResult.estimatedFee == null && buildResult.isFailure) {
      throw buildResult.exception ?? 'Unknown error';
    }
    return buildResult.estimatedFee!;
  }

  void _setSingleTxParams() {
    _amount = _sendInfoProvider.amount!;
    _isMaxMode = _confirmedBalance == UnitUtil.convertBitcoinToSatoshi(_amount);
  }

  void _setBatchTxParams() {
    _amount = _sendInfoProvider.recipientsForBatch!.values.fold(0, (sum, value) => sum + value);
    _isMaxMode = false;
  }

  bool isBalanceEnough(int? estimatedFee) {
    if (estimatedFee == null || estimatedFee == 0) return false;
    if (_isMaxMode) return (_confirmedBalance - estimatedFee) > dustLimit;
    Logger.log(
        '--> ${UnitUtil.convertBitcoinToSatoshi(amount)} + $estimatedFee <= $_confirmedBalance');
    return (UnitUtil.convertBitcoinToSatoshi(amount) + estimatedFee) <= _confirmedBalance;
  }

  void saveFinalSendInfo(TransactionFeeLevel? feeLevel) {
    final finalBuildResult = getFinalBuildResult(feeLevel);
    double finalAmount = _isMaxMode
        ? UnitUtil.convertSatoshiToBitcoin(_confirmedBalance - finalBuildResult.estimatedFee!)
        : _amount;
    _sendInfoProvider.setAmount(finalAmount);
    _sendInfoProvider.setEstimatedFee(finalBuildResult.estimatedFee!);
    _sendInfoProvider.setTransaction(finalBuildResult.transaction!);
    _sendInfoProvider.setFeeBumpfingType(null);
    _sendInfoProvider.setWalletImportSource(_walletListItemBase.walletImportSource);
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void _updateSendInfoProvider() {
    _sendInfoProvider.setIsMultisig(_walletListItemBase.walletType == WalletType.multiSignature);
    _sendInfoProvider.setIsMaxMode(_isMaxMode);
  }
}
