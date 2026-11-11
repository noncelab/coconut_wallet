import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/sighash_all_policy.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';

/// 서버가 보여 준 미확정 거래에서 내 입력의 서명을 확인한 결과
enum PendingTransactionCheck {
  /// 내 입력의 서명이 모두 맞음. 내 입력이 없는 거래(받는 거래)는 확인하지 않고 여기에 든다
  ok,

  /// 내 입력의 서명이 맞지 않음
  invalid,

  /// 내 Taproot 입력을 확인하는 데 필요한 남의 이전 거래를 지금 받지 못함(거래 번호가 다른 응답 포함). 다음 동기화에서 다시 확인한다
  unavailable,
}

/// 서버(Electrum)가 보여 준 미확정 거래가 내 출력을 쓰면, 내 입력의 서명을 그 이전 출력(금액·스크립트)으로 모두 확인한다.
/// - 내 입력: 거래 기록이 "보냄"으로 세는 입력(같은 이전 거래, 같은 계산)과, 로컬 UTXO를 쓰는 입력(코인 상태를 바꾸므로)
/// - 이전 출력은 거래 기록을 만들 때와 같은 이전 거래(받아서 거래 번호를 확인한 것)에서 가져온다. 그 거래가 없을 때만 로컬 UTXO(금액·주소)
/// - 남의 입력은 확인하지 않는다. 내 Taproot 입력의 서명 해시는 모든 입력의 이전 출력을 담으므로 남의 이전 출력도 쓴다
/// - 코코넛 지갑은 P2WPKH·P2WSH 다중 서명·Taproot만 쓰고 핫·볼트·하드웨어 지갑 모두 SIGHASH_ALL(Taproot는 기본값)로 서명하므로,
///   확인되지 않는 내 입력은 꾸민 것으로 본다
/// - 확정된 거래는 확인하지 않는다(블록 포함 증명은 범위 밖)
class PendingTransactionVerifier {
  PendingTransactionVerifier(this._utxoRepository, this._ownInputIndexes);

  final UtxoRepository _utxoRepository;

  /// 거래 기록이 "내 입력"으로 세는 입력 번호(TransactionRecordService.ownInputIndexes)
  final Set<int> Function(int walletId, Transaction tx, List<Transaction> previousTxs) _ownInputIndexes;

  /// [tx]의 이전 거래(입력 순서, 없는 것은 빠짐). getPreviousTransactions와 같은 모양이고, 거래 기록도 이것으로 만든다
  static List<Transaction> previousTransactionsOf(Transaction tx, Map<String, Transaction> parents) => [
    for (final input in tx.inputs)
      if (parents[input.transactionHash] case final previousTx?) previousTx,
  ];

  /// [parents]는 이번 동기화의 거래와, 동기화가 받아 둔 미확정 거래의 이전 거래다(모두 거래 번호 확인함)
  Future<PendingTransactionCheck> check(int walletId, Transaction tx, Map<String, Transaction> parents) async {
    TransactionOutput? previousOutput(TransactionInput input) {
      final outputs = parents[input.transactionHash]?.outputs;
      return outputs != null && input.index < outputs.length ? outputs[input.index] : null;
    }

    final recordOwn = _ownInputIndexes(walletId, tx, previousTransactionsOf(tx, parents));
    final ours = <int, TransactionOutput>{};
    for (final (index, input) in tx.inputs.indexed) {
      final utxo = _utxoRepository.getUtxoState(walletId, getUtxoId(input.transactionHash, input.index));
      if (utxo == null && !recordOwn.contains(index)) continue;
      // 거래 기록이 센 입력은 이전 거래가 모두 있으므로 늘 앞쪽에서 정해진다
      ours[index] = previousOutput(input) ?? TransactionOutput.forPayment(utxo!.amount, utxo.to);
    }
    if (ours.isEmpty) return PendingTransactionCheck.ok;

    // Taproot 서명 해시는 모든 입력의 이전 출력(금액·스크립트)을 담는다
    List<TransactionOutput>? allPrevouts;
    if (ours.values.any((prevout) => prevout.scriptPubKey.isP2tr())) {
      allPrevouts = [];
      for (final (index, input) in tx.inputs.indexed) {
        final prevout = ours[index] ?? previousOutput(input);
        if (prevout == null) return PendingTransactionCheck.unavailable;
        allPrevouts.add(prevout);
      }
    }

    for (final MapEntry(key: index, value: prevout) in ours.entries) {
      final script = prevout.scriptPubKey;
      // 코코넛 서명 정책(SIGHASH_ALL만)을 먼저 본다. 그 밖의 해시 유형은 확인되지 않은 서명으로 본다
      if (!usesSighashAllOnly(tx.inputs[index], script)) return PendingTransactionCheck.invalid;
      final valid = _run(() {
        if (script.isP2wpkh() || script.isP2wsh()) return tx.validateEcdsa(index, prevout);
        if (!script.isP2tr()) return false;
        if (tx.inputs[index].witnessList.length == 1) return tx.validateSchnorr(index, allPrevouts!);
        return _verifyScriptPath(tx, index, allPrevouts!);
      });
      if (!valid) return PendingTransactionCheck.invalid;
    }
    return PendingTransactionCheck.ok;
  }

  /// 내 Taproot 스크립트 경로 입력 하나만 확인한다. validateSpend는 모든 입력을 돌아서, 남의 입력 모양(레거시 등)에 따라 내 서명과
  /// 상관없이 실패할 수 있다. 서명 해시 계산은 coconut_lib validateSpend의 스크립트 경로 부분과 같다
  static bool _verifyScriptPath(Transaction tx, int index, List<TransactionOutput> prevouts) {
    final witness = tx.inputs[index].witnessList;
    if (witness.length < 3) return false;
    final signature = witness.take(witness.length - 2).firstWhere((item) => item.isNotEmpty, orElse: () => '');
    // 코코넛 서명 도구는 기본값(64바이트)이나 SIGHASH_ALL(65바이트, 0x01)로만 서명한다
    final hashType = switch (signature.length) {
      128 => 0x00,
      130 when signature.endsWith('01') => 0x01,
      _ => null,
    };
    if (hashType == null) return false;
    final script = Codec.decodeHex(witness[witness.length - 2]);
    final leafHash = Hash.taggedHash(
      'TapLeaf',
      Uint8List.fromList([
        Codec.decodeHex(witness.last)[0] & 0xfe,
        ...Codec.encodeVariableInteger(script.length),
        ...script,
      ]),
    );
    final sigHash = tx.getTaprootSigHash(
      index,
      prevouts,
      hashType: hashType,
      isTapscript: true,
      tapleafHash: leafHash,
      keyVersion: 0,
      codesepPos: 0xffffffff,
    );
    return tx.inputs[index].verifySpend(Codec.decodeHex(sigHash), prevouts[index]);
  }

  /// 확인 중 예외(빈 서명·깨진 데이터·확인할 수 없는 서명 형식)는 맞지 않는 서명으로 본다
  static bool _run(bool? Function() verify) {
    try {
      return verify() ?? false;
    } catch (_) {
      return false;
    }
  }
}
