import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';

enum ArkSendProblem { unknown, onchainNotYet, wrongNetwork, expiredInvoice, unsupported, notEnoughBalance, feeFailed }

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
  Timer? _expiryTimer;
  String? _memo;

  /// 만료가 이만큼 남으면 남은 시간을 알림
  static const expiryWarningWindow = Duration(minutes: 10);

  String get input => _input;

  /// 나만 보는 메모. 직접 고치기 전에는 결제 요청(BIP21)에 담긴 메모
  String get memo => _memo ?? _request?.message ?? '';

  /// 받는 쪽이 인보이스에 담은 라이트닝 메모
  String? get lightningMemo => rail == ArkPaymentRail.lightningInvoice ? _request?.invoiceDescription : null;

  void setMemo(String memo) {
    _memo = memo;
    notifyListeners();
  }

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

  DateTime? get _invoiceExpiresAt => rail == ArkPaymentRail.lightningInvoice ? _request?.invoiceExpiresAt : null;

  /// 인보이스 만료까지 남은 분(올림). 만료가 [expiryWarningWindow] 안으로 다가왔고 다른 문제가 없을 때만
  int? get invoiceMinutesLeft {
    final expiresAt = _invoiceExpiresAt;
    if (expiresAt == null || problem != null) return null;
    final left = expiresAt.difference(ArkPaymentRequest.clock());
    if (left > expiryWarningWindow) return null;
    return (left.inSeconds / 60).ceil();
  }

  /// 받는 주소 칸에서 생긴 문제
  bool get hasInputProblem => switch (problem) {
    ArkSendProblem.notEnoughBalance || ArkSendProblem.feeFailed || null => false,
    _ => true,
  };

  ArkSendProblem? get problem {
    final request = _request;
    if (request == null || _input.trim().isEmpty) return null;
    if (request.isOnchainOnly) return ArkSendProblem.onchainNotYet;
    switch (request.problem) {
      case ArkPaymentRequestProblem.invoiceNetwork || ArkPaymentRequestProblem.arkNetwork:
        return ArkSendProblem.wrongNetwork;
      case ArkPaymentRequestProblem.invoiceExpired:
        return ArkSendProblem.expiredInvoice;
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
    if (ArkPaymentRequest.isExpired(_invoiceExpiresAt)) return ArkSendProblem.expiredInvoice;
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
    _memo = null;
    _watchExpiry();
    notifyListeners();
    if (amountSats != null) _scheduleFee();
  }

  /// 화면이 지켜보는 동안만 1초마다 만료를 확인
  void _watchExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (!hasListeners || _invoiceExpiresAt == null || ArkPaymentRequest.isExpired(_invoiceExpiresAt)) return;
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final expired = ArkPaymentRequest.isExpired(_invoiceExpiresAt);
      if (expired || invoiceMinutesLeft != null) notifyListeners();
      if (expired) timer.cancel();
    });
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_expiryTimer == null) _watchExpiry();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _expiryTimer?.cancel();
      _expiryTimer = null;
    }
  }

  Future<void> setAmount(int? amountSats) {
    _enteredAmount = amountSats == null || amountSats <= 0 ? null : amountSats;
    _fee = null;
    _feeFailed = false;
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

  Future<ArkSendResult> send() =>
      _wallet.send(rail!, destination!, amountSats!, invoiceHasAmount: invoiceHasAmount, memo: memo);

  @override
  void dispose() {
    _feeTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
