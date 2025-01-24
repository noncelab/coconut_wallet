import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:flutter/material.dart';

class BroadcastingViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late final UtxoTagProvider _tagProvider;
  late final WalletBase _walletBase;
  late final int _walletId;
  late bool? _isNetworkOn;
  bool _isInitDone = false;
  bool _isSendingToMyAddress = false;
  String? _address;
  int? _amount;
  int? _fee;
  int? _totalAmount;
  int? _sendingAmountWhenAddressIsMyChange; // 내 지갑의 change address로 보내는 경우 잔액
  final List<int> _outputIndexesToMyAddress = [];
  late int? _bitcoinPriceKrw;

  BroadcastingViewModel(this._sendInfoProvider, this._walletProvider,
      this._tagProvider, this._isNetworkOn, this._bitcoinPriceKrw) {
    _walletBase =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!).walletBase;
    _walletId = _sendInfoProvider.walletId!;
  }

  String? get address => _address;
  int? get amount => _amount;
  int? get amountValueInKrw {
    if (_bitcoinPriceKrw == null || _amount == null) return null;
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

  Future<Result<String, CoconutError>> broadcast(Transaction signedTx) async {
    return await _walletProvider.broadcast(signedTx);
  }

  void clearSendInfo() {
    _sendInfoProvider.clear();
  }

  void setBitcoinPriceKrw(int bitcoinPriceKrw) {
    _bitcoinPriceKrw = bitcoinPriceKrw;
    notifyListeners();
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
  }

  void setTxInfo() async {
    try {
      PSBT signedPsbt = PSBT.parse(signedTransaction);
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
        if (outputs[i].derivationPath == null) {
          outputsToOther.add(outputs[i]);
        } else if (outputs[i].isChange) {
          outputToMyChangeAddress.add(outputs[i]);
          _outputIndexesToMyAddress.add(i);
        } else {
          outputToMyReceivingAddress.add(outputs[i]);
          _outputIndexesToMyAddress.add(i);
        }
      }

      PsbtOutput? output;
      if (outputsToOther.isNotEmpty) {
        output = outputsToOther[0];
        notifyListeners();
      } else if (outputToMyReceivingAddress.isNotEmpty) {
        output = outputToMyReceivingAddress[0];
        _isSendingToMyAddress = true;
        notifyListeners();
      } else if (outputToMyChangeAddress.isNotEmpty) {
        // 받는 주소에 내 지갑의 change address를 입력한 경우
        // 원래 이 경우 output.sendingAmount = 0, 보낼 주소가 표기되지 않았었지만, 버그처럼 보이는 문제 때문에 대응합니다.
        // (주의!!) coconut_lib에서 output 배열에 sendingOutput을 먼저 담으므로 항상 첫번째 것을 사용하면 전액 보내기일 때와 아닐 때 모두 커버 됨
        // 하지만 coconut_lib에 종속적이므로 coconut_lib에 변경 발생 시 대응 필요

        output = outputToMyChangeAddress[0];
        _sendingAmountWhenAddressIsMyChange = output.amount;
        _isSendingToMyAddress = true;
        notifyListeners();
      }

      _address = output?.getAddress() ?? '';
      _amount = signedPsbt.sendingAmount;

      _fee = signedPsbt.fee;
      _totalAmount = signedPsbt.sendingAmount + signedPsbt.fee;
      _isInitDone = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTagsOfUsedUtxos(String signedTx) async {
    await _tagProvider.updateTagsOfUsedUtxos(
        _walletId, signedTx, _outputIndexesToMyAddress);
  }
}
