import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/extensions/transaction_extension.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';

const _attackTxid = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
const _otherPendingTxid = 'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';
const _externalP2wpkh = 'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx';

String _hash(int i) => i.toRadixString(16).padLeft(64, '0');

UtxoState _utxo(
  WalletItemBase wallet,
  int i,
  int amount, {
  UtxoStatus status = UtxoStatus.unspent,
  int blockHeight = 100,
  String? spentBy,
}) {
  final prefix = wallet.walletBase.derivationPath;
  return UtxoState(
    transactionHash: _hash(i + 1),
    index: i % 3,
    amount: amount,
    derivationPath: '$prefix/0/$i',
    blockHeight: blockHeight,
    to: '',
    timestamp: DateTime(2026, 10, 1),
    status: status,
    spentByTransactionHash: spentBy,
  );
}

SweepConflict _conflict({
  String txid = _attackTxid,
  int fee = 1410,
  double vSize = 141,
  bool signalsRbf = true,
  int descendantCount = 0,
  bool confirmed = false,
}) => SweepConflict(
  txid: txid,
  fee: fee,
  vSize: vSize,
  signalsRbf: signalsRbf,
  descendants: [for (var i = 0; i < descendantCount; i++) (txid: _hash(900 + i), fee: 500, vSize: 110.0)],
  confirmed: confirmed,
);

void _expectRbfSequences(Transaction tx, WalletItemBase wallet) {
  expect(tx.inputs, isNotEmpty);
  expect(tx.inputs.every((i) => i.sequence == SweepBuilder.rbfSequence), isTrue);
  final unsigned = Psbt.fromTransaction(tx, wallet.walletBase).unsignedTransaction!;
  expect(unsigned.inputs.every((i) => i.sequence == SweepBuilder.rbfSequence), isTrue);
  // 서명 전 txid = 전송 txid(F3)
  expect(unsigned.transactionHash, tx.transactionHash);
}

int _fee(Transaction tx) => tx.totalInputAmount - tx.outputs.fold(0, (s, o) => s + o.amount);

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  group('단일서명 대체 구출', () {
    late WalletItemBase wallet;
    setUp(() => wallet = WalletMock.createSingleSigWalletItem());

    test('충돌 입력 + 남은 입력(잠긴 것 포함), 더스트·받는 중·다른 대기 지출 제외, 출력 1개, 모든 입력 RBF 신호', () {
      final stolen = _utxo(wallet, 0, 50000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
      final unspent = _utxo(wallet, 1, 30000);
      final locked = _utxo(wallet, 2, 20000, status: UtxoStatus.locked);
      final dust = _utxo(wallet, 3, 294);
      final incoming = _utxo(wallet, 4, 40000, status: UtxoStatus.incoming, blockHeight: 0);
      final otherPending = _utxo(
        wallet,
        5,
        60000,
        status: UtxoStatus.outgoing,
        blockHeight: 0,
        spentBy: _otherPendingTxid,
      );
      final conflict = _conflict();

      final plan = SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen, unspent, locked, dust, incoming, otherPending],
        conflicts: [conflict],
        fastFeeRate: 5,
      );

      expect(plan.blocker, isNull);
      expect(plan.inputs.toSet(), {stolen, unspent, locked});
      expect(plan.excluded.toSet(), {dust, incoming, otherPending});
      expect(plan.fee, greaterThanOrEqualTo(plan.feeFloor));
      // 우리 거래(입력 3개)가 충돌보다 커서 하한은 수수료율 규칙(충돌 10 sat/vB보다 엄격히 높게)이 정한다
      expect(plan.feeFloor, greaterThan(conflict.fee + plan.vSize.ceil()));
      expect(plan.feeFloor, (conflict.fee * 4 * plan.vSize.toInt()) ~/ (conflict.vSize * 4).floor() + 1);
      expect(plan.fee / plan.vSize, greaterThan(conflict.feeRate));
      expect(plan.amount, 100000 - plan.fee);
      expect(plan.anyConflictNonSignalling, isFalse);

      final tx = SweepBuilder.build(plan, wallet: wallet, destination: _externalP2wpkh);
      expect(tx.outputs.length, 1);
      expect(tx.outputs.single.getAddress(), _externalP2wpkh);
      expect(_fee(tx), plan.fee);
      _expectRbfSequences(tx, wallet);
      // 실제 크기(작은 목적지 출력)로도 하한·수수료율 규칙 유지
      final actualVSize = tx.estimateVirtualByteForWallet(wallet);
      expect(actualVSize, lessThanOrEqualTo(plan.vSize));
      expect(_fee(tx), greaterThanOrEqualTo(conflict.fee + actualVSize.ceil()));
      expect(_fee(tx) / actualVSize, greaterThan(conflict.feeRate));
    });

    test('수수료 = max(빠른 수수료, 하한(자손 포함), 충돌 수수료율 초과)', () {
      final stolen = _utxo(wallet, 0, 500000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
      final unspent = _utxo(wallet, 1, 300000);

      // 빠른 수수료가 가장 큼
      var plan = SweepBuilder.plan(wallet: wallet, utxos: [stolen, unspent], conflicts: [_conflict()], fastFeeRate: 80);
      expect(plan.fee, (80 * plan.vSize).ceil());

      // 자손 수수료 합이 커서 하한이 정함
      final heavy = _conflict(fee: 1410, vSize: 141, descendantCount: 20); // 자손 20 × 500
      plan = SweepBuilder.plan(wallet: wallet, utxos: [stolen, unspent], conflicts: [heavy], fastFeeRate: 2);
      expect(plan.fee, 1410 + 20 * 500 + plan.vSize.ceil());
      expect(plan.fee, plan.feeFloor);

      // 충돌 수수료율(100 sat/vB)이 정함: 엄격히 더 큼
      final pricey = _conflict(fee: 14100, vSize: 141);
      plan = SweepBuilder.plan(wallet: wallet, utxos: [stolen, unspent], conflicts: [pricey], fastFeeRate: 2);
      expect(plan.fee, (100 * plan.vSize).floor() + 1);
      expect(plan.feeFloor, plan.fee); // 하한에 수수료율 규칙도 들어 있다
      expect(plan.fee / plan.vSize, greaterThan(100));
      expect(plan.feeRate, greaterThanOrEqualTo(plan.fee / plan.vSize));
    });

    test('수수료보다 작은 남은 UTXO는 빼고 한 번 다시 계산(충돌 입력은 작아도 유지)', () {
      final stolen = _utxo(wallet, 0, 1500, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
      final small = _utxo(wallet, 1, 2000); // 68 vB × 50 sat/vB = 3400보다 작음
      final big = _utxo(wallet, 2, 300000);

      final plan = SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen, small, big],
        conflicts: [_conflict()],
        fastFeeRate: 50,
      );
      expect(plan.blocker, isNull);
      expect(plan.inputs.toSet(), {stolen, big});
      expect(plan.excluded, [small]);
      expect(plan.fee, (50 * plan.vSize).ceil());
    });

    test('충돌이 없으면 수수료 = max(빠른 수수료, 1 sat/vB)', () {
      final unspent = _utxo(wallet, 0, 80000);
      var plan = SweepBuilder.plan(wallet: wallet, utxos: [unspent], conflicts: [], fastFeeRate: 3);
      expect(plan.fee, (3 * plan.vSize).ceil());
      expect(plan.feeFloor, plan.vSize.ceil());
      plan = SweepBuilder.plan(wallet: wallet, utxos: [unspent], conflicts: [], fastFeeRate: 0.5);
      expect(plan.fee, plan.vSize.ceil());
      final tx = SweepBuilder.build(plan, wallet: wallet, destination: _externalP2wpkh);
      expect(_fee(tx), plan.fee);
      _expectRbfSequences(tx, wallet);
    });

    test('원거래가 RBF 신호를 안 켰으면 표시', () {
      final stolen = _utxo(wallet, 0, 50000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
      final plan = SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen],
        conflicts: [_conflict(signalsRbf: false)],
        fastFeeRate: 5,
      );
      expect(plan.blocker, isNull);
      expect(plan.anyConflictNonSignalling, isTrue);
    });
  });

  group('막힘', () {
    late WalletItemBase wallet;
    setUp(() => wallet = WalletMock.createSingleSigWalletItem());

    test('확정된 충돌 → conflictConfirmed, 남은 코인만은 계획됨', () {
      final unspent = _utxo(wallet, 1, 30000);
      // 확정 표시
      var plan = SweepBuilder.plan(
        wallet: wallet,
        utxos: [unspent],
        conflicts: [_conflict(confirmed: true)],
        fastFeeRate: 5,
      );
      expect(plan.blocker, SweepBlocker.conflictConfirmed);
      expect(() => SweepBuilder.build(plan, wallet: wallet, destination: _externalP2wpkh), throwsStateError);
      // 확정돼서 로컬에 나가는 중 UTXO가 사라진 경우도 같음
      plan = SweepBuilder.plan(wallet: wallet, utxos: [unspent], conflicts: [_conflict()], fastFeeRate: 5);
      expect(plan.blocker, SweepBlocker.conflictConfirmed);

      plan = SweepBuilder.plan(wallet: wallet, utxos: [unspent], conflicts: [], fastFeeRate: 5);
      expect(plan.blocker, isNull);
      expect(plan.inputs, [unspent]);
    });

    test('자손 25개 초과 → tooManyDescendants', () {
      final stolen = _utxo(wallet, 0, 500000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
      final plan = SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen],
        conflicts: [_conflict(descendantCount: SweepBuilder.maxDescendants + 1)],
        fastFeeRate: 5,
      );
      expect(plan.blocker, SweepBlocker.tooManyDescendants);
    });

    test('입력 없음 / 더스트 / 수수료 부족', () {
      expect(
        SweepBuilder.plan(wallet: wallet, utxos: [], conflicts: [], fastFeeRate: 5).blocker,
        SweepBlocker.noInputs,
      );
      expect(
        SweepBuilder.plan(wallet: wallet, utxos: [_utxo(wallet, 0, 200)], conflicts: [], fastFeeRate: 5).blocker,
        SweepBlocker.belowDust,
      );
      // 남은 UTXO가 모두 더스트면 빼고 나서 입력 없음
      expect(
        SweepBuilder.plan(
          wallet: wallet,
          utxos: [_utxo(wallet, 0, 200), _utxo(wallet, 1, 250)],
          conflicts: [],
          fastFeeRate: 5,
        ).blocker,
        SweepBlocker.noInputs,
      );
      // 상대가 낸 수수료가 내 코인보다 큼
      final stolen = _utxo(wallet, 0, 50000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
      final plan = SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen],
        conflicts: [_conflict(fee: 49900, vSize: 141)],
        fastFeeRate: 5,
      );
      expect(plan.blocker, SweepBlocker.insufficientForFee);
      expect(() => SweepBuilder.build(plan, wallet: wallet, destination: _externalP2wpkh), throwsStateError);
    });

    test('입력이 너무 많으면 tooLarge', () {
      final utxos = [for (var i = 0; i < 1400; i++) _utxo(wallet, i, 100000)];
      final plan = SweepBuilder.plan(wallet: wallet, utxos: utxos, conflicts: [], fastFeeRate: 2);
      expect(plan.vSize, greaterThan(SweepBuilder.maxVSize));
      expect(plan.blocker, SweepBlocker.tooLarge);
    });

    test('스크립트 경로 전용 탭루트 → unsupportedWallet', () {
      final taproot = WalletMock.createTaprootWalletItem(hasKeyPathSeedInfo: false);
      final plan = SweepBuilder.plan(wallet: taproot, utxos: [_utxo(taproot, 0, 50000)], conflicts: [], fastFeeRate: 2);
      expect(plan.blocker, SweepBlocker.unsupportedWallet);
    });
  });

  test('다중서명 대체 구출: 출력 1개, PSBT 미서명 거래까지 RBF 신호', () {
    final multisig = WalletMock.createMultiSigWalletItem();
    final stolen = _utxo(multisig, 0, 80000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
    final locked = _utxo(multisig, 1, 40000, status: UtxoStatus.locked);
    final conflict = _conflict(fee: 2000, vSize: 200);

    final plan = SweepBuilder.plan(wallet: multisig, utxos: [stolen, locked], conflicts: [conflict], fastFeeRate: 3);
    expect(plan.blocker, isNull);
    expect(plan.inputs.toSet(), {stolen, locked});

    final tx = SweepBuilder.build(plan, wallet: multisig, destination: _externalP2wpkh);
    expect(tx.outputs.length, 1);
    expect(_fee(tx), plan.fee);
    expect(_fee(tx) / tx.estimateVirtualByteForWallet(multisig), greaterThan(conflict.feeRate));
    _expectRbfSequences(tx, multisig);
  });

  test('43바이트 목적지에서도 계획 크기는 서명 전 추정 이상(정수 vbyte 상한)', () {
    final wallet = WalletMock.createSingleSigWalletItem();
    final p2wshDestination = WalletMock.createMultiSigWalletItem().walletBase.getAddress(5);
    final plan = SweepBuilder.plan(wallet: wallet, utxos: [_utxo(wallet, 0, 70000)], conflicts: [], fastFeeRate: 4);
    final tx = SweepBuilder.build(plan, wallet: wallet, destination: p2wshDestination);
    expect(plan.vSize, plan.vSize.roundToDouble());
    expect(tx.estimateVirtualByteForWallet(wallet), lessThanOrEqualTo(plan.vSize));
    expect(_fee(tx), plan.fee);
    _expectRbfSequences(tx, wallet);
  });

  test('서명·완성 뒤에도 RBF 신호와 txid가 그대로(기존 전송 검증 통과)', () {
    final vault = SingleSignatureVault.random();
    final wallet = SinglesigWalletItem(id: 7, name: 'hot', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor);
    final stolen = _utxo(wallet, 0, 90000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
    final unspent = _utxo(wallet, 1, 15000);
    final plan = SweepBuilder.plan(wallet: wallet, utxos: [stolen, unspent], conflicts: [_conflict()], fastFeeRate: 6);
    final tx = SweepBuilder.build(plan, wallet: wallet, destination: _externalP2wpkh);

    final unsigned = Psbt.fromTransaction(tx, wallet.walletBase);
    final signed = Psbt.parse(vault.addSignatureToPsbt(unsigned.serialize())).getSignedTransaction(AddressType.p2wpkh);

    TransactionIntentValidator.ensureMatches(unsigned.unsignedTransaction, signed);
    expect(signed.inputs.every((i) => i.sequence == SweepBuilder.rbfSequence), isTrue);
    expect(signed.transactionHash, tx.transactionHash);
    expect(signed.outputs.single.amount, 105000 - plan.fee);
  });

  group('GPT 리뷰 회귀(H1–H6)', () {
    late WalletItemBase wallet;
    setUp(() => wallet = WalletMock.createSingleSigWalletItem());

    test('H1: 공유 자손·자손이기도 한 사건 거래는 수수료 하한에 한 번만', () {
      const a =
          'aa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const b =
          'bb'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const shared =
          'cc'
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      final utxos = [
        _utxo(wallet, 0, 300000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: a),
        _utxo(wallet, 1, 300000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: b),
        _utxo(wallet, 2, 100000),
      ];
      const child = (txid: shared, fee: 10000, vSize: 200.0);
      var plan = SweepBuilder.plan(
        wallet: wallet,
        utxos: utxos,
        conflicts: const [
          SweepConflict(txid: a, fee: 1000, vSize: 141, signalsRbf: true, descendants: [child]),
          SweepConflict(txid: b, fee: 1000, vSize: 141, signalsRbf: true, descendants: [child]),
        ],
        fastFeeRate: 1,
      );
      expect(plan.blocker, isNull);
      expect(plan.feeFloor, 12000 + plan.vSize.toInt());
      expect(plan.fee, plan.feeFloor);
      final tx = SweepBuilder.build(plan, wallet: wallet, destination: _externalP2wpkh);
      expect(tx.outputs.single.amount, 700000 - plan.fee);

      // b가 a의 자손으로도 들어온 경우
      plan = SweepBuilder.plan(
        wallet: wallet,
        utxos: utxos,
        conflicts: const [
          SweepConflict(
            txid: a,
            fee: 1000,
            vSize: 141,
            signalsRbf: true,
            descendants: [(txid: b, fee: 1000, vSize: 141.0)],
          ),
          SweepConflict(txid: b, fee: 1000, vSize: 141, signalsRbf: true),
        ],
        fastFeeRate: 1,
      );
      expect(plan.feeFloor, 2000 + plan.vSize.toInt());
    });

    test('H3: 사건 A가 만든 잔돈을 사건 B가 쓰면 그 잔돈은 입력에서 빠지고 B는 A의 자손으로 밀려남', () {
      const a =
          'aa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const b =
          'bb'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final u = _utxo(wallet, 0, 500000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: a);
      // A의 출력(우리 잔돈) V를 B가 씀
      final v = UtxoState(
        transactionHash: a,
        index: 1,
        amount: 200000,
        derivationPath: '${wallet.walletBase.derivationPath}/1/0',
        blockHeight: 0,
        to: '',
        timestamp: DateTime(2026, 10, 1),
        status: UtxoStatus.outgoing,
        spentByTransactionHash: b,
      );
      final w = _utxo(wallet, 2, 100000);
      final plan = SweepBuilder.plan(
        wallet: wallet,
        utxos: [u, v, w],
        conflicts: const [
          SweepConflict(txid: a, fee: 1410, vSize: 141, signalsRbf: true),
          SweepConflict(txid: b, fee: 2000, vSize: 110, signalsRbf: true),
        ],
        fastFeeRate: 2,
      );
      expect(plan.blocker, isNull);
      expect(plan.inputs.toSet(), {u, w});
      // 고른 입력은 모두 밀려날 거래가 만든 것이 아니다
      expect(plan.inputs.every((i) => i.transactionHash != a && i.transactionHash != b), isTrue);
      expect(plan.amount, 600000 - plan.fee);
      expect(plan.feeFloor, 1410 + 2000 + plan.vSize.toInt());
      // 직접 충돌(A) 수수료율만 엄격히 넘는다
      expect(plan.fee / plan.vSize, greaterThan(1410 / 141));
    });

    test('H4: 자손 한도는 모든 충돌을 합치고 사건 거래까지 센다', () {
      List<SweepConflict> roots(int rootCount, int each) => [
        for (var r = 0; r < rootCount; r++)
          SweepConflict(
            txid: _hash(5000 + r),
            fee: 1000,
            vSize: 141,
            signalsRbf: true,
            descendants: [for (var d = 0; d < each; d++) (txid: _hash(6000 + r * 100 + d), fee: 300, vSize: 110.0)],
          ),
      ];
      List<UtxoState> stolen(int rootCount) => [
        for (var r = 0; r < rootCount; r++)
          _utxo(wallet, r, 400000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _hash(5000 + r)),
      ];
      // 5개 × (1 + 4) = 25 → 허용
      var plan = SweepBuilder.plan(wallet: wallet, utxos: stolen(5), conflicts: roots(5, 4), fastFeeRate: 2);
      expect(plan.blocker, isNull);
      // 5개 × (1 + 5) = 30 → 막힘(충돌마다 20개 이하라도)
      plan = SweepBuilder.plan(wallet: wallet, utxos: stolen(5), conflicts: roots(5, 5), fastFeeRate: 2);
      expect(plan.blocker, SweepBlocker.tooManyDescendants);
    });

    test('H5: 받는 곳 스크립트 기준 더스트면 만들지 않음(P2WPKH → P2WSH·레거시 경계)', () {
      // 입력 1개, 충돌 없음, 1 sat/vB → 수수료 = vSize. 출력 300 sats(원 지갑 기준 294 초과라 계획은 통과)
      final probe = SweepBuilder.plan(wallet: wallet, utxos: [_utxo(wallet, 0, 100000)], conflicts: [], fastFeeRate: 1);
      final fee = probe.fee;
      SweepPlan planFor(int output) =>
          SweepBuilder.plan(wallet: wallet, utxos: [_utxo(wallet, 0, output + fee)], conflicts: [], fastFeeRate: 1);
      final p2wsh = WalletMock.createMultiSigWalletItem().walletBase.getAddress(3);
      final legacy = SingleSignatureVault.fromEntropy(
        Uint8List.fromList(List.filled(16, 3)),
        addressType: AddressType.p2pkh,
      ).getAddress(0);

      var plan = planFor(300);
      expect(plan.blocker, isNull);
      expect(SweepBuilder.build(plan, wallet: wallet, destination: _externalP2wpkh).outputs.single.amount, 300);
      expect(() => SweepBuilder.build(plan, wallet: wallet, destination: p2wsh), throwsStateError);
      expect(() => SweepBuilder.build(plan, wallet: wallet, destination: legacy), throwsStateError);

      plan = planFor(331);
      expect(SweepBuilder.build(plan, wallet: wallet, destination: p2wsh).outputs.single.amount, 331);
      plan = planFor(547);
      expect(SweepBuilder.build(plan, wallet: wallet, destination: legacy).outputs.single.amount, 547);
    });

    test('H6: 입력이 많고 출력이 더스트 바로 위여도 정확히 plan.fee로 만들어짐', () {
      final remaining = [for (var i = 1; i <= 300; i++) _utxo(wallet, i, 2000)];
      final stolen = _utxo(wallet, 0, 50000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
      const total = 50000 + 300 * 2000;
      // 크기를 먼저 재고, 하한이 정해지게 충돌 수수료를 골라 출력이 331 sats가 되게 한다
      final sized = SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen, ...remaining],
        conflicts: const [SweepConflict(txid: _attackTxid, fee: 1, vSize: 400000, signalsRbf: true)],
        fastFeeRate: 1,
      );
      final conflictFee = total - sized.vSize.toInt() - 331;
      final plan = SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen, ...remaining],
        conflicts: [SweepConflict(txid: _attackTxid, fee: conflictFee, vSize: 400000, signalsRbf: true)],
        fastFeeRate: 1,
      );
      expect(plan.blocker, isNull);
      expect(plan.inputs.length, 301);
      expect(plan.amount, 331);
      final tx = SweepBuilder.build(
        plan,
        wallet: wallet,
        destination: WalletMock.createMultiSigWalletItem().walletBase.getAddress(1),
      );
      expect(_fee(tx), plan.fee);
      expect(tx.outputs.single.amount, 331);
      _expectRbfSequences(tx, wallet);
    });
  });

  group('H2: 계획 크기 ≥ 실제 서명된 거래 크기(정수 vbyte)', () {
    // 그룹 본문은 선언 때 돌아서 regtest 설정 뒤(setUpAll)에 만든다
    late final Map<String, (WalletItemBase, WalletBase, AddressType)> signers;
    late final String p2wshDestination;
    setUpAll(() {
      final singleVault = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 9)));
      final multiVault = MultisignatureVault.fromKeyStoreList([
        for (final seed in [21, 22, 23])
          KeyStore.fromEntropy(Uint8List.fromList(List.filled(16, seed)), AddressType.p2wsh),
      ], 2);
      signers = {
        '단일서명': (
          SinglesigWalletItem(id: 11, name: 'single', colorIndex: 0, iconIndex: 0, descriptor: singleVault.descriptor),
          singleVault,
          AddressType.p2wpkh,
        ),
        '2-of-3 다중서명': (
          MultisigWalletItem(
            id: 12,
            name: 'multi',
            colorIndex: 0,
            iconIndex: 0,
            descriptor: multiVault.descriptor,
            signers: [for (var i = 0; i < 3; i++) MultisigSigner(name: 's$i', iconIndex: 0, colorIndex: 0)],
            requiredSignatureCount: 2,
          ),
          multiVault,
          AddressType.p2wsh,
        ),
      };
      p2wshDestination = WalletMock.createMultiSigWalletItem().walletBase.getAddress(7);
    });

    for (final name in ['단일서명', '2-of-3 다중서명']) {
      for (final inputCount in [1, 4]) {
        for (final toP2wsh in [false, true]) {
          test('$name 입력 $inputCount개 → ${toP2wsh ? 'p2wsh' : 'p2wpkh'}', () {
            final (wallet, signer, addressType) = signers[name]!;
            final stolen = _utxo(wallet, 0, 90000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
            final rest = [for (var i = 1; i < inputCount; i++) _utxo(wallet, i, 40000)];
            const conflict = SweepConflict(txid: _attackTxid, fee: 11000, vSize: 110, signalsRbf: true);
            final plan = SweepBuilder.plan(
              wallet: wallet,
              utxos: [stolen, ...rest],
              conflicts: const [conflict],
              fastFeeRate: 1,
            );
            expect(plan.blocker, isNull);
            final tx = SweepBuilder.build(
              plan,
              wallet: wallet,
              destination: toP2wsh ? p2wshDestination : _externalP2wpkh,
            );
            final psbt = Psbt.fromTransaction(tx, wallet.walletBase);
            final signed = Psbt.parse(signer.addSignatureToPsbt(psbt.serialize())).getSignedTransaction(addressType);

            final actual = _signedVSize(signed);
            expect(plan.vSize, greaterThanOrEqualTo(actual));
            expect(signed.transactionHash, tx.transactionHash);
            expect(signed.inputs.every((i) => i.sequence == SweepBuilder.rbfSequence), isTrue);
            // 정수 크기로도 엄격히 더 높은 수수료율과 하한(충돌 수수료 + 1 sat/vB × 크기)
            expect(plan.fee * 110, greaterThan(11000 * actual));
            expect(plan.fee, greaterThanOrEqualTo(11000 + actual));
          });
        }
      }
    }
  });

  group('lead: 대체 하한 20% 예외', () {
    late WalletItemBase wallet;
    late UtxoState stolen;
    setUp(() {
      wallet = WalletMock.createSingleSigWalletItem();
      stolen = _utxo(wallet, 0, 100000, status: UtxoStatus.outgoing, blockHeight: 0, spentBy: _attackTxid);
    });

    // 상대가 약 110 vB를 200 sat/vB로(수수료 22,000) 가져가는 중. 되찾으려면 하한만으로도 받는 금액의 20%를 넘는다
    SweepConflict attack({bool verified = true, List<({String txid, int fee, double vSize})> descendants = const []}) =>
        SweepConflict(
          txid: _attackTxid,
          fee: 22000,
          vSize: 110,
          signalsRbf: true,
          feeVerified: verified,
          descendants: descendants,
        );

    test('확인한 하한(수수료율 규칙 포함) 그대로면 20%를 넘어도 예외', () {
      final plan = SweepBuilder.plan(wallet: wallet, utxos: [stolen], conflicts: [attack()], fastFeeRate: 4);
      expect(plan.blocker, isNull);
      // 우리 거래가 상대보다 커서 수수료율 규칙(200 sat/vB 초과)이 하한을 정한다
      expect(plan.feeFloor, (22000 * 4 * plan.vSize.toInt()) ~/ 440 + 1);
      expect(plan.feeFloor, greaterThan(22000 + plan.vSize.toInt()));
      expect(plan.fee, plan.feeFloor);
      expect(SweepFee.isExcessive(plan), isTrue);
      expect(plan.floorVerified, isTrue);
      expect(SweepFee.isFloorExempt(plan), isTrue);
    });

    test('확인 안 된 충돌이 하나라도 있거나 대체 아닌 이동이면 예외 아님(자손 확인은 ConflictAnalyzer가 feeVerified에)', () {
      final unverified = SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen],
        conflicts: [attack(verified: false)],
        fastFeeRate: 4,
      );
      expect(SweepFee.isExcessive(unverified), isTrue);
      expect(SweepFee.isFloorExempt(unverified), isFalse);

      // 이어진 다른 사건 거래(자손이기도 함)가 미확인이면 하한 전체가 미확인
      final mixed = SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen],
        conflicts: [
          attack(descendants: [(txid: _otherPendingTxid, fee: 500, vSize: 110.0)]),
          const SweepConflict(txid: _otherPendingTxid, fee: 500, vSize: 110, signalsRbf: true),
        ],
        fastFeeRate: 4,
      );
      expect(mixed.blocker, isNull);
      expect(mixed.floorVerified, isFalse);
      expect(SweepFee.isFloorExempt(mixed), isFalse);

      final moveOnly = SweepBuilder.plan(
        wallet: wallet,
        utxos: [_utxo(wallet, 1, 2000)],
        conflicts: const [],
        fastFeeRate: 10,
      );
      expect(SweepFee.isExcessive(moveOnly), isTrue);
      expect(SweepFee.isFloorExempt(moveOnly), isFalse);
    });

    test('고른 수수료율이 하한 위라 20%를 넘으면 예외 아님, 수수료율 0으로 다시 계획하면 하한(계속 대체)', () {
      const cheap = SweepConflict(txid: _attackTxid, fee: 1410, vSize: 141, signalsRbf: true, feeVerified: true);
      final fast = SweepBuilder.plan(wallet: wallet, utxos: [stolen], conflicts: const [cheap], fastFeeRate: 300);
      expect(fast.fee, greaterThan(fast.feeFloor));
      expect(SweepFee.isExcessive(fast), isTrue);
      expect(SweepFee.isFloorExempt(fast), isFalse);

      final floor = SweepBuilder.plan(wallet: wallet, utxos: [stolen], conflicts: const [cheap], fastFeeRate: 0);
      expect(floor.fee, floor.feeFloor);
      expect(floor.inputs, [stolen]);
      expect(SweepFee.isExcessive(floor), isFalse);
    });
  });
}

/// 서명된 거래의 실제 vsize = ceil((stripped×4 + witness) / 4). 증인은 항목 길이 접두사까지 직접 센다
int _signedVSize(Transaction tx) {
  int varInt(int v) => v < 0xfd ? 1 : 3;
  final total = Codec.decodeHex(tx.serialize()).length;
  var witness = 2; // marker + flag
  for (final input in tx.inputs) {
    witness += varInt(input.witnessList.length);
    for (final item in input.witnessList) {
      final length = item == '00' ? 0 : item.length ~/ 2;
      witness += varInt(length) + length;
    }
  }
  return ((total - witness) * 4 + witness + 3) ~/ 4;
}
