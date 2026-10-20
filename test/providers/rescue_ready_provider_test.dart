import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/safety/safety_assist.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/safety/safety_fakes.dart';

const _attackTxid = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
const _external = 'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx';

Uint8List _entropy(int seed) => Uint8List.fromList(List.filled(16, seed));

SinglesigWalletItem _single(int id, int seed, {int accountIndex = 0, bool hot = false}) {
  final vault = SingleSignatureVault.fromEntropy(_entropy(seed), accountIndex: accountIndex);
  return SinglesigWalletItem(
    id: id,
    name: 'w$id',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: vault.descriptor,
    hotWalletMetadata:
        hot
            ? HotWalletMetadata(
              walletId: id,
              secureStorageKey: 'k$id',
              masterFingerprint: vault.keyStore.masterFingerprint,
              derivationPath: vault.derivationPath,
              accountIndex: accountIndex,
              backupVerified: true,
              enterPassphraseWhenSigning: false,
              createdAt: DateTime(2026, 10, 1),
            )
            : null,
  );
}

SinglesigWalletItem _withoutMfp(int id, int seed) {
  final xpub = SingleSignatureVault.fromEntropy(_entropy(seed)).keyStore.extendedPublicKey.serialize();
  final wallet = SingleSignatureWallet.fromExtendedPublicKey(
    AddressType.p2wpkh,
    xpub,
    WalletAddService.masterFingerprintPlaceholder,
  );
  return SinglesigWalletItem(id: id, name: 'w$id', colorIndex: 0, iconIndex: 0, descriptor: wallet.descriptor);
}

MultisigWalletItem _multisig(int id, List<int> seeds) {
  final vault = MultisignatureVault.fromKeyStoreList([
    for (final s in seeds) KeyStore.fromEntropy(_entropy(s), AddressType.p2wsh),
  ], 2);
  return MultisigWalletItem(
    id: id,
    name: 'w$id',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: vault.descriptor,
    signers: [for (var i = 0; i < seeds.length; i++) MultisigSigner(name: 's$i', iconIndex: 0, colorIndex: 0)],
    requiredSignatureCount: 2,
  );
}

WatchOnlyVerification _verification(WalletItemBase wallet, VerificationResult result, {String? descriptorHash}) =>
    WatchOnlyVerification(
      method: VerificationMethod.qr,
      result: result,
      matchedIndex: 0,
      descriptorHash: descriptorHash ?? WalletVerification.descriptorHash(wallet.descriptor),
      at: DateTime(2026, 10, 20),
    );

UtxoState _utxo(
  WalletItemBase wallet,
  int i,
  int amount, {
  UtxoStatus status = UtxoStatus.unspent,
  int blockHeight = 100,
  String? spentBy,
}) => UtxoState(
  transactionHash: (i + 1).toRadixString(16).padLeft(64, '0'),
  index: 0,
  amount: amount,
  derivationPath: '${wallet.walletBase.derivationPath}/0/$i',
  blockHeight: blockHeight,
  to: '',
  timestamp: DateTime(2026, 10, 1),
  status: status,
  spentByTransactionHash: spentBy,
);

class _Wallets extends SafetyWalletsFake {
  _Wallets(super.wallets);

  /// 주소 → 그 주소를 가진 지갑들(같은 디스크립터를 핫·보기 전용으로 둘 다 가질 수 있다)
  final owners = <String, Set<int>>{};

  // 아직 생성된 주소가 없으면 SafetyAssist가 다음 인덱스를 직접 도출한다
  @override
  WalletAddress getReceiveAddress(int walletId) => throw StateError('no generated address');

  @override
  int? findWalletIdContainingAddress(String address) => owners[address]?.first;

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => owners[address]?.contains(walletId) ?? false;
}

/// 전송이 한 번이라도 불리면 테스트가 깨진다
class _Node extends SafetyNodeFake {
  int broadcasts = 0;

  /// 노드 수수료 추정(sat/vB). null이면 실패
  double? nodeFee;

  @override
  Future<Result<RecommendedFee>> getRecommendedFees() async =>
      nodeFee == null
          ? throw StateError('node offline')
          : Result.success(RecommendedFee(nodeFee, nodeFee, nodeFee, nodeFee, 1));

  @override
  Future<Result<String>> broadcast(Transaction signedTx) {
    broadcasts++;
    throw StateError('Rescue-ready must never broadcast');
  }
}

/// 앱 생성 txid·전송 기록이 불리면 테스트가 깨진다(초안은 서명용 PSBT가 아님)
class _Store extends SafetyStoreFake {
  @override
  Future<void> recordAppCreatedTxid(int walletId, String txid) => throw StateError('must not record txids');

  @override
  Future<void> recordBroadcastSucceeded(int walletId, String txid) => throw StateError('must not record broadcasts');
}

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  late SinglesigWalletItem source, vault, sameSeed, noMfp, caution, otherHot;
  late _Wallets wallets;
  late _Node node;
  late _Store store;
  late FakeEntitlementService premium;
  late DateTime clock;
  late List<double?> fees; // 차례로 돌려줄 빠른 수수료(null = 실패)
  late int feeCalls;
  Completer<void>? feeGate;
  RescueReadyProvider? provider;

  Future<RecommendedFee?> fetchFees() async {
    feeCalls++;
    if (feeGate != null) await feeGate!.future;
    final fee = fees.isEmpty ? null : fees.removeAt(0);
    if (fee == null) throw StateError('offline');
    return RecommendedFee(fee, fee, fee, fee, 1);
  }

  // 주소 도출 확인은 앞 60개만(테스트 시간). 도출 범위 자체는 아래 테스트가 따로 본다
  RescueReadyProvider build({Duration interval = const Duration(minutes: 5)}) =>
      provider = RescueReadyProvider(
        walletProvider: wallets,
        nodeProvider: node,
        entitlement: premium,
        store: store,
        fetchFees: fetchFees,
        feeRefreshInterval: interval,
        now: () => clock,
        derivedAddressDepth: 60,
      );

  void setRescue(int walletId, RescueDestination d) =>
      store.state = store.state.copyWith(rescue: {...store.state.rescue, walletId: (destination: d, draft: null)});

  Future<void> syncCompleted() async {
    node.sync.add(NodeSyncState.completed);
    await pumpEventQueue();
  }

  setUp(() {
    source = _single(1, 1, hot: true);
    vault = _single(2, 2);
    sameSeed = _single(3, 1, accountIndex: 1); // 같은 니모닉, 다른 계정 → 같은 MFP
    noMfp = _withoutMfp(4, 4);
    caution = _single(5, 5);
    otherHot = _single(6, 6, hot: true);
    wallets = _Wallets([source, vault, sameSeed, noMfp, caution, otherHot]);
    wallets.utxos[1] = [_utxo(source, 0, 100000), _utxo(source, 1, 50000)];
    node = _Node();
    store = _Store();
    store.state = store.state.copyWith(cautionWalletIds: {5});
    premium = FakeEntitlementService(initial: const PremiumState(PremiumStatus.active));
    clock = DateTime(2026, 10, 20, 12);
    fees = [10, 10, 10, 10, 10];
    feeCalls = 0;
    feeGate = null;
  });

  tearDown(() {
    provider?.dispose();
    provider = null;
    wallets.dispose();
    node.dispose();
  });

  RescueDestination toVault() => RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20));

  group('재계산', () {
    test('Premium이 아니면 어떤 계기에도 재계산하지 않는다', () async {
      premium.emit(const PremiumState(PremiumStatus.expired));
      setRescue(1, toVault());
      final p = build();
      await syncCompleted();
      wallets.walletItemListNotifier.value = [...wallets.walletItemList];
      await pumpEventQueue();

      expect(feeCalls, 0);
      expect(store.state.rescue[1]!.draft, isNull);
      expect(p.statusOf(1), RescueStatus.paused);
    });

    test('동기화 완료(F6: 연결 + 등록 지갑)·지갑 목록 변경·권한 활성화마다 재계산한다', () async {
      setRescue(1, toVault());
      build(interval: Duration.zero);

      // 오프라인 시작도 completed라서 연결·등록 지갑이 없으면 거른다
      node.connected = false;
      await syncCompleted();
      node.connected = true;
      final registered = node.state;
      node.state = const NodeProviderState(nodeSyncState: NodeSyncState.completed, registeredWallets: {});
      await syncCompleted();
      expect(feeCalls, 0);

      node.state = registered;
      await syncCompleted();
      expect(feeCalls, 1);
      expect(store.state.rescue[1]!.draft, isNotNull);

      wallets.walletItemListNotifier.value = [...wallets.walletItemList];
      await pumpEventQueue();
      expect(feeCalls, 2);

      premium.emit(const PremiumState(PremiumStatus.expired));
      await pumpEventQueue();
      expect(feeCalls, 2);
      premium.emit(const PremiumState(PremiumStatus.active)); // 권한 활성화
      await pumpEventQueue();
      expect(feeCalls, 3);
    });

    test('빠른 수수료는 5분 스로틀, 실패하면 마지막 수수료로 계산한다', () async {
      setRescue(1, toVault());
      fees = [10, null, 12];
      final p = build();

      await syncCompleted();
      expect(feeCalls, 1);
      final first = store.state.rescue[1]!.draft!;

      clock = clock.add(const Duration(minutes: 4));
      await syncCompleted();
      expect(feeCalls, 1, reason: '5분 안에는 다시 받지 않는다');
      expect(store.state.rescue[1]!.draft!.preparedAt, clock, reason: '초안은 새 UTXO로 다시 계산');

      clock = clock.add(const Duration(minutes: 2));
      await syncCompleted();
      expect(feeCalls, 2);
      final afterFailure = store.state.rescue[1]!.draft!;
      expect(afterFailure.feeRate, first.feeRate, reason: '실패 → 마지막 수수료');
      expect(afterFailure.preparedAt, clock);
      expect(p.statusOf(1), RescueStatus.ready);

      await syncCompleted(); // 실패한 요청도 스로틀에 들어간다(리뷰 I-4)
      expect(feeCalls, 2);
      clock = clock.add(const Duration(minutes: 5));
      await syncCompleted();
      expect(feeCalls, 3);
      expect(store.state.rescue[1]!.draft!.feeRate, greaterThan(first.feeRate));
    });

    test('수수료 요청이 계속 실패해도 5분에 한 번만 다시 요청한다(리뷰 I-4)', () async {
      setRescue(1, toVault());
      fees = [];
      build();
      await syncCompleted();
      wallets.walletItemListNotifier.value = [...wallets.walletItemList];
      await pumpEventQueue();
      await syncCompleted();
      expect(feeCalls, 1);
      clock = clock.add(const Duration(minutes: 5));
      await syncCompleted();
      expect(feeCalls, 2);
    });

    test('비정상 수수료(1,000 sat/vB 초과·직전의 10배 초과)는 버리고 마지막 정상 값으로(Grok §4)', () async {
      setRescue(1, toVault());
      fees = [10, 5000, 150];
      build();
      await syncCompleted();
      final first = store.state.rescue[1]!.draft!.feeRate;
      for (var i = 0; i < 2; i++) {
        clock = clock.add(const Duration(minutes: 6));
        await syncCompleted();
        expect(store.state.rescue[1]!.draft!.feeRate, first, reason: '시도 ${i + 2}');
      }
      expect(feeCalls, 3);
    });

    test('수수료 API가 없거나 비정상이고 마지막 정상 값도 없으면 노드 추정으로(Grok §4)', () async {
      setRescue(1, toVault());
      fees = [5000];
      node.nodeFee = 7;
      build();
      await syncCompleted();
      final expected = SweepBuilder.plan(wallet: source, utxos: wallets.utxos[1]!, conflicts: const [], fastFeeRate: 7);
      expect(store.state.rescue[1]!.draft!.feeRate, expected.feeRate);
    });

    test('수수료가 옮기는 금액의 20%를 넘는 초안은 막힘(지금 이동도 안 보임)(Grok §4)', () async {
      wallets.utxos[1] = [_utxo(source, 0, 3000)];
      setRescue(1, toVault());
      fees = [10];
      final p = build();
      await syncCompleted();
      expect(store.state.rescue[1]!.draft!.blocker, RescueReadyProvider.feeTooHighBlocker);
      expect(p.statusOf(1), RescueStatus.unavailable);
      expect(p.readyWalletCount, 0);
      expect(p.canMoveNow(1), isFalse);
    });

    test('수수료를 한 번도 못 받으면 초안 없이 실패 상태', () async {
      setRescue(1, toVault());
      fees = [];
      final p = build();
      await syncCompleted();
      expect(store.state.rescue[1]!.draft, isNull);
      expect(p.statusOf(1), RescueStatus.failed);
      expect(p.readyWalletCount, 0);
    });

    test('초안 요약 = 목적지 받기 주소로 잔액 전체(SweepBuilder.plan, 충돌 없음)', () async {
      setRescue(1, toVault());
      final p = build();
      await syncCompleted();

      final expected = SweepBuilder.plan(
        wallet: source,
        utxos: wallets.utxos[1]!,
        conflicts: const [],
        fastFeeRate: 10,
      );
      final draft = store.state.rescue[1]!.draft!;
      expect(draft.destinationAddress, vault.walletBase.getAddress(vault.receiveUsedIndex + 1));
      expect(draft.amount, 150000 - expected.fee);
      expect(draft.fee, expected.fee);
      expect(draft.feeRate, expected.feeRate);
      expect(draft.inputCount, 2);
      expect(draft.preparedAt, clock);
      expect(draft.blocker, isNull);
      expect(p.drafts, {1: draft});
      expect(p.readyWalletCount, 1);
      expect(p.statusOf(1), RescueStatus.ready);
      expect(p.destinationLabel(1), 'w2');
    });

    test('잔액이 없으면 막힌 초안(잔액 없음), 준비된 지갑 수에 안 들어간다', () async {
      setRescue(6, toVault());
      final p = build();
      await syncCompleted();
      expect(store.state.rescue[6]!.draft!.blocker, SweepBlocker.noInputs.name);
      expect(p.statusOf(6), RescueStatus.noBalance);
      expect(p.readyWalletCount, 0);
    });

    test('초안은 서명·전송·앱 생성 txid 기록을 하지 않는다(던지는 가짜로 확인)', () async {
      setRescue(1, toVault());
      build();
      await syncCompleted();
      clock = clock.add(const Duration(minutes: 10));
      await syncCompleted();

      expect(node.broadcasts, 0);
      expect(store.state.appTxidPrefixes, isEmpty);
      expect(store.state.lastBroadcast, isNull);
      expect(store.state.rescue[1]!.draft, isNotNull);
    });

    test('계산하는 동안 바꾼 목적지는 덮어쓰지 않는다', () async {
      setRescue(1, toVault());
      build();
      feeGate = Completer<void>();
      await syncCompleted(); // 수수료를 기다리는 중
      setRescue(1, RescueDestination(address: _external, setAt: DateTime(2026, 10, 21)));
      feeGate!.complete();
      await pumpEventQueue();
      expect(store.state.rescue[1]!.destination.address, _external);
      expect(store.state.rescue[1]!.draft, isNull);
    });
  });

  group('목적지', () {
    test('후보: 이 지갑·같은 니모닉·사용 주의·위급 사건 지갑 제외, 보기 전용 → 볼트 새 지갑 → 주소 → 새 핫월렛(Assist 순서)', () {
      store.state = store.state.copyWith(
        incidents: [SafetyIncident(walletId: 6, txid: _attackTxid, detectedAt: DateTime(2026, 10, 20))],
      );
      final options = build().destinationOptions(1);

      expect(options.map((o) => o.wallet?.id), [2, 4, null, null, null]);
      expect(options.map((o) => o.kind), [
        AssistDestinationKind.watchOnlyWallet,
        AssistDestinationKind.watchOnlyWallet,
        AssistDestinationKind.vaultNewWallet, // 안내 → 지갑 추가 스캔 뒤 그 지갑을 목적지로(UI_SPEC §10.8)
        AssistDestinationKind.manualAddress,
        AssistDestinationKind.newHotWallet, // 맨 아래, 미리 고르지 않음
      ]);
      expect(options[2].canPreselect, isFalse, reason: '볼트 새 지갑은 미리 고르지 않는다');
      expect(options.last.canPreselect, isFalse);
      final mfpLess = options[1];
      expect(mfpLess.cannotVerifySeed, isTrue);
      expect(mfpLess.canPreselect, isFalse, reason: 'MFP 없는 지갑은 미리 고르지 않는다');
      expect(options[0].canPreselect, isTrue);
    });

    test('MFP 없이 같은 xpub으로 가져온 보기 전용 지갑은 같은 키라서 제외(같은 주소로 되돌려 보내지 않게)', () async {
      final sameKey = _withoutMfp(7, 1); // 지갑 1과 같은 xpub
      wallets.walletItemListNotifier.value = [...wallets.walletItemList, sameKey];
      final p = build();
      expect(p.destinationOptions(1).map((o) => o.wallet?.id), isNot(contains(7)));
      await expectLater(p.setDestination(1, RescueDestination(walletId: 7, setAt: clock)), throwsArgumentError);
    });

    test('검증 불일치 지갑(보기 전용 주소 불일치·BSMS 불일치)은 빠지고, 정해 둔 목적지면 다시 정해야 한다', () async {
      final multisig = _multisig(8, [8, 9, 10]);
      wallets.walletItemListNotifier.value = [...wallets.walletItemList, multisig];
      setRescue(1, toVault());
      store.state = store.state.copyWith(
        watchOnlyVerifications: {2: _verification(vault, VerificationResult.mismatch)},
        bsms: {
          8: BsmsVerification(
            matched: false,
            configHash: WalletVerification.descriptorHash(multisig.descriptor),
            at: DateTime(2026, 10, 20),
          ),
        },
      );
      final p = build();

      final ids = p.destinationOptions(1).map((o) => o.wallet?.id);
      expect(ids, isNot(contains(2)));
      expect(ids, isNot(contains(8)));
      expect(p.statusOf(1), RescueStatus.invalidDestination);
      expect(p.canMoveNow(1), isFalse);
      await syncCompleted();
      expect(store.state.rescue[1]!.draft, isNull, reason: '불일치 지갑으로 가는 초안은 만들지 않는다');
      await expectLater(p.setDestination(1, RescueDestination(walletId: 8, setAt: clock)), throwsArgumentError);
    });

    test('디스크립터가 바뀐(오래된) 불일치 기록은 미검증으로 보고 고를 수 있다', () {
      store.state = store.state.copyWith(
        watchOnlyVerifications: {2: _verification(vault, VerificationResult.mismatch, descriptorHash: 'stale')},
      );
      expect(build().destinationOptions(1).map((o) => o.wallet?.id), contains(2));
    });

    test('다른 시드 핫월렛은 후보지만 미리 고르지 않는다(이 기기 키)', () {
      final options = build().destinationOptions(1);
      expect(options.where((o) => o.wallet?.id == 6).single.canPreselect, isFalse);
    });

    test('정하기는 Premium 활성일 때만, 제외 지갑·잘못된 주소는 거절', () async {
      final p = build();
      await expectLater(p.setDestination(1, RescueDestination(walletId: 3, setAt: clock)), throwsArgumentError);
      await expectLater(p.setDestination(1, RescueDestination(walletId: 5, setAt: clock)), throwsArgumentError);
      await expectLater(p.setDestination(1, RescueDestination(walletId: 1, setAt: clock)), throwsArgumentError);
      // 다른 네트워크 주소
      await expectLater(
        p.setDestination(1, RescueDestination(address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq', setAt: clock)),
        throwsArgumentError,
      );
      // 이 지갑 주소
      final own = source.walletBase.getAddress(3);
      wallets.owners[own] = {1};
      expect(p.checkAddress(1, own).ownedByExcluded, isTrue);
      await expectLater(p.setDestination(1, RescueDestination(address: own, setAt: clock)), throwsArgumentError);
      expect(store.state.rescue, isEmpty);

      await p.setDestination(1, RescueDestination(address: '  ${_external.toUpperCase()}  ', setAt: clock));
      expect(store.state.rescue[1]!.destination.address, _external, reason: '정규화(bech32 소문자)해서 저장');
      expect(p.statusOf(1), RescueStatus.pending);

      premium.emit(const PremiumState(PremiumStatus.expired));
      await expectLater(p.setDestination(1, toVault()), throwsStateError);
      expect(store.state.rescue[1]!.destination.address, _external);
    });

    for (final cautionFirst in [false, true]) {
      test('같은 주소를 가진 지갑 중 하나라도 제외 대상이면 거절(첫 주인만 보지 않음, caution ${cautionFirst ? '먼저' : '뒤'})(리뷰 I-2)', () async {
        final copy = _single(9, 9); // 보기 전용 사본 B
        final hot = _single(10, 9, hot: true); // 같은 디스크립터의 핫월렛 C(사용 주의)
        wallets.walletItemListNotifier.value = [
          ...wallets.walletItemList,
          if (cautionFirst) hot,
          copy,
          if (!cautionFirst) hot,
        ];
        final shared = copy.walletBase.getAddress(0); // B의 받기 주소 = C의 주소
        wallets.owners[shared] = {9, 10};
        store.state = store.state.copyWith(cautionWalletIds: {5, 10});
        final p = build();

        expect(p.checkAddress(1, shared).ownedByExcluded, isTrue);
        await expectLater(p.setDestination(1, RescueDestination(address: shared, setAt: clock)), throwsArgumentError);
        await expectLater(p.setDestination(1, RescueDestination(walletId: 9, setAt: clock)), throwsArgumentError);
        expect(p.destinationOptions(1).map((o) => o.wallet?.id), isNot(contains(9)), reason: '시트에도 보이지 않는다');
        expect(store.state.rescue, isEmpty);
      });
    }

    test('직접 입력 목적지의 주인 지갑이 나중에 제외되면 준비됨이 아니다(리뷰 I-3)', () async {
      final address = vault.walletBase.getAddress(4);
      wallets.owners[address] = {2};
      setRescue(1, RescueDestination(address: address, setAt: clock));
      final p = build();
      await syncCompleted();
      expect(p.statusOf(1), RescueStatus.ready);
      expect(p.canMoveNow(1), isTrue);

      store.state = store.state.copyWith(cautionWalletIds: {2, 5});
      expect(p.statusOf(1), RescueStatus.invalidDestination);
      expect(p.drafts, isEmpty);
      expect(p.readyWalletCount, 0);
      expect(p.canMoveNow(1), isFalse);
    });

    test('구독이 끝나도 정해 둔 목적지는 지울 수 있다. 새로 정하기만 Premium(G-R6)', () async {
      setRescue(1, toVault());
      premium.emit(const PremiumState(PremiumStatus.expired));
      final p = build();
      await expectLater(p.setDestination(1, RescueDestination(address: _external, setAt: clock)), throwsStateError);
      expect(store.state.rescue[1]!.destination.walletId, 2);
      await p.setDestination(1, null);
      expect(store.state.rescue, isEmpty);
      expect(p.statusOf(1), RescueStatus.notSet);
    });

    test('테스트넷에서는 regtest(bcrt1) 주소를 목적지로 받지 않는다(리뷰 I-8)', () async {
      NetworkType.setNetworkType(NetworkType.testnet);
      addTearDown(() => NetworkType.setNetworkType(NetworkType.regtest));
      final p = build();
      expect(p.checkAddress(1, _external).format, isNotNull);
      await expectLater(p.setDestination(1, RescueDestination(address: _external, setAt: clock)), throwsArgumentError);
    });

    test('만들어 둔 주소 목록 밖의 이 지갑 주소도 앞 주소를 도출해 거절한다(Grok §5)', () async {
      final p = build();
      final beyondGap = source.walletBase.getAddress(50); // DB에는 없는 주소
      expect(p.checkAddress(1, beyondGap).ownedByExcluded, isFalse, reason: '입력할 때의 가벼운 검사는 DB만 본다');
      expect(await p.derivesFromExcludedWallet(1, beyondGap), isTrue);
      await expectLater(p.setDestination(1, RescueDestination(address: beyondGap, setAt: clock)), throwsArgumentError);
      final changeOfSameSeed = sameSeed.walletBase.getAddress(7, isChange: true);
      await expectLater(
        p.setDestination(1, RescueDestination(address: changeOfSameSeed, setAt: clock)),
        throwsArgumentError,
      );
      expect(store.state.rescue, isEmpty);
      expect(await p.derivesFromExcludedWallet(1, vault.walletBase.getAddress(3)), isFalse);
    });

    test('끄기는 목적지와 초안을 지운다', () async {
      setRescue(1, toVault());
      final p = build();
      await syncCompleted();
      await p.setDestination(1, null);
      expect(store.state.rescue, isEmpty);
      expect(p.statusOf(1), RescueStatus.notSet);
    });

    test('지갑을 지우면 그 지갑을 가리키는 목적지도 지운다(withoutWallet)', () async {
      setRescue(1, toVault());
      setRescue(6, toVault());
      final p = build();
      wallets.events.add(const WalletRemoved(2));
      await pumpEventQueue();
      expect(store.state.rescue, isEmpty);
      expect(p.destinationOf(1), isNull);
    });

    test('목적지 지갑이 나중에 사용 주의가 되면 다시 정해야 하고 초안을 만들지 않는다', () async {
      setRescue(1, toVault());
      store.state = store.state.copyWith(cautionWalletIds: {2, 5});
      final p = build();
      await syncCompleted();
      expect(p.statusOf(1), RescueStatus.invalidDestination);
      expect(store.state.rescue[1]!.draft, isNull);
      expect(p.drafts, isEmpty);
      expect(p.canMoveNow(1), isFalse);
    });
  });

  group('지금 이동', () {
    test('구독이 끝나도 준비된 초안으로 지금 이동할 수 있다(자동 재계산만 멈춤)', () async {
      setRescue(1, toVault());
      store.state = store.state.copyWith(
        incidents: [SafetyIncident(walletId: 1, txid: _attackTxid, detectedAt: clock)],
      );
      final p = build(interval: Duration.zero);
      await syncCompleted();
      premium.emit(const PremiumState(PremiumStatus.expired));
      await pumpEventQueue();
      final calls = feeCalls;

      expect(p.statusOf(1), RescueStatus.paused);
      expect(p.canMoveNow(1), isTrue);
      expect(p.hasCriticalIncident(1), isTrue);
      await syncCompleted();
      expect(feeCalls, calls, reason: '만료 뒤 자동 재계산 없음');
      expect(p.drafts[1], isNotNull, reason: '마지막 초안은 그대로');
    });

    test('확인 중(verifying)·결제 대기는 멈춤으로 보이지 않는다', () async {
      setRescue(1, toVault());
      final p = build();
      await syncCompleted();
      premium.emit(const PremiumState(PremiumStatus.verifying));
      expect(p.statusOf(1), RescueStatus.ready);
      premium.emit(const PremiumState(PremiumStatus.pending));
      expect(p.statusOf(1), RescueStatus.ready);
    });

    test('막힌 초안·사건 없는 지갑은 지금 이동 대상이 아니다', () async {
      setRescue(6, toVault());
      final p = build();
      await syncCompleted();
      expect(p.canMoveNow(6), isFalse, reason: '잔액 없음');
      expect(p.hasCriticalIncident(6), isFalse);
    });
  });
}
