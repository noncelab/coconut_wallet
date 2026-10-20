import 'dart:math' as math;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/bitcoin/transaction_util.dart';

/// 구출 거래가 겨루는 의심 거래. 값은 [ConflictAnalyzer]가 채운다
class SweepConflict {
  const SweepConflict({
    required this.txid,
    required this.fee,
    required this.vSize,
    required this.signalsRbf,
    this.descendants = const [],
    this.descendantsComplete = true,
    this.confirmed = false,
    this.feeVerified = false,
  });

  final String txid;
  final int fee;
  final double vSize;
  double get feeRate => fee / vSize;
  final bool signalsRbf;

  /// 이 거래가 밀려날 때 함께 밀려나는 거래. 다른 사건 거래가 들어 있을 수 있다(txid로 한 번만 센다)
  final List<({String txid, int fee, double vSize})> descendants;

  /// 자손 조회가 네트워크 실패로 끝나지 않았으면 false(수수료 하한이 모자랄 수 있음)
  final bool descendantsComplete;

  /// 이미 확정된 거래는 대체할 수 없다(남은 코인만 옮김)
  final bool confirmed;

  /// 이 거래와 [descendants]의 수수료·크기를 모두 일렉트럼 원본 거래로 직접 셌다(입력 값은 내 UTXO 또는 일렉트럼 이전 거래,
  /// 외부 수수료 값을 믿지 않음). 대체 하한 20% 예외의 근거
  final bool feeVerified;
}

enum SweepBlocker {
  noInputs,
  belowDust,
  insufficientForFee,
  conflictConfirmed,
  tooManyDescendants,
  tooLarge,
  unsupportedWallet,

  /// 계약용. [SweepBuilder.plan]은 내지 않고 [SweepBuilder.build]가 StateError로 막는다
  outputCountNot1,
}

class SweepPlan {
  const SweepPlan({
    required this.inputs,
    required this.excluded,
    required this.conflicts,
    required this.vSize,
    required this.feeFloor,
    required this.fee,
    required this.feeRate,
    required this.amount,
    required this.anyConflictNonSignalling,
    this.blocker,
  });

  final List<UtxoState> inputs, excluded;
  final List<SweepConflict> conflicts;

  /// 서명 후 크기의 상한(정수 vbyte). 서명은 최대 길이, 받는 곳 출력은 가장 큰 표준 출력(43바이트)으로 잡았다
  final double vSize;

  /// 대체에 필요한 최소 수수료(BIP125: 밀려날 수수료 합 + 우리 크기 × 1 sat/vB, 직접 충돌보다 엄격히 높은 수수료율).
  /// 충돌이 없으면 1 sat/vB
  final int feeFloor, fee;
  final double feeRate;
  final int amount;
  final bool anyConflictNonSignalling;
  final SweepBlocker? blocker;

  /// 대체 하한을 확인한 값으로만 셌다(모든 충돌이 [SweepConflict.feeVerified], 자손 포함)
  bool get floorVerified => conflicts.isNotEmpty && conflicts.every((c) => c.feeVerified);
}

/// 사고 지갑의 코인을 목적지 하나로 모두 옮기는 거래(대체 거래 포함)를 계획·구성한다.
/// 서명·전송하지 않는다. 기존 RbfBuilder는 원래 수신 출력을 유지하므로 쓰지 않는다
abstract final class SweepBuilder {
  static const rbfSequence = 0xfffffffd;

  /// 함께 밀려나는 거래 수 한도(사건 거래 포함, 모든 충돌을 합쳐서). ponytail: Core 한도는 100, 여유 있게 25
  static const maxDescendants = 25;
  static const maxVSize = 90000; // 표준 거래 한도 100k vB 아래

  // p2wsh·p2tr 출력(8 + 1 + 34). 목적지를 몰라도 수수료가 모자라지 않게 상한으로 계산
  static const _maxOutputBytes = 43;

  // 서명 최대 길이: DER 72 + sighash 1(low-S면 72 이하). p2wpkh 증인 = 개수 1 + (1 + 73) + (1 + 33)
  static const _maxSignature = 73;

  /// 입력: [conflicts]가 쓰는 내 UTXO(밀려날 거래가 만든 것은 빼고) ∪ 확정된 unspent·locked.
  /// 충돌 입력은 수수료보다 작아도 언제나 넣는다(의심 거래를 무효로 만들려고). 더스트·비경제 걸러내기는 그 밖의 입력만.
  /// 비경제 기준은 입력 하나가 늘리는 수수료(입력 크기 × 한계 수수료율 max(빠른 수수료, 1 sat/vB, 직접 충돌 최고 수수료율)).
  /// 평균 수수료율을 쓰면 충돌 수수료가 클 때 평균이 부풀어 남은 코인이 사고 지갑에 남는다(lead 승인).
  ///
  /// 호출 쪽 규칙: [SweepBlocker.conflictConfirmed]·[SweepBlocker.tooManyDescendants]·[SweepBlocker.insufficientForFee]면
  /// `conflicts: []`로 다시 계획해 남은 코인만 옮긴다
  static SweepPlan plan({
    required WalletItemBase wallet,
    required List<UtxoState> utxos,
    required List<SweepConflict> conflicts,
    required double fastFeeRate,
  }) {
    if (!fastFeeRate.isFinite || fastFeeRate < 0) throw ArgumentError.value(fastFeeRate, 'fastFeeRate');
    SweepPlan blocked(SweepBlocker blocker, [List<UtxoState> inputs = const []]) => SweepPlan(
      inputs: inputs,
      excluded: utxos.where((u) => !inputs.contains(u)).toList(),
      conflicts: conflicts,
      vSize: 0,
      feeFloor: 0,
      fee: 0,
      feeRate: 0,
      amount: 0,
      anyConflictNonSignalling: conflicts.any((c) => !c.signalsRbf),
      blocker: blocker,
    );

    if (wallet is TaprootWalletItem && wallet.defaultSpendType == TaprootSpendType.scriptPath) {
      return blocked(SweepBlocker.unsupportedWallet);
    }
    if (conflicts.any((c) => c.confirmed)) return blocked(SweepBlocker.conflictConfirmed);

    // 밀려날 거래 전체(직접 충돌 + 자손). 공유 자손·자손이기도 한 사건 거래는 txid로 한 번만 센다(H1)
    final evictedFees = <String, int>{for (final c in conflicts) c.txid: c.fee};
    for (final c in conflicts) {
      for (final d in c.descendants) {
        evictedFees.putIfAbsent(d.txid, () => d.fee);
      }
    }
    // 개수 한도는 사건 거래를 포함해 전체로(H4)
    if (evictedFees.length > maxDescendants) return blocked(SweepBlocker.tooManyDescendants);

    final rootTxids = {for (final c in conflicts) c.txid};
    bool spentByRoot(UtxoState u) => u.status == UtxoStatus.outgoing && rootTxids.contains(u.spentByTransactionHash);
    // 밀려날 거래가 만든 UTXO는 대체가 확정되면 사라지므로 쓰지 않는다(체인 사건 A→B, H3)
    final conflictInputs = {
      for (final u in utxos)
        if (spentByRoot(u) && !evictedFees.containsKey(u.transactionHash)) u,
    };
    final direct = [
      for (final c in conflicts)
        if (conflictInputs.any((u) => u.spentByTransactionHash == c.txid)) c,
    ];
    // 직접 쓰는 입력이 없는 사건 거래는 다른 충돌을 통해 밀려나야 한다(자손). 아니면 이미 확정·대체됨
    final reachable = {
      for (final c in conflicts) ...c.descendants.map((d) => d.txid),
      for (final u in utxos)
        if (spentByRoot(u) &&
            evictedFees.containsKey(u.transactionHash) &&
            u.transactionHash != u.spentByTransactionHash)
          u.spentByTransactionHash!,
    };
    if (conflicts.isNotEmpty &&
        (direct.isEmpty || conflicts.any((c) => !direct.contains(c) && !reachable.contains(c.txid)))) {
      return blocked(SweepBlocker.conflictConfirmed);
    }

    // 남은 입력: 확정된 unspent·locked. 받는 중(BIP125 규칙 2)·다른 대기 지출이 쓰는 UTXO는 넣지 않는다
    final remaining = [
      for (final u in utxos)
        if ((u.status == UtxoStatus.unspent || u.status == UtxoStatus.locked) && u.blockHeight > 0) u,
    ];
    var inputs = {...conflictInputs, ...remaining}.toList();
    if (inputs.isEmpty) return blocked(SweepBlocker.noInputs);

    final dust = wallet.walletType.addressType.dustThreshold;
    if (_sum(inputs) <= dust) return blocked(SweepBlocker.belowDust, inputs);

    final evictedFeeSum = evictedFees.values.fold(0, (sum, fee) => sum + fee);
    var priced = _price(wallet, inputs.length, direct, evictedFeeSum, fastFeeRate);
    // 더스트이거나 들어가는 데 드는 수수료보다 작은 남은 UTXO는 빼고 한 번만 다시 계산.
    // 입력 하나가 늘리는 수수료는 평균 수수료율이 아니라 한계 수수료율(빠른 수수료·1 sat/vB·충돌 수수료율 중 큰 값)로 센다
    final marginalRate = [
      fastFeeRate,
      RbfBuilder.incrementalRelayFeeRate,
      for (final c in direct) c.feeRate,
    ].reduce(math.max);
    final minWorth = (_inputVSize(wallet) * marginalRate).ceil();
    final kept = [
      for (final u in inputs)
        if (conflictInputs.contains(u) || (u.amount > dust && u.amount > minWorth)) u,
    ];
    if (kept.length != inputs.length) {
      inputs = kept;
      if (inputs.isEmpty) return blocked(SweepBlocker.noInputs);
      if (_sum(inputs) <= dust) return blocked(SweepBlocker.belowDust, inputs);
      priced = _price(wallet, inputs.length, direct, evictedFeeSum, fastFeeRate);
    }

    final amount = _sum(inputs) - priced.fee;
    final blocker =
        priced.vSize > maxVSize
            ? SweepBlocker.tooLarge
            : amount <= 0
            ? SweepBlocker.insufficientForFee
            : amount <= dust
            ? SweepBlocker.belowDust
            : null;

    return SweepPlan(
      inputs: inputs,
      excluded: utxos.where((u) => !inputs.contains(u)).toList(),
      conflicts: conflicts,
      vSize: priced.vSize.toDouble(),
      feeFloor: priced.feeFloor,
      fee: priced.fee,
      feeRate: priced.feeRate,
      amount: amount,
      anyConflictNonSignalling: conflicts.any((c) => !c.signalsRbf),
      blocker: blocker,
    );
  }

  /// 계획 그대로 미서명 거래를 만든다. 모든 입력은 RBF 신호, 출력은 정확히 1개, 수수료는 [SweepPlan.fee]
  static Transaction build(SweepPlan plan, {required WalletItemBase wallet, required String destination}) {
    if (plan.blocker != null) throw StateError('Sweep is blocked: ${plan.blocker!.name}');

    // 수수료 0으로 만든 뒤 정확한 출력 금액을 넣는다. 올림한 수수료율로 먼저 빼면 잔액 부족으로 던질 수 있다(H6)
    final tx = Transaction.forSweep(plan.inputs, destination, 0, wallet.walletBase);
    // ponytail: coconut_lib 1.1.1 forSweep엔 sequence 인자가 없어서 같은 outpoint의 RBF 신호 입력으로 갈아 끼운다(F2).
    // inputs getter가 내부 리스트를 돌려주고 sequence는 4바이트 고정이라 크기·utxoList 대조는 그대로. lib에 인자가 생기면 교체
    final inputs = tx.inputs;
    for (var i = 0; i < inputs.length; i++) {
      inputs[i] = TransactionInput.forPayment(inputs[i].transactionHash, inputs[i].index, sequence: rbfSequence);
    }
    if (tx.outputs.length != 1) throw StateError('Sweep must have exactly one output: ${tx.outputs.length}');
    final output = tx.outputs.single;
    if (Codec.decodeHex(output.serialize()).length > _maxOutputBytes) {
      throw StateError('Destination output is larger than the planned size');
    }
    final amount = tx.totalInputAmount - plan.fee;
    if (amount <= 0) throw StateError('Sweep amount is not positive');
    output.setAmount(amount);
    // 받는 곳 스크립트 기준 더스트(Core와 같은 3 sat/vB)면 서명으로 넘기지 않는다(H5)
    if (output.isDustOutput(isBech32(destination))) throw StateError('Sweep output is dust for the destination');
    return tx;
  }

  static int _sum(List<UtxoState> utxos) => utxos.fold(0, (sum, u) => sum + u.amount);

  /// 입력 하나의 서명 후 vsize 상한(증인 항목 길이 접두사 포함, 올림)
  static int _inputVSize(WalletItemBase wallet) => switch (wallet.walletType) {
    WalletType.singleSignature => (41 * 4 + 1 + (1 + _maxSignature) + (1 + 33) + 3) ~/ 4,
    WalletType.multiSignature => p2wshMultisigInputVSize(
      m: wallet.multisigConfig!.requiredSignature,
      n: wallet.multisigConfig!.totalSigner,
      signatureLength: _maxSignature,
    ),
    WalletType.taproot => p2trInputVSize(spendType: TaprootSpendType.keyPath),
  };

  /// 서명 후 거래 크기 상한(정수 vbyte): 고정부(버전·개수·출력 43바이트·locktime, 증인 marker·flag) + 입력별 상한
  static int _signedVSize(WalletItemBase wallet, int inputCount) {
    int varInt(int v) => v < 0xfd ? 1 : (v <= 0xffff ? 3 : 5);
    final strippedOverhead = 4 + varInt(inputCount) + varInt(1) + _maxOutputBytes + 4;
    return (strippedOverhead * 4 + 2 + 3) ~/ 4 + inputCount * _inputVSize(wallet);
  }

  static ({int vSize, int feeFloor, int fee, double feeRate}) _price(
    WalletItemBase wallet,
    int inputCount,
    List<SweepConflict> direct,
    int evictedFeeSum,
    double fastFeeRate,
  ) {
    final vSize = _signedVSize(wallet, inputCount);
    var feeFloor = evictedFeeSum + (vSize * RbfBuilder.incrementalRelayFeeRate).ceil();
    // 직접 충돌마다 수수료율이 엄격히 더 높게: fee / vSize > c.fee / c.vSize. 충돌 크기는 내림(→ 수수료율을 높게) 잡고 정수로 비교
    for (final c in direct) {
      final weight = BigInt.from(math.max(1, (c.vSize * 4).floor()));
      final minFee = (BigInt.from(c.fee) * BigInt.from(4 * vSize)) ~/ weight + BigInt.one;
      feeFloor = math.max(feeFloor, minFee.toInt());
    }
    final fee = math.max((fastFeeRate * vSize).ceil(), feeFloor);
    // 소수 2자리 올림. 부동소수 오차로 한 칸 더 올라가지 않게 아주 작게 뺀다
    final feeRate = ((fee / vSize) * 100 - 1e-9).ceil() / 100;
    return (vSize: vSize, feeFloor: feeFloor, fee: fee, feeRate: feeRate);
  }
}

enum FeeRateSource { fresh, lastGood, node }

/// 구출 수수료율 고르기와 비율 상한(Grok §4). Assist와 Track I 비상 이동 초안이 같은 규칙을 쓴다
abstract final class SweepFee {
  /// 절대 상한(sat/vB). 넘으면 수수료 API 값이 비정상
  static const maxRate = 1000.0;

  /// 마지막 정상 값의 이 배수를 넘으면 비정상
  static const maxJump = 10;

  /// 수수료가 옮기는 금액의 이 %를 넘으면 그대로는 보내지 않는다
  static const maxSharePercent = 20;

  static bool isSane(double? rate, {double? lastGood}) =>
      rate != null &&
      rate.isFinite &&
      rate >= 0 &&
      rate <= maxRate &&
      (lastGood == null || lastGood <= 0 || rate <= lastGood * maxJump);

  /// 새 값 → 마지막 정상 값 → 노드 추정 순. 모두 쓸 수 없으면 null
  static ({double rate, FeeRateSource source})? choose({double? fresh, double? lastGood, double? node}) {
    final good = isSane(lastGood) ? lastGood : null;
    if (isSane(fresh, lastGood: good)) return (rate: fresh!, source: FeeRateSource.fresh);
    if (good != null) return (rate: good, source: FeeRateSource.lastGood);
    if (isSane(node)) return (rate: node!, source: FeeRateSource.node);
    return null;
  }

  /// 수수료가 받는 금액의 [maxSharePercent]%를 넘음(0.01 BTC 경고와 별개로 막는다)
  static bool isExcessive(SweepPlan plan) => plan.blocker == null && plan.fee * 100 > plan.amount * maxSharePercent;

  /// 대체 하한 그대로인 대체 거래는 [isExcessive]여도 막지 않는다(lead 결정: 막으면 되찾을 수 있던 코인을 잃는다).
  /// 하한을 우리 쪽 값으로만 셌을 때만. 화면은 수수료와 비율을 보여 주고 한 번 더 눌러야 넘긴다
  static bool isFloorExempt(SweepPlan plan) => plan.blocker == null && plan.floorVerified && plan.fee <= plan.feeFloor;
}
