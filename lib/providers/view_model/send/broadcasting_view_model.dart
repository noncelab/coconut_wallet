import 'dart:collection';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/material.dart';

class BroadcastingViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late final UtxoTagProvider _tagProvider;
  late final NodeProvider _nodeProvider;
  late final TransactionProvider _txProvider;
  late final WalletBase _walletBase;
  late final int _walletId;
  late bool? _isNetworkOn;
  bool _isInitDone = false;
  bool _isSendingToMyAddress = false;
  final List<String> _recipientAddresses = [];
  int? _sendingAmount;
  int? _fee;
  int? _totalAmount;
  int? _sendingAmountWhenAddressIsMyChange; // 내 지갑의 change address로 보내는 경우 잔액
  final List<int> _outputIndexesToMyAddress = [];
  late int? _bitcoinPriceKrw;

  BroadcastingViewModel(
    this._sendInfoProvider,
    this._walletProvider,
    this._tagProvider,
    this._isNetworkOn,
    this._bitcoinPriceKrw,
    this._nodeProvider,
    this._txProvider,
  ) {
    _walletBase =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!).walletBase;
    _walletId = _sendInfoProvider.walletId!;
  }

  List<String> get recipientAddresses =>
      UnmodifiableListView(_recipientAddresses);

  int? get amount => _sendingAmount;
  int? get amountValueInKrw {
    if (_bitcoinPriceKrw == null || _sendingAmount == null) return null;
    return FiatUtil.calculateFiatAmount(
        sendingAmountWhenAddressIsMyChange != null
            ? sendingAmountWhenAddressIsMyChange!
            : amount!,
        _bitcoinPriceKrw!);
  }

  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  int? get fee => _fee;
  bool get isInitDone => _isInitDone;
  bool get isNetworkOn => _isNetworkOn == true;
  bool get isSendingToMyAddress => _isSendingToMyAddress;
  int? get sendingAmountWhenAddressIsMyChange =>
      _sendingAmountWhenAddressIsMyChange;
  String get signedTransaction => _sendInfoProvider.signedPsbt!;
  int? get totalAmount => _totalAmount;
  AddressType get walletAddressType => _walletBase.addressType;
  int get walletId => _walletId;

  UtxoTagProvider get tagProvider => _tagProvider;

  FeeBumpingType? get feeBumpingType => _sendInfoProvider.feeBumpingType;

  Future<Result<String>> broadcast(Transaction signedTx) async {
    return _nodeProvider.broadcast(signedTx);
  }

  void setBitcoinPriceKrw(int bitcoinPriceKrw) {
    _bitcoinPriceKrw = bitcoinPriceKrw;
    notifyListeners();
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
  }

  void setTxInfo() async {
    Psbt signedPsbt = Psbt.parse(signedTransaction);
    // print("!!! -> ${_model.signedTransaction!}");
    List<PsbtOutput> outputs = signedPsbt.outputs;

    // case1. 다른 사람에게 보내고(B1) 잔액이 있는 경우(A2)
    // case2. 다른 사람에게 보내고(B1) 잔액이 없는 경우
    // case3. 내 지갑의 다른 주소로 보내고(A2) 잔액이 있는 경우(A3)
    // case4. 내 지갑의 다른 주소로 보내고(A2) 잔액이 없는 경우
    // 만약 실수로 내 지갑의 change address로 보내는 경우에는 sendingAmount가 0
    List<PsbtOutput> outputToMyReceivingAddress = [];
    List<PsbtOutput> outputToMyChangeAddress = [];
    List<PsbtOutput> outputsToOther = [];
    for (int i = 0; i < outputs.length; i++) {
      if (outputs[i].bip32Derivation == null) {
        outputsToOther.add(outputs[i]);
      } else if (outputs[i].isChange) {
        outputToMyChangeAddress.add(outputs[i]);
        _outputIndexesToMyAddress.add(i);
      } else {
        outputToMyReceivingAddress.add(outputs[i]);
        _outputIndexesToMyAddress.add(i);
      }
    }

    if (_isBatchTransaction(
        outputToMyReceivingAddress, outputToMyChangeAddress, outputsToOther)) {
      Map<String, double> recipientAmounts = {};
      if (outputsToOther.isNotEmpty) {
        for (var output in outputsToOther) {
          recipientAmounts[output.outAddress] =
              UnitUtil.satoshiToBitcoin(output.outAmount!);
        }
      }
      if (outputToMyReceivingAddress.isNotEmpty) {
        for (var output in outputToMyReceivingAddress) {
          recipientAmounts[output.outAddress] =
              UnitUtil.satoshiToBitcoin(output.outAmount!);
        }
        _isSendingToMyAddress = true;
      }
      if (outputToMyChangeAddress.length > 1) {
        for (int i = outputToMyChangeAddress.length - 1; i > 0; i--) {
          var output = outputToMyChangeAddress[i];
          recipientAmounts[output.outAddress] =
              UnitUtil.satoshiToBitcoin(output.outAmount!);
        }
      }
      _sendingAmount = signedPsbt.sendingAmount;
      _recipientAddresses.addAll(recipientAmounts.entries
          .map((e) => '${e.key} (${e.value} ${t.btc})'));
    } else {
      PsbtOutput? output;
      if (outputsToOther.isNotEmpty) {
        output = outputsToOther[0];
      } else if (outputToMyReceivingAddress.isNotEmpty) {
        output = outputToMyReceivingAddress[0];
        _isSendingToMyAddress = true;
      } else if (outputToMyChangeAddress.isNotEmpty) {
        // 받는 주소에 내 지갑의 change address를 입력한 경우
        // 원래 이 경우 output.sendingAmount = 0, 보낼 주소가 표기되지 않았었지만, 버그처럼 보이는 문제 때문에 대응합니다.
        // (주의!!) coconut_lib에서 output 배열에 sendingOutput을 먼저 담으므로 항상 첫번째 것을 사용하면 전액 보내기일 때와 아닐 때 모두 커버 됨
        // 하지만 coconut_lib에 종속적이므로 coconut_lib에 변경 발생 시 대응 필요

        output = outputToMyChangeAddress[0];
        _sendingAmountWhenAddressIsMyChange = output.outAmount;
        _isSendingToMyAddress = true;
      }

      _sendingAmount = signedPsbt.sendingAmount;
      if (output != null) {
        _recipientAddresses.add(output.outAddress);
      }
    }
    _fee = signedPsbt.fee;
    _totalAmount = signedPsbt.sendingAmount + signedPsbt.fee;
    _isInitDone = true;
    notifyListeners();
  }

  ///예외: 사용자가 배치 트랜잭션에 '남의 주소 또는 내 Receive 주소 1개'와 '본인 change 주소 1개'를 입력하고, 이 트랜잭션의 잔액이 없는 희박한 상황에서는 배치 트랜잭션임을 구분하지 못함
  bool _isBatchTransaction(
      List<PsbtOutput> outputToMyReceivingAddress,
      List<PsbtOutput> outputToMyChangeAddress,
      List<PsbtOutput> outputsToOther) {
    var countExceptToMyChangeAddress =
        outputToMyReceivingAddress.length + outputsToOther.length;
    if (countExceptToMyChangeAddress >= 2) {
      return true;
    }
    if (outputToMyChangeAddress.length >= 3) {
      return true;
    }
    if (outputToMyChangeAddress.length == 2 &&
        countExceptToMyChangeAddress >= 1) {
      return true;
    }

    return false;
  }

  // pending상태였던 Tx가 confirmed 되었는지 조회
  bool hasTransactionConfirmed() {
    TransactionRecord? tx = _txProvider.getTransactionRecord(
        walletId, _txProvider.transaction!.transactionHash);
    if (tx == null || tx.blockHeight! <= 0) return false;
    return true;
  }

  Future<void> updateTagsOfUsedUtxos(String signedTx) async {
    await _tagProvider.applyTagsToNewUtxos(
        _walletId, signedTx, _outputIndexesToMyAddress);
  }
}
