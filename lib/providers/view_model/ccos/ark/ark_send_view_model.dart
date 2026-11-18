import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';

enum ArkSendProblem { unknown, onchainNotYet, wrongNetwork, unsupported, notEnoughBalance, feeFailed }

/// 아크 지갑 보내기. 받는 곳 → (필요하면) 금액 → 최종 확인
class ArkSendViewModel extends ChangeNotifier {
  ArkSendViewModel(this._wallet, {required NetworkType network, Duration feeDelay = const Duration(milliseconds: 300)})
    : _network = network,
      _feeDelay = feeDelay;

  final ArkWalletProvider _wallet;
  final NetworkType _network;
  final Duration _feeDelay;

  String _input = '';
  ArkPaymentRequest? _request;
  int? _enteredAmount;
  int? _fee;
  bool _isEstimating = false;
  bool _feeFailed = false;
  Timer? _feeTimer;

  String get input => _input;
  ArkPaymentRequest? get request => _request;
  int? get fee => _fee;
  bool get isEstimating => _isEstimating;

  ArkPaymentOption? get _option {
    final request = _request;
    if (request == null || !request.isPayable) return null;
    return request.arkOptions.where((option) => option.rail != ArkPaymentRail.onchain).firstOrNull;
  }

  ArkPaymentRail? get rail => _option?.rail;
  String? get destination => _option?.destination;

  /// 인보이스에 금액이 있으면 그 금액
  bool get invoiceHasAmount => rail == ArkPaymentRail.lightningInvoice && _request?.invoiceAmountSats != null;
  bool get needsAmount => _option != null && !invoiceHasAmount && _enteredAmount == null;

  int? get amountSats => invoiceHasAmount ? _request!.invoiceAmountSats : _enteredAmount;
  int? get total => amountSats == null || _fee == null ? null : amountSats! + _fee!;

  ArkSendProblem? get problem {
    final request = _request;
    if (request == null || _input.trim().isEmpty) return null;
    if (request.isOnchainOnly) return ArkSendProblem.onchainNotYet;
    switch (request.problem) {
      case ArkPaymentRequestProblem.invoiceNetwork || ArkPaymentRequestProblem.arkNetwork:
        return ArkSendProblem.wrongNetwork;
      case ArkPaymentRequestProblem.bolt12 ||
          ArkPaymentRequestProblem.lnurl ||
          ArkPaymentRequestProblem.requiredParameter:
        return ArkSendProblem.unsupported;
      case null:
        break;
      default:
        return ArkSendProblem.unknown;
    }
    if (_option == null) return ArkSendProblem.unknown;
    final amount = amountSats;
    if (amount != null && amount + (_fee ?? 0) > _wallet.balance.spendable) return ArkSendProblem.notEnoughBalance;
    if (_feeFailed) return ArkSendProblem.feeFailed;
    return null;
  }

  bool get canContinue =>
      _option != null && amountSats != null && amountSats! > 0 && _fee != null && !_isEstimating && problem == null;

  void setInput(String input) {
    _input = input;
    _request = input.trim().isEmpty ? null : ArkPaymentRequest.parse(input, _network);
    _enteredAmount = null;
    _fee = null;
    _feeFailed = false;
    notifyListeners();
    if (amountSats != null) _scheduleFee();
  }

  Future<void> setAmount(int? amountSats) {
    _enteredAmount = amountSats == null || amountSats <= 0 ? null : amountSats;
    _fee = null;
    notifyListeners();
    return _scheduleFee();
  }

  Future<void> _scheduleFee() {
    _feeTimer?.cancel();
    final completer = Completer<void>();
    _feeTimer = Timer(_feeDelay, () => _estimateFee().whenComplete(completer.complete));
    return completer.future;
  }

  Future<void> _estimateFee() async {
    final rail = this.rail;
    final amount = amountSats;
    if (rail == null || amount == null) return;
    _isEstimating = true;
    _feeFailed = false;
    notifyListeners();
    try {
      _fee = await _wallet.estimateFee(rail, amount);
    } catch (error) {
      Logger.error('ArkSendViewModel: fee estimate failed: $error');
      _fee = null;
      _feeFailed = true;
    } finally {
      _isEstimating = false;
      notifyListeners();
    }
  }

  Future<ArkSendResult> send() => _wallet.send(rail!, destination!, amountSats!, invoiceHasAmount: invoiceHasAmount);

  @override
  void dispose() {
    _feeTimer?.cancel();
    super.dispose();
  }
}
