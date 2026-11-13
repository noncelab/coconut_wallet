import 'dart:async';

import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/model/ark/ark_board.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/ark/hot_wallet_onchain_payment.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';

enum ArkMoveDirection { toArk, toOnchain }

/// 옮길 수 없는 이유
enum ArkMoveProblem { exceedsBalance, belowMinimum, serverDown, estimateFailed }

/// 같은 지갑 안에서 온체인·아크 잔액을 옮기는 화면
class ArkMoveViewModel extends ChangeNotifier {
  ArkMoveViewModel(this._arkProvider, this._walletProvider, this._nodeProvider, this._utxoRepository, this.walletId)
    : _payment = HotWalletOnchainPayment(_walletProvider, walletId) {
    _loadBoardTerms();
  }

  final ArkProvider _arkProvider;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final UtxoRepository _utxoRepository;
  final HotWalletOnchainPayment _payment;
  final int walletId;

  ArkMoveDirection _direction = ArkMoveDirection.toArk;
  ArkMoveDirection get direction => _direction;

  int? _amountSats;
  int? get amountSats => _amountSats;

  /// [모두]를 눌러 출발 잔액 전부를 옮김(수수료는 금액에서 빠짐)
  bool _isMax = false;
  bool get isMax => _isMax;

  ArkBoardTerms? _boardTerms;
  ArkBoardTerms? get boardTerms => _boardTerms;
  bool _isLoadingBoardTerms = true;
  bool get isLoadingBoardTerms => _isLoadingBoardTerms;

  bool _isEstimating = false;
  bool get isEstimating => _isEstimating;

  /// 온체인 수수료와 아크 수수료를 더한 값
  int? _feeSats;
  int? get feeSats => _feeSats;

  /// 도착하는 금액
  int? _arrivalSats;
  int? get arrivalSats => _arrivalSats;

  /// 출발 잔액에서 빠지는 금액(옮기는 금액 + 출발 잔액에서 나가는 수수료)
  int? _spendSats;
  int? get spendSats => _spendSats;
  int? get fromAfterSats => _spendSats == null ? null : fromBalanceSats - _spendSats!;

  ArkMoveProblem? _problem;
  ArkMoveProblem? get problem => _problem;

  ArkBoardFunding? _funding;
  int? _feeRate;
  Timer? _estimateTimer;
  int _estimateSeq = 0;
  bool _disposed = false;

  int get onchainBalanceSats => _walletProvider.getWalletBalance(walletId).confirmed;
  int get arkBalanceSats => _arkProvider.sendableSats(walletId);

  int get fromBalanceSats => _direction == ArkMoveDirection.toArk ? onchainBalanceSats : arkBalanceSats;
  int get toBalanceSats => _direction == ArkMoveDirection.toArk ? arkBalanceSats : onchainBalanceSats;

  bool get needsPassphrase => _direction == ArkMoveDirection.toArk && _payment.needsPassphrase;
  Future<bool> validatePassphrase(Uint8List passphrase) => _payment.validatePassphrase(passphrase);

  /// 옮길 수 있는 가장 작은 금액. 아크로는 서버 최소 보딩 금액, 온체인으로는 더스트 한도 바로 위
  int get minimumSats {
    if (_direction == ArkMoveDirection.toOnchain) return _onchainDustThreshold + 1;
    final boardMinimum = _boardTerms?.minAmountSats ?? 0;
    return boardMinimum > ArkBoardTerms.dustLimitSats ? boardMinimum : ArkBoardTerms.dustLimitSats;
  }

  int get _onchainDustThreshold => _walletProvider.getWalletById(walletId).walletType.addressType.dustThreshold;

  /// 수수료가 도착하는 금액보다 큼(막지는 않음)
  bool get feeExceedsAmount => _feeSats != null && _arrivalSats != null && _feeSats! > _arrivalSats!;

  bool get canMove =>
      (_amountSats ?? 0) > 0 && !_isEstimating && _problem == null && _feeSats != null && _arrivalSats != null;

  void swapDirection() {
    _direction = _direction == ArkMoveDirection.toArk ? ArkMoveDirection.toOnchain : ArkMoveDirection.toArk;
    _amountSats = null;
    _isMax = false;
    _resetEstimate();
    notifyListeners();
  }

  void setAmountSats(int? sats, {bool isMax = false}) {
    _amountSats = sats;
    _isMax = isMax;
    _scheduleEstimate();
  }

  void _resetEstimate() {
    _estimateTimer?.cancel();
    _estimateSeq++;
    _feeSats = null;
    _arrivalSats = null;
    _spendSats = null;
    _problem = null;
    _isEstimating = false;
  }

  void _scheduleEstimate() {
    _resetEstimate();
    final amount = _amountSats;
    if (amount == null || amount <= 0) {
      notifyListeners();
      return;
    }
    if (amount > fromBalanceSats) {
      _problem = ArkMoveProblem.exceedsBalance;
      notifyListeners();
      return;
    }
    _isEstimating = true;
    notifyListeners();
    final seq = _estimateSeq;
    _estimateTimer = Timer(const Duration(milliseconds: 300), () => _estimate(seq, amount));
  }

  Future<void> _estimate(int seq, int amount) async {
    ArkMoveProblem? problem;
    int? fee;
    int? arrival;
    int? spend;
    try {
      if (!await _arkProvider.isServerReachable(walletId)) {
        problem = ArkMoveProblem.serverDown;
      } else if (_direction == ArkMoveDirection.toArk) {
        final funding = _funding ??= await _arkProvider.boardFunding(walletId);
        final feeRate = _feeRate ??= await _arkProvider.onchainFeeRate(walletId);
        final built = _payment.build(
          address: funding.address,
          amountSats: amount,
          feeRate: feeRate.toDouble(),
          sweep: _isMax,
        );
        if (built.isFailure) {
          problem = ArkMoveProblem.exceedsBalance;
        } else {
          final boarded = _isMax ? amount - built.estimatedFee : amount;
          final terms = _boardTerms;
          if (terms != null && terms.check(boarded) != null) {
            problem = ArkMoveProblem.belowMinimum;
          } else {
            final boardFee = await _arkProvider.estimateBoardFee(walletId, boarded);
            fee = built.estimatedFee + boardFee;
            arrival = boarded - boardFee;
            spend = _isMax ? amount : amount + built.estimatedFee;
          }
        }
      } else {
        final address = _walletProvider.getReceiveAddress(walletId).address;
        final moveFee = await _arkProvider.estimateMoveOnchainFee(
          walletId,
          address,
          amountSats: _isMax ? null : amount,
        );
        if (!_isMax && amount + moveFee > arkBalanceSats) {
          problem = ArkMoveProblem.exceedsBalance;
        } else {
          fee = moveFee;
          arrival = _isMax ? amount - moveFee : amount;
          spend = _isMax ? amount : amount + moveFee;
          if (arrival <= 0) {
            problem = ArkMoveProblem.exceedsBalance;
          } else if (arrival <= _onchainDustThreshold) {
            problem = ArkMoveProblem.belowMinimum;
          }
        }
      }
    } catch (error) {
      Logger.error('ArkMoveViewModel: estimate failed: $error');
      problem = ArkMoveProblem.estimateFailed;
    }
    if (_disposed || seq != _estimateSeq) return;
    _isEstimating = false;
    _problem = problem;
    _feeSats = problem == null ? fee : null;
    _arrivalSats = problem == null ? arrival : null;
    _spendSats = problem == null ? spend : null;
    notifyListeners();
  }

  /// 결제 진행 화면에 넘길 실제 이동. 화면이 인증을 마친 뒤 호출
  Future<void> move({Uint8List? passphrase}) async {
    final amount = _amountSats;
    if (amount == null || !canMove) throw StateError('Nothing to move');
    if (_direction == ArkMoveDirection.toOnchain) {
      final address = _walletProvider.getReceiveAddress(walletId).address;
      await _arkProvider.moveOnchain(walletId, address, amountSats: _isMax ? null : amount);
      return;
    }
    final funding = _funding ?? await _arkProvider.boardFunding(walletId);
    final feeRate = _feeRate ?? await _arkProvider.onchainFeeRate(walletId);
    final built = _payment.build(
      address: funding.address,
      amountSats: amount,
      feeRate: feeRate.toDouble(),
      sweep: _isMax,
    );
    if (built.isFailure) throw built.exception ?? StateError('Board funding was not built');
    final signed = await _payment.sign(built.transaction!, passphrase: passphrase);
    // 전송 전 bark에 보딩 등록(이후 거래 ID 고정)
    await _arkProvider.board(walletId, unsignedPsbtBase64: signed.unsignedPsbt, funding: funding);
    _funding = null;
    final result = await _nodeProvider.broadcast(signed.signedTx);
    if (result.isFailure) {
      Logger.error('ArkMoveViewModel: node broadcast failed, trying bark: ${result.error}');
      await _arkProvider.broadcastTx(walletId, signed.signedTx.serialize());
    }
    try {
      await _utxoRepository.markUnspentInputsAsOutgoing(walletId, signed.signedTx);
    } catch (error) {
      Logger.error('ArkMoveViewModel: board funding sent, but marking inputs failed: $error');
    }
  }

  Future<void> _loadBoardTerms() async {
    try {
      _boardTerms = await _arkProvider.boardTerms(walletId);
    } catch (error) {
      Logger.error('ArkMoveViewModel: board terms unavailable: $error');
    }
    _isLoadingBoardTerms = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _estimateTimer?.cancel();
    super.dispose();
  }
}
