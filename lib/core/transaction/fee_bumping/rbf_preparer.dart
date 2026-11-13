import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/sighash_all_policy.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/output_analysis.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';

class RbfPreparer {
  final TransactionRecord pendingTx;
  final List<UtxoState> inputUtxos;
  final OutputAnalysis outputAnalysis;

  RbfPreparer({required this.pendingTx, required this.inputUtxos, required this.outputAnalysis});

  factory RbfPreparer.fromPendingTx({
    required TransactionRecord pendingTx,
    required String rawTx,
    required UtxoState? Function(String utxoId) getUtxos,
    required bool Function(String address, {bool isChange}) isMyAddress,
    required String Function(String address) getDerivationPath,
  }) {
    final (tx, inputUtxos) = _checkInputs(pendingTx, rawTx, getUtxos);
    // 원래 거래의 서명을 내 UTXO(금액·주소)로 확인. 서명이 맞지 않는 거래로는 대체 거래를 만들지 않음
    if (!_hasValidSignatures(tx, inputUtxos)) throw const UnverifiedOriginalTransactionException();
    return _prepare(pendingTx, inputUtxos, isMyAddress, getDerivationPath);
  }

  /// [RbfPreparer.fromPendingTx]와 같은 순서·예외로 준비하되, 원래 거래의 서명 확인(입력마다 몇 ms)은 다른 아이솔레이트에서 한다.
  /// 기다리는 동안 화면(메인 아이솔레이트)이 멈추지 않는다
  static Future<RbfPreparer> fromPendingTxAsync({
    required TransactionRecord pendingTx,
    required String rawTx,
    required UtxoState? Function(String utxoId) getUtxos,
    required bool Function(String address, {bool isChange}) isMyAddress,
    required String Function(String address) getDerivationPath,
  }) async {
    final (_, inputUtxos) = _checkInputs(pendingTx, rawTx, getUtxos);
    if (!await _hasValidSignaturesOffMainIsolate(rawTx, inputUtxos)) {
      throw const UnverifiedOriginalTransactionException();
    }
    return _prepare(pendingTx, inputUtxos, isMyAddress, getDerivationPath);
  }

  /// 두 길이 함께 쓰는 선행 확인. 원문이 이 거래인지 먼저 보고(로컬 UTXO를 읽기 전), 입력이 모두 내 UTXO인지 본다
  static (Transaction, List<UtxoState>) _checkInputs(
    TransactionRecord pendingTx,
    String rawTx,
    UtxoState? Function(String utxoId) getUtxos,
  ) {
    final tx = Transaction.parse(rawTx);
    if (tx.transactionHash != pendingTx.transactionHash) throw ArgumentError('pendingTx and rawTx does not match');
    final inputUtxos = <UtxoState>[];
    for (final input in tx.inputs) {
      final utxoId = getUtxoId(input.transactionHash, input.index);
      inputUtxos.add(getUtxos(utxoId) ?? (throw UtxoNotFoundException(utxoId: utxoId)));
    }
    return (tx, inputUtxos);
  }

  static RbfPreparer _prepare(
    TransactionRecord pendingTx,
    List<UtxoState> inputUtxos,
    bool Function(String address, {bool isChange}) isMyAddress,
    String Function(String address) getDerivationPath,
  ) => RbfPreparer(
    pendingTx: pendingTx,
    inputUtxos: inputUtxos,
    outputAnalysis: OutputAnalysis.fromPendingTx(
      pendingTx: pendingTx,
      isMyAddress: isMyAddress,
      getDerivationPath: getDerivationPath,
    ),
  );

  bool get hasDuplicatedOutput => outputAnalysis.hasDuplicatedOutput;

  /// 모든 입력이 내 UTXO이므로 prevout을 서버 데이터 없이 만든다. 이전 출력을 만들 수 없거나(로컬 주소가 깨짐) 서명이 없거나 모양이
  /// 깨지면 예외가 나므로 실패로 본다
  static bool _hasValidSignatures(Transaction tx, List<UtxoState> inputUtxos) {
    try {
      return _signaturesValid(tx, [for (final utxo in inputUtxos) TransactionOutput.forPayment(utxo.amount, utxo.to)]);
    } catch (_) {
      return false;
    }
  }

  /// [_hasValidSignatures]와 같되 확인은 다른 아이솔레이트에서 한다. 아이솔레이트에는 원문과 직렬화한 이전 출력만 넘긴다
  /// (네트워크 설정·Realm에 기대지 않음)
  static Future<bool> _hasValidSignaturesOffMainIsolate(String rawTx, List<UtxoState> inputUtxos) {
    final List<String> prevouts;
    try {
      prevouts = [for (final utxo in inputUtxos) TransactionOutput.forPayment(utxo.amount, utxo.to).serialize()];
    } catch (_) {
      return Future.value(false);
    }
    return _runOffMainIsolate(rawTx, prevouts);
  }

  static Future<bool> _runOffMainIsolate(String rawTx, List<String> prevouts) => Isolate.run(() {
    try {
      return _signaturesValid(Transaction.parse(rawTx), [
        for (final prevout in prevouts) TransactionOutput.parse(prevout),
      ]);
    } catch (_) {
      return false;
    }
  });

  /// 코코넛 서명 정책(SIGHASH_ALL)을 먼저 보고 모든 입력의 서명을 확인한다
  static bool _signaturesValid(Transaction tx, List<TransactionOutput> prevouts) =>
      tx.inputs.indexed.every((entry) => usesSighashAllOnly(entry.$2, prevouts[entry.$1].scriptPubKey)) &&
      tx.validateSpend(prevouts);
}
