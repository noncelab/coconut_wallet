import 'package:coconut_wallet/ccos/features/ark/ark_exit.dart';
import 'package:flutter_test/flutter_test.dart';

class _Steps implements ArkExitSteps {
  int confirmed = 0;
  int pending = 0;
  ArkExitProgress progress = const ArkExitProgress(
    spent: false,
    onChain: false,
    allClaimable: false,
    claimableHeight: null,
    txDone: 1,
    txTotal: 3,
  );
  final List<String> calls = [];

  @override
  Future<int> exitFeeConfirmedSats() async => confirmed;

  @override
  Future<int> exitFeePendingSats() async => pending;

  @override
  Future<void> startExit(List<String> vtxoIds) async => calls.add('start ${vtxoIds.join(',')}');

  @override
  Future<ArkExitProgress> progressExit(List<String> vtxoIds, int feeRateSatPerVb) async {
    calls.add('progress');
    return progress;
  }

  @override
  Future<({String txid, int feeSats})> claimExit(String address, int feeRateSatPerVb) async {
    calls.add('claim $address');
    return (txid: 'claimtx', feeSats: 300);
  }

  int returned = 0;

  @override
  Future<int> returnExitFee(String address, int feeRateSatPerVb) async {
    calls.add('return $address');
    return returned;
  }
}

ArkExitSession _session({ArkExitPhase phase = ArkExitPhase.funding}) => ArkExitSession(
  vtxoIds: const ['a', 'b'],
  amountSats: 50000,
  destination: 'bcrt1qmine',
  fundingSats: 3000,
  feeRateSatPerVb: 2,
  firstExpiryHeight: 2000,
  startedAt: DateTime(2026, 11, 18),
  phase: phase,
  fundingFeeSats: 200,
  feeWalletId: 5,
  destinationPath: "m/84'/1'/0'/0/7",
);

void main() {
  late _Steps steps;
  setUp(() => steps = _Steps());

  test('waits for the fee funding to confirm, then starts the exit', () async {
    var session = await nextArkExitState(steps, _session(), tipHeight: 1000);
    expect(session.phase, ArkExitPhase.funding);
    expect(steps.calls, isEmpty);

    steps.confirmed = 3000;
    session = await nextArkExitState(steps, session, tipHeight: 1000);
    expect(steps.calls, ['start a,b', 'progress']);
    expect(session.phase, ArkExitPhase.exiting);
    expect((session.txDone, session.txTotal), (1, 3));
  });

  test(
    'once on chain it waits for the delay, then claims to the chosen address and returns the leftover fee',
    () async {
      steps.progress = const ArkExitProgress(
        spent: false,
        onChain: true,
        allClaimable: false,
        claimableHeight: 1144,
        txDone: 3,
        txTotal: 3,
      );
      var session = await nextArkExitState(steps, _session(phase: ArkExitPhase.exiting), tipHeight: 1000);
      expect(session.phase, ArkExitPhase.waiting);
      expect(session.claimableHeight, 1144);

      steps.progress = const ArkExitProgress(
        spent: false,
        onChain: true,
        allClaimable: true,
        claimableHeight: 1144,
        txDone: 3,
        txTotal: 3,
      );
      session = await nextArkExitState(steps, session, tipHeight: 1144);
      expect(session.phase, ArkExitPhase.done);
      expect(session.receivedSats, 49700);
      expect(session.finishedAt, isNotNull);
      expect(session.feeReturned, isTrue);
      expect(steps.calls.sublist(steps.calls.length - 2), ['claim bcrt1qmine', 'return bcrt1qmine']);
    },
  );

  test('the fee paid counts the funding fee, what the fee wallet kept and the claim fee, not what came back', () async {
    steps.returned = 1800;
    steps.progress = const ArkExitProgress(
      spent: false,
      onChain: true,
      allClaimable: true,
      claimableHeight: 1144,
      txDone: 3,
      txTotal: 3,
    );
    final exiting = _session(phase: ArkExitPhase.exiting);
    expect(exiting.paidFeeSats, isNull);

    final session = await nextArkExitState(steps, exiting, tipHeight: 1144);

    expect(session.returnedSats, 1800);
    expect(session.claimTxid, 'claimtx');
    expect(session.paidFeeSats, 200 + (3000 - 1800) + 300);
  });

  test('the transaction count survives bark dropping the list once they are all on chain', () async {
    var session = _session(phase: ArkExitPhase.funding).copyWith(txTotal: 4);
    steps.confirmed = 3000;
    steps.progress = const ArkExitProgress(
      spent: false,
      onChain: false,
      allClaimable: false,
      claimableHeight: null,
      txDone: 0,
      txTotal: 0,
    );
    session = await nextArkExitState(steps, session, tipHeight: 1000);
    expect((session.txDone, session.txTotal), (0, 4));

    steps.progress = const ArkExitProgress(
      spent: false,
      onChain: true,
      allClaimable: false,
      claimableHeight: 1144,
      txDone: 0,
      txTotal: 0,
    );
    session = await nextArkExitState(steps, session, tipHeight: 1010);
    expect((session.txDone, session.txTotal), (4, 4));
  });

  test('a failed exit pays only the fee funding it did not get back', () async {
    steps.returned = 2500;
    final session = await nextArkExitState(steps, _session(phase: ArkExitPhase.exiting), tipHeight: 2000);

    expect(session.paidFeeSats, 200 + 500);
  });

  test('expiring before the exit is on chain fails and still returns the fee', () async {
    final session = await nextArkExitState(steps, _session(phase: ArkExitPhase.exiting), tipHeight: 2000);

    expect(session.phase, ArkExitPhase.failed);
    expect(session.failure, ArkExitFailure.expired);
    expect(session.feeReturned, isTrue);
  });

  test('the leftover fee waits while the fee wallet has unconfirmed funds', () async {
    steps.pending = 500;
    final session = await nextArkExitState(steps, _session(phase: ArkExitPhase.funding), tipHeight: 2000);

    expect(session.phase, ArkExitPhase.failed);
    expect(session.feeReturned, isFalse);
    expect(steps.calls, isEmpty);
  });

  test('a session survives a round trip through storage', () {
    final session = _session(
      phase: ArkExitPhase.waiting,
    ).copyWith(claimableHeight: 1144, txDone: 2, txTotal: 3, returnedSats: 1800);
    final restored = ArkExitSession.fromJson(session.toJson());

    expect(restored.phase, ArkExitPhase.waiting);
    expect(restored.claimableHeight, 1144);
    expect(restored.vtxoIds, ['a', 'b']);
    expect(restored.failure, isNull);
    expect(restored.finishedAt, isNull);
    expect(restored.fundingFeeSats, 200);
    expect(restored.returnedSats, 1800);
    expect(restored.feeWalletId, 5);
    expect(restored.destinationPath, "m/84'/1'/0'/0/7");
  });
}
