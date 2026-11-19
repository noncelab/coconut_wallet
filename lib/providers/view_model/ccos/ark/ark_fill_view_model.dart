import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_board.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_fill_source.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/services/fee_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';

enum ArkFillProblem { notEnough, belowMinimum, aboveMaximum, estimateFailed }

/// 핫월렛 온체인 잔액으로 아크 지갑을 채움(보딩). 금액 → 수수료와 도착 금액 → 서명·등록·전송
class ArkFillViewModel extends ChangeNotifier {
  ArkFillViewModel(
    this._wallet,
    this.source, {
    Future<double> Function()? feeRate,
    Duration estimateDelay = const Duration(milliseconds: 300),
  }) : _loadFeeRate = feeRate ?? _recommendedFeeRate,
       _estimateDelay = estimateDelay {
    ready = _load();
  }

  final ArkWalletProvider _wallet;
  final ArkFillSource source;
  final Future<double> Function() _loadFeeRate;
  final Duration _estimateDelay;

  /// 서버 한도와 수수료율을 읽고 나면 끝남
  late final Future<void> ready;

  ArkBoardTerms? _terms;
  ArkBoardFunding? _funding;
  double? _feeRate;
  int? _amountSats;
  bool _isMax = false;
  bool _isEstimating = false;
  int? _onchainFee;
  int? _boardFee;
  ArkFillProblem? _problem;
  Timer? _timer;
  int _seq = 0;
  bool _disposed = false;

  int? get amountSats => _amountSats;

  /// 네트워크 수수료에 쓰는 수수료율(sat/vB), 코코넛 권장 30분 기준
  double? get feeRate => _feeRate;
  bool get isMax => _isMax;
  bool get isEstimating => _isEstimating;
  int? get onchainFee => _onchainFee;
  int? get boardFee => _boardFee;
  int? get totalFee => _onchainFee == null || _boardFee == null ? null : _onchainFee! + _boardFee!;
  ArkFillProblem? get problem => _problem;
  int? get requiredConfirmations => _terms?.requiredConfirmations;
  int? get minimumSats => _terms?.minimumSats;

  /// 보딩되는 금액, 모두면 온체인 수수료를 뺀 값
  int? get boardedSats {
    final amount = _amountSats;
    final fee = _onchainFee;
    if (amount == null || fee == null) return null;
    return _isMax ? amount - fee : amount;
  }

  /// 아크 잔액으로 들어오는 금액
  int? get arrivalSats {
    final boarded = boardedSats;
    final fee = _boardFee;
    return boarded == null || fee == null || _problem != null ? null : boarded - fee;
  }

  /// 핫월렛에서 빠지는 금액
  int? get spendSats {
    final amount = _amountSats;
    final fee = _onchainFee;
    if (amount == null || fee == null) return null;
    return _isMax ? amount : amount + fee;
  }

  bool get canFill => arrivalSats != null && arrivalSats! > 0 && !_isEstimating;

  static Future<double> _recommendedFeeRate() async {
    final fees = await FeeService().getRecommendedFees();
    return fees?.halfHourFee ?? 1;
  }

  Future<void> _load() async {
    try {
      _terms = await _wallet.boardTerms();
    } catch (error) {
      Logger.error('ArkFillViewModel: board terms unavailable: $error');
    }
    try {
      _feeRate = await _loadFeeRate();
    } catch (error) {
      Logger.error('ArkFillViewModel: fee rate unavailable: $error');
      _feeRate = 1;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setAmount(int? amountSats, {bool isMax = false}) {
    _timer?.cancel();
    _seq++;
    _amountSats = amountSats == null || amountSats <= 0 ? null : amountSats;
    _isMax = isMax;
    _onchainFee = null;
    _boardFee = null;
    _problem = null;
    final amount = _amountSats;
    if (amount == null) {
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
    int? onchainFee;
    int? boardFee;
    ArkFillProblem? problem;
    try {
      await ready;
      final funding = _funding ??= await _wallet.boardFunding();
      onchainFee = source.quoteFee(funding.address, amount, _feeRate!, sweep: _isMax);
      if (onchainFee == null) {
        problem = ArkFillProblem.notEnough;
      } else {
        final boarded = _isMax ? amount - onchainFee : amount;
        final terms = _terms;
        if (terms != null && boarded < terms.minimumSats) {
          problem = ArkFillProblem.belowMinimum;
        } else if (terms?.maxAmountSats != null && boarded > terms!.maxAmountSats!) {
          problem = ArkFillProblem.aboveMaximum;
        } else {
          boardFee = await _wallet.estimateBoardFee(boarded);
        }
      }
    } catch (error) {
      Logger.error('ArkFillViewModel: estimate failed: $error');
      problem = ArkFillProblem.estimateFailed;
    }
    if (_disposed || seq != _seq) return;
    _isEstimating = false;
    _onchainFee = onchainFee;
    _boardFee = boardFee;
    _problem = problem;
    notifyListeners();
  }

  /// 인증을 마친 뒤 부름. 서명 → 보딩 등록(이후 거래 ID 고정) → 코코넛 노드 전송, 실패하면 bark로 전송
  Future<void> fill({Uint8List? passphrase}) async {
    final amount = _amountSats;
    final funding = _funding;
    if (amount == null || funding == null || !canFill) throw StateError('Nothing to fill');
    final signed = await source.sign(funding.address, amount, _feeRate!, sweep: _isMax, passphrase: passphrase);
    await _wallet.board(unsignedPsbtBase64: signed.unsignedPsbt, funding: funding);
    _funding = null;
    if (!await source.broadcast(signed)) await _wallet.broadcastTx(signed.signedTxHex);
    await source.markSpent(signed);
    unawaited(_wallet.syncNow());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
