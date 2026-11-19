import 'dart:async';

import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// [overBalance] 금액에 수수료를 더하면 잔액을 넘음, [feeOverBalance] 전부 보내도 수수료가 더 큼
enum ArkExportProblem { overBalance, feeOverBalance, belowDust, estimateFailed }

/// 아크 잔액을 내 코코넛 지갑으로 내보냄(오프보딩). 금액 또는 전부 → 서버 수수료와 도착 금액 → 전송
class ArkExportViewModel extends ChangeNotifier {
  ArkExportViewModel(
    this._wallet, {
    required String? address,
    required int dustThreshold,
    Duration estimateDelay = const Duration(milliseconds: 300),
  }) : _address = address,
       _dustThreshold = dustThreshold,
       _estimateDelay = estimateDelay;

  final ArkWalletProvider _wallet;

  /// 받을 주소(내 지갑의 받는 주소나 직접 넣은 주소), 아직 없으면 수수료를 셈하지 않음
  String? _address;
  String? get address => _address;

  /// 받을 주소 유형의 더스트 한도, 도착 금액이 이 이하면 못 보냄
  int _dustThreshold;
  final Duration _estimateDelay;

  int? _amountSats;
  bool _isMax = false;
  bool _isEstimating = false;
  int? _fee;
  ArkExportProblem? _problem;
  Timer? _timer;
  int _seq = 0;
  bool _disposed = false;

  int? get amountSats => _amountSats;
  bool get isMax => _isMax;
  bool get isEstimating => _isEstimating;
  int? get fee => _fee;
  ArkExportProblem? get problem => _problem;
  int get balanceSats => _wallet.balance.spendable;

  /// 받는 지갑에 도착하는 금액, 전부면 수수료를 뺀 값
  int? get arrivalSats {
    final amount = _amountSats;
    final fee = _fee;
    if (amount == null || fee == null || _problem != null) return null;
    return _isMax ? amount - fee : amount;
  }

  /// 아크 잔액에서 빠지는 금액
  int? get spendSats {
    final amount = _amountSats;
    final fee = _fee;
    if (amount == null || fee == null || _problem != null) return null;
    return _isMax ? amount : amount + fee;
  }

  bool get canExport => arrivalSats != null && !_isEstimating;

  /// 받을 곳을 바꿈. 넣은 금액은 그대로 두고 수수료를 다시 셈
  Future<void> setDestination(String? address, {required int dustThreshold}) {
    _address = address;
    _dustThreshold = dustThreshold;
    return setAmount(_amountSats, isMax: _isMax);
  }

  Future<void> setAmount(int? amountSats, {bool isMax = false}) {
    _timer?.cancel();
    _seq++;
    _amountSats = amountSats == null || amountSats <= 0 ? null : amountSats;
    _isMax = isMax;
    _fee = null;
    _problem = null;
    final amount = _amountSats;
    if (amount == null || _address == null) {
      _isEstimating = false;
      notifyListeners();
      return Future.value();
    }
    _isEstimating = true;
    notifyListeners();
    final seq = _seq;
    final done = Completer<void>();
    _timer = Timer(_estimateDelay, () => _estimate(seq, amount).whenComplete(done.complete));
    return done.future;
  }

  Future<void> _estimate(int seq, int amount) async {
    int? fee;
    ArkExportProblem? problem;
    try {
      fee = await _wallet.estimateExportFee(_address!, amountSats: _isMax ? null : amount);
      final arrival = _isMax ? amount - fee : amount;
      final spend = _isMax ? amount : amount + fee;
      if (arrival <= 0) {
        problem = ArkExportProblem.feeOverBalance;
      } else if (spend > balanceSats) {
        problem = ArkExportProblem.overBalance;
      } else if (arrival <= _dustThreshold) {
        problem = ArkExportProblem.belowDust;
      }
    } catch (error) {
      Logger.error('ArkExportViewModel: estimate failed: $error');
      problem = ArkExportProblem.estimateFailed;
    }
    if (_disposed || seq != _seq) return;
    _isEstimating = false;
    _fee = fee;
    _problem = problem;
    notifyListeners();
  }

  /// 인증을 마친 뒤 부름, 거래 ID
  Future<String> export() {
    final amount = _amountSats;
    final address = _address;
    if (amount == null || address == null || !canExport) throw StateError('Nothing to export');
    return _wallet.export(address, amountSats: _isMax ? null : amount);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
