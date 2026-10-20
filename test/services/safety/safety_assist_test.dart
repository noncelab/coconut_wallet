import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/hot_wallet_create_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/safety/safety_assist.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _attackTxid = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
const _destination = 'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx';

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
              backupVerified: false,
              enterPassphraseWhenSigning: false,
              createdAt: DateTime(2026, 10, 20, 12),
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

class _Wallets extends Fake implements WalletProvider {
  _Wallets(this.wallets);
  final List<WalletItemBase> wallets;
  final Set<String> incidentAddresses = {};

  /// 지갑별로 가진 주소(사고 지갑은 [incidentAddresses])
  final Map<int, Set<String>> owned = {};
  final Map<String, TransactionRecord> records = {};

  @override
  WalletItemBase getWalletById(int id) => wallets.firstWhere((w) => w.id == id);

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) =>
      (walletId == wallets.first.id && incidentAddresses.contains(address)) ||
      (owned[walletId]?.contains(address) ?? false);

  @override
  List<WalletItemBase> get walletItemList => wallets;

  @override
  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) => records[transactionHash];

  @override
  WalletAddress getReceiveAddress(int walletId) => throw StateError('not generated');
}

class _TxRepo extends Fake implements TransactionRepository {
  final Map<String, TransactionRecord> records = {};

  @override
  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) => records[transactionHash];
}

/// 서명·전송을 부르면 테스트가 실패한다
class _ThrowingNode extends Fake implements NodeProvider {
  @override
  Future<Result<String>> broadcast(Transaction signedTx) => throw StateError('Safety Assist must never broadcast');
}

class _Analytics extends AnalyticsService {
  _Analytics() : super(null, true);
  final List<String> events = [];

  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async => events.add(eventName);
}

class _Auth extends Fake implements AuthProvider {
  _Auth(this.passcodeSet);
  final bool passcodeSet;

  @override
  Future<bool> isDevicePasscodeSet() async => passcodeSet;
}

class _Creator extends Fake implements HotWalletCreateViewModel {
  final List<Map<String, Object>> calls = [];
  HotWalletCreateResult? result;

  @override
  Future<HotWalletCreateResult> createWallet({
    required String walletName,
    required int colorIndex,
    required int iconIndex,
    required int mnemonicWordCount,
    required String passphrase,
    required bool enterPassphraseWhenSigning,
  }) async {
    calls.add({
      'name': walletName,
      'words': mnemonicWordCount,
      'passphrase': passphrase,
      'enterPassphraseWhenSigning': enterPassphraseWhenSigning,
    });
    return result = HotWalletCreateResult(
      walletId: 42,
      walletName: walletName,
      descriptor: 'd',
      mnemonic: Uint8List.fromList(List.filled(12, 7)),
      passphrase: Uint8List(0),
      enterPassphraseWhenSigning: false,
    );
  }
}

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  group('destinations', () {
    test('순서: 보기 전용 → 볼트 새 지갑 → 다른 시드 기존 지갑 → 주소 → 이 기기 새 핫월렛, 사고·같은 MFP·사용 주의 제외', () {
      final incident = _single(1, 1);
      final sameSeedOtherAccount = _single(2, 1, accountIndex: 1); // 같은 MFP
      final sameSeedMultisig = _multisig(3, [1, 4, 5]); // 서명자 하나가 같은 MFP
      final watchOnly = _single(4, 6);
      final noMfp = _withoutMfp(5, 7);
      final otherHot = _single(6, 8, hot: true);
      final caution = _single(7, 9);
      final multisig = _multisig(8, [10, 11, 12]);

      final list = SafetyAssist.destinations(
        incidentWallet: incident,
        wallets: [incident, sameSeedOtherAccount, sameSeedMultisig, noMfp, watchOnly, otherHot, caution, multisig],
        cautionWalletIds: {7},
      );

      expect(list.map((d) => (d.kind, d.wallet?.id)).toList(), [
        (AssistDestinationKind.watchOnlyWallet, 4),
        (AssistDestinationKind.watchOnlyWallet, 8),
        (AssistDestinationKind.watchOnlyWallet, 5), // MFP 없는 지갑은 섹션 뒤
        (AssistDestinationKind.vaultNewWallet, null),
        (AssistDestinationKind.manualAddress, null),
        // 이 기기에 키가 있는 목적지는 다른 모든 선택지 뒤
        (AssistDestinationKind.otherWallet, 6),
        (AssistDestinationKind.newHotWallet, null),
      ]);
      final byId = {for (final d in list) d.wallet?.id: d};
      expect(byId[5]!.cannotVerifySeed, isTrue);
      expect(byId[5]!.canPreselect, isFalse);
      expect(byId[4]!.canPreselect, isTrue);
      expect(byId[6]!.onThisDevice, isTrue);
      expect(byId[6]!.canPreselect, isFalse);
      expect(list.last.onThisDevice, isTrue);
      expect(list.last.canPreselect, isFalse);
    });

    test('비상 목적지는 맨 위(지갑이든 주소든), 제외 대상이면 표시 안 함', () {
      final incident = _single(1, 1);
      final watchOnly = _single(4, 6);
      final otherHot = _single(6, 8, hot: true);
      final at = DateTime(2026, 10, 1);

      var list = SafetyAssist.destinations(
        incidentWallet: incident,
        wallets: [incident, watchOnly, otherHot],
        rescueDestination: RescueDestination(walletId: 4, setAt: at),
      );
      expect(list.first.wallet?.id, 4);
      expect(list.first.isRescueDestination, isTrue);
      expect(list.where((d) => d.wallet?.id == 4).length, 1);

      // 이 기기 핫월렛이 비상 목적지여도 맨 위로 올리지 않고(새 핫월렛 바로 앞) 미리 고르지 않는다
      list = SafetyAssist.destinations(
        incidentWallet: incident,
        wallets: [incident, watchOnly, otherHot],
        rescueDestination: RescueDestination(walletId: 6, setAt: at),
      );
      final device = list.indexWhere((d) => d.wallet?.id == 6);
      expect(list[device].isRescueDestination, isTrue);
      expect(list[device].canPreselect, isFalse);
      expect(device, list.length - 2);
      expect(list.indexWhere((d) => d.kind == AssistDestinationKind.manualAddress), lessThan(device));

      list = SafetyAssist.destinations(
        incidentWallet: incident,
        wallets: [incident, watchOnly],
        rescueDestination: RescueDestination(address: _destination, setAt: at),
      );
      expect(
        (list.first.kind, list.first.address, list.first.isRescueDestination),
        (AssistDestinationKind.manualAddress, _destination, true),
      );

      list = SafetyAssist.destinations(
        incidentWallet: incident,
        wallets: [incident, watchOnly],
        cautionWalletIds: {4},
        rescueDestination: RescueDestination(walletId: 4, setAt: at),
      );
      expect(list.any((d) => d.isRescueDestination || d.wallet != null), isFalse);
    });

    test('MFP 없이 같은 확장 공개키로 추가한 지갑은 목적지에서 빠짐', () {
      final incident = _single(1, 1, hot: true);
      final sameXpubNoMfp = _withoutMfp(2, 1); // 사고 지갑과 같은 계정 키, 지문만 00000000
      final other = _single(3, 6);
      final list = SafetyAssist.destinations(incidentWallet: incident, wallets: [incident, sameXpubNoMfp, other]);
      expect(list.map((d) => d.wallet?.id).whereType<int>().toList(), [3]);
      // 반대로 사고 지갑이 MFP 없이 추가된 보기 전용이어도 같은 키의 핫월렛은 빠짐
      final reversed = SafetyAssist.destinations(
        incidentWallet: sameXpubNoMfp,
        wallets: [sameXpubNoMfp, incident, other],
      );
      expect(reversed.map((d) => d.wallet?.id).whereType<int>().toList(), [3]);
    });

    group('검증 불일치(바꿔치기 위험) 지갑은 목적지에서 빠짐, 미검증은 남음', () {
      // 그룹 본문은 선언 때 돌아서 regtest 설정 뒤(setUpAll)에 만든다
      late SinglesigWalletItem incident, watchOnly;
      late MultisigWalletItem multisig;
      setUpAll(() {
        incident = _single(1, 1, hot: true);
        watchOnly = _single(4, 6);
        multisig = _multisig(8, [10, 11, 12]);
      });
      final at = DateTime(2026, 10, 20);
      String hash(WalletItemBase w) => WalletVerification.descriptorHash(w.descriptor);
      Set<int?> ids(SafetyState state) => {
        for (final d in SafetyAssist.destinations(
          incidentWallet: incident,
          wallets: [incident, watchOnly, multisig],
          safetyState: state,
        ))
          if (d.wallet != null) d.wallet!.id,
      };
      WatchOnlyVerification watch(VerificationResult result, {String? descriptorHash}) => WatchOnlyVerification(
        method: VerificationMethod.qr,
        result: result,
        descriptorHash: descriptorHash ?? hash(watchOnly),
        at: at,
      );

      test('미검증·일치는 고를 수 있음', () {
        expect(ids(SafetyState.initial()), {4, 8});
        expect(
          ids(
            SafetyState.initial().copyWith(
              watchOnlyVerifications: {4: watch(VerificationResult.match)},
              bsms: {8: BsmsVerification(matched: true, configHash: hash(multisig), at: at)},
            ),
          ),
          {4, 8},
        );
      });

      test('보기 전용 mismatch·confirmedMismatch → 빠짐(지금 디스크립터 기준)', () {
        for (final result in [VerificationResult.mismatch, VerificationResult.confirmedMismatch]) {
          expect(ids(SafetyState.initial().copyWith(watchOnlyVerifications: {4: watch(result)})), {8});
        }
        // 디스크립터가 바뀐 예전 기록은 미검증과 같다
        expect(
          ids(
            SafetyState.initial().copyWith(
              watchOnlyVerifications: {4: watch(VerificationResult.mismatch, descriptorHash: 'old')},
            ),
          ),
          {4, 8},
        );
      });

      test('다중서명 BSMS 불일치 → 빠짐(예전 구성 해시면 남음)', () {
        expect(
          ids(
            SafetyState.initial().copyWith(
              bsms: {8: BsmsVerification(matched: false, configHash: hash(multisig), at: at)},
            ),
          ),
          {4},
        );
        expect(
          ids(SafetyState.initial().copyWith(bsms: {8: BsmsVerification(matched: false, configHash: 'old', at: at)})),
          {4, 8},
        );
      });

      test('사용 주의·위급 사건 지갑도 같은 규칙으로 빠짐', () {
        expect(ids(SafetyState.initial().copyWith(cautionWalletIds: {4})), {8});
        expect(
          ids(
            SafetyState.initial().copyWith(incidents: [SafetyIncident(walletId: 8, txid: _attackTxid, detectedAt: at)]),
          ),
          {4},
        );
      });
    });

    test('사고 지갑에 MFP가 없으면 어떤 지갑도 같은 시드인지 확인할 수 없음', () {
      final incident = _withoutMfp(1, 1);
      final list = SafetyAssist.destinations(incidentWallet: incident, wallets: [incident, _single(4, 6)]);
      expect(list.where((d) => d.wallet != null).every((d) => d.cannotVerifySeed && !d.canPreselect), isTrue);
    });
  });

  group('openConfirm', () {
    late SinglesigWalletItem wallet;
    late _Wallets wallets;
    late _TxRepo repo;
    late TransactionProvider txProvider;
    late SendInfoProvider sendInfo;
    late List<RouteSettings> pushed;
    SafetyProvider? safety;

    setUp(() {
      safety = null;
      wallet = _single(1, 1);
      wallets = _Wallets([wallet]);
      repo = _TxRepo();
      txProvider = TransactionProvider(repo);
      sendInfo = SendInfoProvider();
      pushed = [];
    });

    Future<BuildContext> pumpHost(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            InheritedProvider<WalletProvider>.value(value: wallets),
            InheritedProvider<NodeProvider>.value(value: _ThrowingNode()),
            ChangeNotifierProvider<TransactionProvider>.value(value: txProvider),
            Provider<SendInfoProvider>.value(value: sendInfo),
            if (safety != null) ChangeNotifierProvider<SafetyProvider>.value(value: safety!),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox();
              },
            ),
            onGenerateRoute: (settings) {
              pushed.add(settings);
              return MaterialPageRoute(builder: (_) => const Text('send confirm'), settings: settings);
            },
          ),
        ),
      );
      return captured;
    }

    SweepPlan replacementPlan() {
      final stolen = UtxoState(
        transactionHash: '1'.padLeft(64, '0'),
        index: 0,
        amount: 90000,
        derivationPath: "${wallet.walletBase.derivationPath}/0/0",
        blockHeight: 0,
        to: '',
        timestamp: DateTime(2026),
        status: UtxoStatus.outgoing,
        spentByTransactionHash: _attackTxid,
      );
      final locked = UtxoState(
        transactionHash: '2'.padLeft(64, '0'),
        index: 1,
        amount: 20000,
        derivationPath: "${wallet.walletBase.derivationPath}/0/1",
        blockHeight: 90,
        to: '',
        timestamp: DateTime(2026),
        status: UtxoStatus.locked,
      );
      return SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen, locked],
        conflicts: const [SweepConflict(txid: _attackTxid, fee: 1410, vSize: 141, signalsRbf: true)],
        fastFeeRate: 4,
      );
    }

    testWidgets('수수료 올리기와 같게 채우고 기존 보내기 확인으로만 간다(서명·전송 없음)', (tester) async {
      repo.records[_attackTxid] = TransactionRecord(
        _attackTxid,
        DateTime(2026),
        0,
        TransactionType.sent,
        null,
        -90000,
        1410,
        const [],
        const [],
        141,
        DateTime(2026),
      );
      final context = await pumpHost(tester);
      final plan = replacementPlan();

      SafetyAssist.openConfirm(
        context,
        wallet: wallet,
        plan: plan,
        destination: _destination,
        entryPoint: SendEntryPoint.transactionDetail,
      );
      await tester.pumpAndSettle();

      expect(pushed.last.name, AppRouteNames.sendConfirm);
      expect(pushed.last.arguments, isA<SendConfirmRouteArgs>());
      expect(find.text('send confirm'), findsOneWidget);

      expect(sendInfo.walletId, 1);
      expect(sendInfo.sendEntryPoint, SendEntryPoint.transactionDetail);
      expect(sendInfo.isMultisig, isFalse);
      expect(sendInfo.feeBumpingType, FeeBumpingType.rbf);
      expect(sendInfo.walletImportSource, wallet.walletImportSource);
      expect(sendInfo.feeRate, plan.feeRate);
      expect(sendInfo.isMaxMode, isTrue);
      expect(txProvider.transaction?.transactionHash, _attackTxid);

      final tx = sendInfo.transaction!;
      expect(tx.outputs.single.getAddress(), _destination);
      expect(tx.inputs.length, 2);
      expect(tx.inputs.every((i) => i.sequence == SweepBuilder.rbfSequence), isTrue);
      expect(tx.totalInputAmount - tx.outputs.single.amount, plan.fee);
      // 서명 대기·서명 결과는 비어 있다(서명은 보내기 확인 화면에서 사용자가)
      expect(sendInfo.txWaitingForSign, isNull);
      expect(sendInfo.signedResult, isNull);
    });

    testWidgets('충돌 거래 기록이 없으면 feeBumpingType 없음, 남은 코인 이동은 home', (tester) async {
      final context = await pumpHost(tester);
      SafetyAssist.openConfirm(context, wallet: wallet, plan: replacementPlan(), destination: _destination);
      await tester.pumpAndSettle();
      expect(sendInfo.feeBumpingType, isNull);
      expect(sendInfo.sendEntryPoint, SendEntryPoint.home);
      expect(txProvider.transaction, isNull);
    });

    testWidgets('AH1: 고른 지갑이 넘기기 직전에 제외 대상이 되면 거절하고 아무것도 채우지 않음', (tester) async {
      final other = _single(4, 6);
      wallets.wallets.add(other);
      safety = SafetyProvider.fixed(null, state: SafetyState.initial().copyWith(cautionWalletIds: {4}));
      final context = await pumpHost(tester);
      await expectLater(
        SafetyAssist.openConfirm(
          context,
          wallet: wallet,
          plan: replacementPlan(),
          destination: other.walletBase.getAddress(0),
          destinationWalletId: 4,
        ),
        throwsA(
          isA<AssistDestinationRejected>().having((e) => e.problem, 'problem', DestinationProblem.excludedWallet),
        ),
      );
      await tester.pumpAndSettle();
      expect(pushed.where((s) => s.name == AppRouteNames.sendConfirm), isEmpty);
      expect(sendInfo.transaction, isNull);
    });

    testWidgets('AH3: 받은 핫월렛을 txid로 기억해 동기화 전에도 백업 대상으로 찾음', (tester) async {
      final hot = _single(9, 8, hot: true);
      wallets.wallets.add(hot);
      final context = await pumpHost(tester);
      SafetyAssist.openConfirm(
        context,
        wallet: wallet,
        plan: replacementPlan(),
        destination: hot.walletBase.getAddress(0),
        destinationWalletId: 9,
      );
      await tester.pumpAndSettle();
      final txid = sendInfo.transaction!.transactionHash;
      expect(SafetyAssist.unbackedHotWalletFor(wallets, walletId: 1, txid: txid)?.id, 9);
    });

    testWidgets('목적지가 사고 지갑 주소거나 계획이 막혔으면 아무것도 채우지 않고 멈춤', (tester) async {
      final context = await pumpHost(tester);
      final plan = replacementPlan();
      wallets.incidentAddresses.add(_destination);
      await expectLater(
        SafetyAssist.openConfirm(context, wallet: wallet, plan: plan, destination: _destination),
        throwsA(isA<AssistDestinationRejected>().having((e) => e.problem, 'problem', DestinationProblem.excludedOwner)),
      );
      wallets.incidentAddresses.clear();
      final blocked = SweepBuilder.plan(wallet: wallet, utxos: const [], conflicts: const [], fastFeeRate: 2);
      await expectLater(
        SafetyAssist.openConfirm(context, wallet: wallet, plan: blocked, destination: _destination),
        throwsStateError,
      );
      await tester.pumpAndSettle();
      expect(pushed.where((s) => s.name == AppRouteNames.sendConfirm), isEmpty);
      expect(sendInfo.transaction, isNull);
    });

    testWidgets('lead: 수수료가 20%를 넘는 계획은 넘기지 않고, 확인한 대체 하한만 예외로 넘김', (tester) async {
      final context = await pumpHost(tester);
      final stolen = UtxoState(
        transactionHash: '1'.padLeft(64, '0'),
        index: 0,
        amount: 100000,
        derivationPath: "${wallet.walletBase.derivationPath}/0/0",
        blockHeight: 0,
        to: '',
        timestamp: DateTime(2026),
        status: UtxoStatus.outgoing,
        spentByTransactionHash: _attackTxid,
      );
      SweepPlan plan({required bool verified}) => SweepBuilder.plan(
        wallet: wallet,
        utxos: [stolen],
        conflicts: [SweepConflict(txid: _attackTxid, fee: 22000, vSize: 110, signalsRbf: true, feeVerified: verified)],
        fastFeeRate: 4,
      );
      expect(SweepFee.isExcessive(plan(verified: false)), isTrue);
      await expectLater(
        SafetyAssist.openConfirm(context, wallet: wallet, plan: plan(verified: false), destination: _destination),
        throwsStateError,
      );
      expect(sendInfo.transaction, isNull);

      SafetyAssist.openConfirm(context, wallet: wallet, plan: plan(verified: true), destination: _destination);
      await tester.pumpAndSettle();
      expect(pushed.last.name, AppRouteNames.sendConfirm);
    });
  });

  group('새 핫월렛', () {
    Future<BuildContext> pumpHost(
      WidgetTester tester, {
      required bool passcodeSet,
      required _Analytics analytics,
    }) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            InheritedProvider<WalletProvider>.value(value: _Wallets([_single(1, 1)])),
            InheritedProvider<AuthProvider>.value(value: _Auth(passcodeSet)),
            Provider<AnalyticsService>.value(value: analytics),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return captured;
    }

    testWidgets('12단어·패스프레이즈 없이 만들고 니모닉 바이트를 지운다', (tester) async {
      final analytics = _Analytics();
      final context = await pumpHost(tester, passcodeSet: true, analytics: analytics);
      final creator = _Creator();

      final id = await SafetyAssist.createHotWallet(context, viewModel: creator);

      expect(id, 42);
      expect(creator.calls.single['words'], 12);
      expect(creator.calls.single['passphrase'], '');
      expect(creator.calls.single['enterPassphraseWhenSigning'], false);
      expect(creator.calls.single['name'], t.safety_guide.move.new_wallet);
      expect(creator.result!.mnemonic.every((b) => b == 0), isTrue);
    });
  });

  group('AH1·AH7: checkDestination(지금 상태로 목적지 다시 확인)', () {
    late SinglesigWalletItem incident, other;
    late _Wallets wallets;
    setUp(() {
      incident = _single(1, 1);
      other = _single(4, 6);
      wallets = _Wallets([incident, other]);
    });
    DestinationProblem? check(String address, {int? walletId, SafetyState? state}) => SafetyAssist.checkDestination(
      wallets,
      incidentWallet: incident,
      address: address,
      walletId: walletId,
      safetyState: state,
    );

    test('저장해 둔 주소의 주인이 나중에 제외 대상이 되면 거절', () {
      final address = other.walletBase.getAddress(3);
      wallets.owned[4] = {address};
      expect(check(address), isNull);
      expect(
        check(address, state: SafetyState.initial().copyWith(cautionWalletIds: {4})),
        DestinationProblem.excludedOwner,
      );
      expect(
        check(
          address,
          state: SafetyState.initial().copyWith(
            incidents: [SafetyIncident(walletId: 4, txid: _attackTxid, detectedAt: DateTime(2026, 10, 20))],
          ),
        ),
        DestinationProblem.excludedOwner,
      );
    });

    test('고른 지갑이 지워졌거나 제외 대상이면 거절, 사고 지갑 주소도 거절', () {
      final address = other.walletBase.getAddress(0);
      expect(check(address, walletId: 4), isNull);
      expect(check(address, walletId: 99), DestinationProblem.excludedWallet);
      expect(
        check(address, walletId: 4, state: SafetyState.initial().copyWith(cautionWalletIds: {4})),
        DestinationProblem.excludedWallet,
      );
      wallets.incidentAddresses.add(_destination);
      expect(check(_destination), DestinationProblem.excludedOwner);
    });

    test('형식 오류와 다른 네트워크 주소(testnet에서 bcrt1)는 거절', () {
      expect(check('not-an-address'), DestinationProblem.invalidAddress);
      expect(check('bc1qxa3vg30kvqsd73knsv0dj8z26jx223cht4qwh4'), DestinationProblem.invalidAddress);
      NetworkType.setNetworkType(NetworkType.testnet);
      try {
        expect(AssistAddress.isValidForCurrentNetwork(_destination), isFalse);
      } finally {
        NetworkType.setNetworkType(NetworkType.regtest);
      }
      expect(AssistAddress.isValidForCurrentNetwork(_destination), isTrue);
    });
  });

  test('AH3: 백업 대상은 실제로 받은 지갑(만든 시각·다시 시작과 무관)', () {
    final incident = _single(1, 1);
    final first = _single(9, 8, hot: true); // 먼저 만들고 안 쓴 지갑
    final used = _single(10, 9, hot: true); // 실제로 받은 지갑
    final wallets = _Wallets([incident, first, used]);
    const txid =
        'cd'
        'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';
    final address = used.walletBase.getAddress(0);
    wallets.owned[10] = {address};
    wallets.records[txid] = TransactionRecord(
      txid,
      DateTime(2026, 10, 20),
      0,
      TransactionType.sent,
      null,
      -90000,
      1000,
      const [],
      [TransactionAddress(address, 89000)],
      141,
      DateTime(2026, 10, 20),
    );
    expect(SafetyAssist.unbackedHotWalletFor(wallets, walletId: 1, txid: txid)?.id, 10);
  });

  group('I-1·I-2: verifiedTarget(비상 목적지 마지막 확인)과 제외 지갑 사본', () {
    test('사용 주의 핫월렛 C의 보기 전용 사본 B도 목적지에서 빠지고 B 주소도 거절', () {
      final incident = _single(1, 1);
      final caution = _single(5, 7, hot: true); // C: 사용 주의
      final copy = _withoutMfp(6, 7); // B: C와 같은 계정 키(보기 전용 사본, MFP 없음)
      final other = _single(4, 6);
      final wallets = _Wallets([incident, caution, copy, other]);
      final state = SafetyState.initial().copyWith(cautionWalletIds: {5});
      final ids = {
        for (final d in SafetyAssist.destinations(
          incidentWallet: incident,
          wallets: wallets.wallets,
          safetyState: state,
        ))
          if (d.wallet != null) d.wallet!.id,
      };
      expect(ids, {4});

      final address = copy.walletBase.getAddress(2);
      wallets.owned[6] = {address}; // 주소 목록상 첫 주인은 사본 B
      wallets.owned[5] = {address};
      expect(
        SafetyAssist.verifiedTarget(
          wallets,
          source: incident,
          destination: RescueDestination(address: address, setAt: DateTime(2026, 10, 20)),
          state: state,
        ),
        isNull,
      );
      expect(
        SafetyAssist.verifiedTarget(
          wallets,
          source: incident,
          destination: RescueDestination(walletId: 6, setAt: DateTime(2026, 10, 20)),
          state: state,
        ),
        isNull,
      );
      final ok = SafetyAssist.verifiedTarget(
        wallets,
        source: incident,
        destination: RescueDestination(walletId: 4, setAt: DateTime(2026, 10, 20)),
        state: state,
      );
      expect((ok?.wallet?.id, ok?.address), (4, other.walletBase.getAddress(0)));
    });
  });

  group('Grok §5: 제외 지갑에서 도출되는 주소(만들어 둔 목록 밖 포함)', () {
    test('사고 지갑·같은 시드 지갑의 받기·잔돈 깊은 인덱스 주소를 잡고, 다른 지갑 주소는 통과', () {
      final incident = _single(1, 1);
      final sameSeed = _single(2, 1, accountIndex: 1);
      final other = _single(4, 6);
      List<(WalletType, String)> excluded() => [
        (incident.walletType, incident.descriptor),
        (sameSeed.walletType, sameSeed.descriptor),
      ];
      expect(SafetyAssist.derivesFrom(excluded(), incident.walletBase.getAddress(40), depth: 50), isTrue);
      expect(
        SafetyAssist.derivesFrom(excluded(), sameSeed.walletBase.getAddress(45, isChange: true), depth: 50),
        isTrue,
      );
      expect(SafetyAssist.derivesFrom(excluded(), other.walletBase.getAddress(3), depth: 50), isFalse);
      // 범위 밖이면 못 잡는다(기본 1,000)
      expect(SafetyAssist.derivesFrom(excluded(), incident.walletBase.getAddress(60), depth: 50), isFalse);
    });
  });

  group('Grok §4: SweepFee', () {
    test('비정상 수수료율(음수·무한·1,000 초과·마지막 정상 값의 10배 초과)은 버리고 마지막 정상 값 → 노드 추정', () {
      expect(SweepFee.isSane(5), isTrue);
      for (final bad in [null, -1.0, double.nan, double.infinity, 1500.0]) {
        expect(SweepFee.isSane(bad), isFalse, reason: '$bad');
      }
      expect(SweepFee.isSane(60, lastGood: 5), isFalse);
      expect(SweepFee.choose(fresh: 7, lastGood: 5), (rate: 7.0, source: FeeRateSource.fresh));
      expect(SweepFee.choose(fresh: 900, lastGood: 5), (rate: 5.0, source: FeeRateSource.lastGood));
      expect(SweepFee.choose(fresh: null, node: 3), (rate: 3.0, source: FeeRateSource.node));
      expect(SweepFee.choose(fresh: 5000, node: 3000), isNull);
    });

    test('수수료가 받는 금액의 20%를 넘으면 isExcessive', () {
      final wallet = _single(1, 1);
      UtxoState coin(int amount) => UtxoState(
        transactionHash: '3'.padLeft(64, '0'),
        index: 0,
        amount: amount,
        derivationPath: "${wallet.walletBase.derivationPath}/0/0",
        blockHeight: 90,
        to: '',
        timestamp: DateTime(2026),
      );
      final small = SweepBuilder.plan(wallet: wallet, utxos: [coin(2000)], conflicts: const [], fastFeeRate: 10);
      expect(small.blocker, isNull);
      expect(SweepFee.isExcessive(small), isTrue);
      final large = SweepBuilder.plan(wallet: wallet, utxos: [coin(200000)], conflicts: const [], fastFeeRate: 10);
      expect(SweepFee.isExcessive(large), isFalse);
    });
  });

  test('Safety Assist 코드는 서명·전송 API를 부르지 않는다', () {
    final sources = [
      ...Directory('lib/services/safety').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')),
      ...(Directory('lib/screens/safety/assist').existsSync()
          ? Directory('lib/screens/safety/assist').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))
          : const <File>[]),
    ].where(
      (f) =>
          f.path.contains('sweep_builder') ||
          f.path.contains('conflict_analyzer') ||
          f.path.contains('safety_assist') ||
          f.path.contains('/assist/'),
    );
    expect(sources, isNotEmpty);
    for (final file in sources) {
      final code = file.readAsStringSync();
      for (final forbidden in [
        '.broadcast(',
        'HotWalletSigningService',
        'addSignatureToPsbt',
        'signHotWallet',
        'setSignedResult',
        'setTxWaitingForSign',
      ]) {
        expect(code.contains(forbidden), isFalse, reason: '${file.path} uses $forbidden');
      }
    }
  });
}
