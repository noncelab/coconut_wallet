import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/routes/route_observer.dart';
import 'package:coconut_wallet/screens/safety/assist/assist_move_screens.dart';
import 'package:coconut_wallet/screens/safety/assist/safety_assist_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/safety/conflict_analyzer.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart' show PremiumActionCard, PremiumChip;
import 'package:coconut_wallet/screens/safety/help_channels_sheet.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show formatHomeRelativeTime;
import 'package:coconut_wallet/widgets/features/safety/safety_address_entry_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// R1(한국어 단어 안 줄바꿈 막기)의 이음 문자를 빼고 비교한다. 공용 부품이 글을 감싸는지와 무관하게 같은 글을 찾는다
String _plain(String text) => text.replaceAll('\u2060', '');
Finder _koText(String text) =>
    find.byWidgetPredicate((w) => w is RichText && _plain(w.text.toPlainText()) == _plain(text));
Finder _koTextContaining(String text) =>
    find.byWidgetPredicate((w) => w is RichText && _plain(w.text.toPlainText()).contains(_plain(text)));

const _attackTxid = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';

SinglesigWalletItem _wallet(int id, int seed) => SinglesigWalletItem(
  id: id,
  name: 'Wallet $id',
  colorIndex: 0,
  iconIndex: 0,
  descriptor: SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, seed))).descriptor,
);

/// 이 기기에 이미 있는 다른 시드 핫월렛
SinglesigWalletItem _hotWallet(int id, int seed) {
  final vault = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, seed)));
  return SinglesigWalletItem(
    id: id,
    name: 'Wallet $id',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: vault.descriptor,
    hotWalletMetadata: HotWalletMetadata(
      walletId: id,
      secureStorageKey: 'k$id',
      masterFingerprint: vault.keyStore.masterFingerprint,
      derivationPath: vault.derivationPath,
      accountIndex: 0,
      backupVerified: true,
      enterPassphraseWhenSigning: false,
      createdAt: DateTime(2026, 10, 20),
    ),
  );
}

UtxoState _utxo(WalletItemBase w, int i, int amount, {UtxoStatus status = UtxoStatus.unspent, String? spentBy}) =>
    UtxoState(
      transactionHash: (i + 1).toRadixString(16).padLeft(64, '0'),
      index: 0,
      amount: amount,
      derivationPath: '${w.walletBase.derivationPath}/0/$i',
      blockHeight: status == UtxoStatus.outgoing ? 0 : 100,
      to: '',
      timestamp: DateTime(2026),
      status: status,
      spentByTransactionHash: spentBy,
    );

class _Wallets extends Fake implements WalletProvider {
  _Wallets(this.wallets, this.utxos);
  final List<WalletItemBase> wallets;
  final List<UtxoState> utxos;

  @override
  List<WalletItemBase> get walletItemList => wallets;

  @override
  WalletItemBase getWalletById(int id) => wallets.firstWhere((w) => w.id == id);

  @override
  List<UtxoState> getUtxoList(int walletId) => walletId == 1 ? utxos : const [];

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => false;

  @override
  WalletAddress getReceiveAddress(int walletId) => throw StateError('not generated');

  final records = <String, TransactionRecord>{};

  @override
  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) =>
      walletId == 1 ? records[transactionHash] : null;

  final balances = <int, int>{};

  @override
  Balance getWalletBalance(int walletId) => Balance(balances[walletId] ?? 0, 0);

  final events = StreamController<WalletLifecycleEvent>.broadcast();

  @override
  Stream<WalletLifecycleEvent> get lifecycleEvents => events.stream;
}

class _Rescue extends Fake implements RescueReadyProvider {
  _Rescue(this.destination, {this.ready = false, this.draft});
  final RescueDestination destination;
  final bool ready;
  final RescueDraftSummary? draft;
  int moves = 0;

  @override
  Map<int, RescueDraftSummary> get drafts => {if (draft != null) 1: draft!};

  @override
  RescueDestination? destinationOf(int walletId) => walletId == 1 ? destination : null;

  @override
  bool canMoveNow(int walletId) => ready && walletId == 1;

  @override
  Future<void> moveNow(BuildContext context, int walletId) async => moves++;
}

class _Analytics extends AnalyticsService {
  _Analytics() : super(null, true);

  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {}
}

class _Analyzer extends Fake implements ConflictAnalyzer {
  _Analyzer(this.result);
  List<SweepConflict> result;
  int calls = 0;

  @override
  Future<List<SweepConflict>> analyze(int walletId, List<String> incidentTxids) async {
    calls++;
    return result;
  }
}

class _Preferences extends ChangeNotifier implements PreferenceProvider {
  _Preferences({this.hidden = true, this.fake = false});
  final bool hidden, fake;

  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  bool get isBalanceHidden => hidden;
  @override
  bool get isFakeBalanceActive => fake;
  @override
  double getFakeBalance(int walletId) => 777;
  @override
  FiatCode get selectedFiat => FiatCode.USD;
  @override
  String get language => 'ko';
  @override
  NumberFormatPreset get numberFormatPreset => NumberFormatPreset.dotDecimal;
  @override
  bool get isManualUtxoSelectionMode => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 페이월이 쓰는 값 + 새 핫월렛 게이트(기기 비밀번호 확인)를 몇 번 불렀는지
class _Auth extends ChangeNotifier implements AuthProvider {
  int passcodeChecks = 0;
  @override
  bool get isSetPin => false;
  @override
  bool get canCheckBiometrics => false;
  @override
  bool get isSetBiometrics => false;
  @override
  Future<bool> isDevicePasscodeSet() async {
    passcodeChecks++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _premiumProducts = [
  for (final period in [PremiumPeriod.yearly, PremiumPeriod.monthly])
    PremiumProduct(config: kAppStorePremiumProducts.firstWhere((c) => c.period == period), price: '₩39,000'),
];

class _TxRepo extends Fake implements TransactionRepository {
  @override
  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) => null;
}

/// 서명·전송을 부르면 테스트가 실패한다
class _ThrowingNode extends Fake implements NodeProvider {
  @override
  Future<Result<String>> broadcast(Transaction signedTx) => throw StateError('never broadcast');
}

void main() {
  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));
  tearDown(() {
    SafetyAssistFlow.analyzerOverride = null;
    SafetyAssistFlow.fastFeeRateOverride = null;
    SafetyAssistFlow.nodeFeeRateOverride = null;
    SafetyAssistFlow.resetLastGoodFeeRate();
  });

  final incident = _wallet(1, 1);
  final destination = _wallet(2, 2);

  Future<
    ({
      SendInfoProvider sendInfo,
      List<String> pushed,
      Future<AssistExit?> Function() start,
      BuildContext Function() host,
      _Wallets wallets,
      _Analyzer analyzer,
      _Auth auth,
      SafetyProvider safety,
      _Rescue? rescue,
    })
  >
  pump(
    WidgetTester tester, {
    required List<SweepConflict> conflicts,
    required List<UtxoState> utxos,
    double? fastFee = 3,
    List<WalletItemBase>? wallets,
    Map<int, ({RescueDestination destination, RescueDraftSummary? draft})> rescue = const {},
    RescueDestination? rescueReady,
    bool rescueCanMoveNow = false,
    FakeEntitlementService? premium,
    Map<int, WatchOnlyVerification> verifications = const {},
    bool withIncident = true,
    Map<int, WalletBaseline> baselines = const {},
    _Preferences? preferences,
    double textScale = 1,
    RescueDraftSummary? rescueDraft,
  }) async {
    final auth = _Auth();
    final rescueProvider =
        rescueReady == null ? null : _Rescue(rescueReady, ready: rescueCanMoveNow, draft: rescueDraft);
    final analyzer = _Analyzer(conflicts);
    SafetyAssistFlow.analyzerOverride = (_) => analyzer;
    SafetyAssistFlow.fastFeeRateOverride = () async => fastFee;
    final sendInfo = SendInfoProvider();
    final pushed = <String>[];
    final safety = SafetyProvider.fixed(
      null,
      state: SafetyState.initial().copyWith(
        incidents: [
          if (withIncident)
            SafetyIncident(
              walletId: 1,
              txid: _attackTxid,
              detectedAt: DateTime(2026, 10, 20),
              state: IncidentState.responding,
              responseMode: IncidentResponseMode.premium,
              guideStep: 2,
            ),
        ],
        rescue: rescue,
        watchOnlyVerifications: verifications,
        baselines: baselines,
      ),
    );
    final walletProvider = _Wallets(wallets ?? [incident, destination], utxos);
    late BuildContext host;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          InheritedProvider<WalletProvider>.value(value: walletProvider),
          Provider<AnalyticsService>.value(value: _Analytics()),
          if (rescueProvider != null) InheritedProvider<RescueReadyProvider>.value(value: rescueProvider),
          InheritedProvider<NodeProvider>.value(value: _ThrowingNode()),
          ChangeNotifierProvider<PreferenceProvider>.value(value: preferences ?? _Preferences()),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<TransactionProvider>.value(value: TransactionProvider(_TxRepo())),
          ChangeNotifierProvider<SafetyProvider>.value(value: safety),
          Provider<SendInfoProvider>.value(value: sendInfo),
          Provider<EntitlementService>.value(
            value: premium ?? FakeEntitlementService(initial: const PremiumState(PremiumStatus.active)),
          ),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
          navigatorObservers: [routeObserver],
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold(body: Text('guide'));
            },
          ),
          onGenerateRoute: (settings) {
            pushed.add(settings.name!);
            return MaterialPageRoute(builder: (_) => const Text('send confirm'), settings: settings);
          },
        ),
      ),
    );
    return (
      sendInfo: sendInfo,
      pushed: pushed,
      start: () => SafetyAssistFlow.start(host, '1:$_attackTxid'),
      host: () => host,
      wallets: walletProvider,
      analyzer: analyzer,
      auth: auth,
      safety: safety,
      rescue: rescueProvider,
    );
  }

  testWidgets('대체 가능: 분석 → 대체 거래 준비 → 보기 전용 목적지 → 검토(대체 안내) → 기존 보내기 확인, 서명·전송 없음', (tester) async {
    final stolen = _utxo(incident, 0, 90000, status: UtxoStatus.outgoing, spentBy: _attackTxid);
    final locked = _utxo(incident, 1, 30000, status: UtxoStatus.locked);
    final env = await pump(
      tester,
      utxos: [stolen, locked],
      conflicts: const [SweepConflict(txid: _attackTxid, fee: 1410, vSize: 141, signalsRbf: false)],
    );
    env.start();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-assist-options')), findsOneWidget);
    expect(find.text(t.premium.assist.available), findsOneWidget);
    // H7: 도움 받기 부제 + 완료 화면과 같은 사기 예방 줄
    expect(
      find.descendant(
        of: find.byKey(const Key('safety-assist-help')),
        matching: _koText((t.safety_guide.help_center.subtitle)),
      ),
      findsOneWidget,
    );
    expect(find.byType(HelpCenterNeverAsksNote), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-assist-destination')), findsOneWidget);
    // 사고 지갑은 목록에 없다
    expect(find.byKey(const Key('safety-assist-destination-wallet-1')), findsNothing);
    await tester.tap(find.byKey(const Key('safety-assist-destination-wallet-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
    expect(find.byKey(const Key('safety-assist-review-replace-warning')), findsOneWidget);
    expect(find.byKey(const Key('safety-assist-review-locked')), findsOneWidget);
    expect(find.byKey(const Key('safety-assist-review-no-rbf')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();

    expect(env.pushed.last, AppRouteNames.sendConfirm);
    final tx = env.sendInfo.transaction!;
    expect(tx.outputs.single.getAddress(), destination.walletBase.getAddress(0));
    expect(tx.inputs.length, 2);
    expect(tx.inputs.every((i) => i.sequence == SweepBuilder.rbfSequence), isTrue);
    expect(env.sendInfo.isMaxMode, isTrue);
    expect(env.sendInfo.txWaitingForSign, isNull);
    expect(env.sendInfo.signedResult, isNull);
    // 충돌 거래 기록이 로컬에 없으면 확정 확인 경로를 켜지 않는다
    expect(env.sendInfo.feeBumpingType, isNull);
    expect(env.sendInfo.feeBumpingType, isNot(FeeBumpingType.cpfp));
  });

  testWidgets('확정된 충돌 → 대체 불가(P6) → 남은 비트코인 보호는 남은 코인만', (tester) async {
    final env = await pump(
      tester,
      utxos: [_utxo(incident, 1, 50000)],
      conflicts: const [SweepConflict(txid: _attackTxid, fee: 1410, vSize: 141, signalsRbf: true, confirmed: true)],
    );
    env.start();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-assist-unavailable')), findsOneWidget);
    // H11: 이유는 따로 한 줄
    expect(
      find.descendant(
        of: find.byKey(const Key('safety-assist-unavailable-reason')),
        matching: _koText((t.premium.protect.reason_confirmed)),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-assist-destination-wallet-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-assist-review-replace-warning')), findsNothing);
    expect(find.byKey(const Key('safety-assist-review-move-warning')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.sendInfo.transaction!.inputs.length, 1);
  });

  testWidgets('옮길 것이 없으면 보안 점검 계속하기로 닫힘', (tester) async {
    final env = await pump(tester, utxos: const [], conflicts: const []);
    final result = env.start();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-assist-nothing')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(await result, AssistExit.continueReview);
    expect(find.text('guide'), findsOneWidget);
  });

  testWidgets('목적지에서 나중에 계속하기 → later로 닫힘', (tester) async {
    final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const []);
    final result = env.start();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('safety-assist-destination-later')), 200);
    await tester.tap(find.byKey(const Key('safety-assist-destination-later')));
    await tester.pumpAndSettle();
    expect(await result, AssistExit.later);
    expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
  });

  testWidgets('수수료를 못 가져오면 실패 표시 + 다시 시도(자동 재시도 없음)', (tester) async {
    final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const [], fastFee: null);
    env.start();
    await tester.pumpAndSettle();
    expect(_koText((t.safety_guide.move.prepare_failed)), findsOneWidget);
    expect(find.byKey(const Key('safety-guide-button')), findsOneWidget);
    expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
  });

  testWidgets('지금 이동(비상 목적지): 분석 → 바로 검토(수수료 다시 계산 안내) → 기존 보내기 확인(home)', (tester) async {
    final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const []);
    final moving = SafetyAssistFlow.moveNow(
      env.host(),
      walletId: 1,
      destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 1)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
    expect(_koText((t.premium.rescue.recalculated)), findsOneWidget);
    expect(find.byKey(const Key('safety-assist-review-excludes')), findsNothing); // 빠진 코인 없음
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.pushed.last, AppRouteNames.sendConfirm);
    expect(env.sendInfo.sendEntryPoint, SendEntryPoint.home);
    expect(env.sendInfo.transaction!.outputs.single.getAddress(), destination.walletBase.getAddress(0));

    // 보내기 확인·검토에서 뒤로 가면 흐름이 닫힌다
    Navigator.of(env.host()).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
    Navigator.of(env.host()).pop();
    await tester.pumpAndSettle();
    await moving;
    expect(find.text('guide'), findsOneWidget);
  });

  testWidgets('새 지갑 추가: 추가 흐름에서 돌아오면 추가됨 화면, 같은 니모닉 지갑은 거절', (tester) async {
    final sameSeed = SinglesigWalletItem(
      id: 3,
      name: 'Same seed',
      colorIndex: 0,
      iconIndex: 0,
      descriptor: SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 1)), accountIndex: 1).descriptor,
    );
    final env = await pump(
      tester,
      utxos: [_utxo(incident, 1, 50000)],
      conflicts: const [],
      wallets: [incident, destination, sameSeed],
    );
    final session = AssistSession(wallet: incident, incidentTxids: const [], entryPoint: SendEntryPoint.home)
      ..remaining = SweepBuilder.plan(
        wallet: incident,
        utxos: [_utxo(incident, 1, 50000)],
        conflicts: const [],
        fastFeeRate: 2,
      );
    Navigator.of(env.host()).push(
      assistRoute(
        'add-wallet',
        AssistAddWalletScreen(
          sourceWallet: session.wallet,
          onAdded:
              (context, wallet) => Navigator.of(
                context,
              ).pushReplacement(assistRoute('wallet-added', AssistWalletAddedScreen(session: session, wallet: wallet))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> addViaScanner(int walletId) async {
      await tester.tap(find.byKey(const Key('safety-guide-button')));
      await tester.pumpAndSettle();
      expect(env.pushed.last, AppRouteNames.walletAddScanner);
      env.wallets.events.add(WalletAdded(walletId));
      await tester.pump();
      Navigator.of(env.host()).pop();
      await tester.pumpAndSettle();
    }

    await addViaScanner(3);
    final banner = find.byKey(const Key('safety-assist-add-same-seed'));
    expect(banner, findsOneWidget);
    for (final text in [t.premium.destination.excluded_wallet_title, t.premium.destination.excluded_wallet_body]) {
      expect(find.descendant(of: banner, matching: _koText((text))), findsOneWidget);
    }
    expect(find.byKey(const Key('safety-assist-wallet-added')), findsNothing);

    await addViaScanner(2);
    expect(find.byKey(const Key('safety-assist-wallet-added')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-result-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
  });

  testWidgets('지금 이동: 직전에 바뀐 비상 목적지로 보낸다(예전 상태 값은 안 씀)', (tester) async {
    final newDestination = _wallet(4, 4);
    final env = await pump(
      tester,
      utxos: [_utxo(incident, 1, 50000)],
      conflicts: const [],
      wallets: [incident, destination, newDestination],
      // SafetyProvider 상태에는 예전 목적지(지갑 2)가 남아 있다
      rescue: {1: (destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 1)), draft: null)},
    );
    SafetyAssistFlow.moveNow(
      env.host(),
      walletId: 1,
      destination: RescueDestination(walletId: 4, setAt: DateTime(2026, 10, 20)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review-address')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();

    final paid = env.sendInfo.transaction!.outputs.single.getAddress();
    expect(paid, newDestination.walletBase.getAddress(0));
    expect(paid, isNot(destination.walletBase.getAddress(0)));
  });

  testWidgets('지금 이동: 수수료 조회 실패면 마지막 수수료로, 다시 계산 안내는 없음', (tester) async {
    final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const [], fastFee: null);
    SafetyAssistFlow.moveNow(
      env.host(),
      walletId: 1,
      destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)),
      fallbackFeeRate: 4,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
    expect(_koText((t.premium.rescue.recalculated)), findsNothing);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.sendInfo.feeRate, greaterThanOrEqualTo(4));
  });

  testWidgets('비상 목적지(Rescue-ready 값)는 목적지 맨 위 "비상 목적지로 옮기기" 행', (tester) async {
    final env = await pump(
      tester,
      utxos: [_utxo(incident, 1, 50000)],
      conflicts: const [],
      rescueReady: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)),
    );
    env.start();
    await tester.pumpAndSettle();
    // H3: Health S3와 같은 Premium 행동 카드, 칩·밑줄 버튼 없음
    final card = find.byKey(const Key('safety-assist-rescue-card'));
    expect(tester.widget(card), isA<PremiumActionCard>());
    expect(find.descendant(of: card, matching: find.byType(PremiumChip)), findsNothing);
    expect(find.descendant(of: card, matching: find.byType(CoconutUnderlinedButton)), findsNothing);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('safety-assist-destination-wallet-2'));
    expect(find.descendant(of: row, matching: _koText((t.safety_guide.step2.move_to_rescue))), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.sendInfo.transaction!.outputs.single.getAddress(), destination.walletBase.getAddress(0));
  });

  group('G-R4: 페이월 결과가 true여도 그 사이 만료되면 새 자동화를 시작하지 않음', () {
    Future<void> subscribeThenExpire(WidgetTester tester, FakeEntitlementService premium) async {
      expect(find.byKey(const Key('premium-paywall')), findsOneWidget);
      await tester.tap(_koText(t.premium.paywall.subscribe));
      await tester.pumpAndSettle();
      expect(_koText(t.premium.purchased.title), findsOneWidget);
      // 결과 화면이 열린 사이 갱신 확인에서 만료·취소
      premium.emit(const PremiumState(PremiumStatus.expired));
      await tester.tap(_koText(t.confirm));
      await tester.pumpAndSettle();
    }

    testWidgets('대응 시작(대체 자동 준비)', (tester) async {
      final premium = FakeEntitlementService(products: _premiumProducts);
      final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const [], premium: premium);
      final started = env.start();
      await tester.pumpAndSettle();
      await subscribeThenExpire(tester, premium);

      expect(await started, isNull);
      expect(find.byKey(const Key('safety-assist-analyzing')), findsNothing);
      expect(env.analyzer.calls, 0);
      expect(find.text('guide'), findsOneWidget);
    });

    testWidgets('새 핫월렛 자동 생성', (tester) async {
      final premium = FakeEntitlementService(
        products: _premiumProducts,
        initial: const PremiumState(PremiumStatus.active),
      );
      final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const [], premium: premium);
      env.start();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-guide-button'))); // 남은 비트코인 보호
      await tester.pumpAndSettle();
      premium.emit(const PremiumState(PremiumStatus.expired));
      final newHot = find.byKey(const Key('safety-assist-destination-new-hot'));
      await tester.scrollUntilVisible(newHot, 200);
      await tester.tap(newHot);
      await tester.pumpAndSettle();
      await subscribeThenExpire(tester, premium);

      expect(env.auth.passcodeChecks, 0); // 지갑 생성 게이트까지 가지 않음
      expect(find.byKey(const Key('safety-assist-move-progress')), findsNothing);
      expect(find.byKey(const Key('safety-assist-destination')), findsOneWidget);
    });
  });

  testWidgets('AH1: 검토를 연 뒤 목적지 지갑이 사용 주의가 되면 넘기지 않고 목적지 선택으로', (tester) async {
    final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const []);
    env.start();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-assist-destination-wallet-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);

    await env.safety.setCaution(2, true);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
    expect(env.sendInfo.transaction, isNull);
    expect(find.byKey(const Key('safety-assist-destination')), findsOneWidget);
    expect(find.byKey(const Key('safety-assist-destination-wallet-2')), findsNothing);
    await tester.pump(const Duration(seconds: 4)); // 토스트
  });

  testWidgets('AH2: 검토 뒤 받는 중 UTXO가 확정되면 바뀐 검토를 다시 승인받고 함께 옮김', (tester) async {
    final confirmed = _utxo(incident, 1, 50000);
    final incoming = _utxo(incident, 2, 30000, status: UtxoStatus.incoming);
    final env = await pump(tester, utxos: [confirmed, incoming], conflicts: const []);
    env.start();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-assist-destination-wallet-2')));
    await tester.pumpAndSettle();

    // 지갑을 만들러 다녀온 사이 동기화로 확정됨
    env.wallets.utxos[1] = _utxo(incident, 2, 30000);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
    expect(find.byKey(const Key('safety-assist-review-updated')), findsOneWidget);

    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.pushed.last, AppRouteNames.sendConfirm);
    expect(env.sendInfo.transaction!.inputs.length, 2);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('AH2: 검토 뒤 충돌(자손 수수료)이 바뀌면 바뀐 수수료로 다시 승인', (tester) async {
    // 금액을 크게 둬서 수수료 20% 상한(Grok §4)에 걸리지 않게
    final stolen = _utxo(incident, 0, 900000, status: UtxoStatus.outgoing, spentBy: _attackTxid);
    const before = SweepConflict(txid: _attackTxid, fee: 1410, vSize: 141, signalsRbf: true);
    final env = await pump(tester, utxos: [stolen, _utxo(incident, 1, 30000)], conflicts: const [before]);
    env.start();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-guide-button'))); // 대체 거래 준비
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-assist-destination-wallet-2')));
    await tester.pumpAndSettle();

    env.analyzer.result = const [
      SweepConflict(
        txid: _attackTxid,
        fee: 1410,
        vSize: 141,
        signalsRbf: true,
        descendants: [
          (
            txid:
                'ef'
                'efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef',
            fee: 20000,
            vSize: 110.0,
          ),
        ],
      ),
    ];
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review-updated')), findsOneWidget);
    expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    final tx = env.sendInfo.transaction!;
    expect(tx.totalInputAmount - tx.outputs.single.amount, greaterThan(1410 + 20000));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('AH4: 음수 수수료 응답은 조회 실패로(대체 수수료가 없으면 실패·다시 시도)', (tester) async {
    final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const [], fastFee: -1);
    env.start();
    await tester.pumpAndSettle();
    expect(_koText((t.safety_guide.move.prepare_failed)), findsOneWidget);
    expect(find.byKey(const Key('safety-guide-button')), findsOneWidget);
  });

  testWidgets('AH4: 음수 수수료 응답 + 마지막 수수료가 있으면(지금 이동) 그 값으로, 다시 계산 안내 없음', (tester) async {
    final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const [], fastFee: -1);
    SafetyAssistFlow.moveNow(
      env.host(),
      walletId: 1,
      destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)),
      fallbackFeeRate: 4,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
    expect(find.byKey(const Key('safety-assist-review-recalculated')), findsNothing);
  });

  testWidgets('AH8: 준비된 비상 이동은 분석 전에 먼저(수수료 조회 실패와 무관), 다른 방법 보기 → 분석', (tester) async {
    final env = await pump(
      tester,
      utxos: [_utxo(incident, 1, 50000)],
      conflicts: const [],
      fastFee: null,
      rescueReady: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)),
      rescueCanMoveNow: true,
    );
    env.start();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-rescue-ready')), findsOneWidget);
    expect(env.analyzer.calls, 0);

    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.rescue!.moves, 1); // Track I의 검증된 지금 이동으로

    await tester.tap(find.byKey(const Key('safety-assist-other-options')));
    await tester.pumpAndSettle();
    expect(env.analyzer.calls, 1);
    expect(find.byKey(const Key('safety-assist-analyzing')), findsOneWidget); // 수수료 실패 → 실패 상태(분석 화면)
  });

  testWidgets('Grok §3: 지금 이동에서 대체가 막히면 이유를 먼저, 그 다음 남은 코인 검토(의심 거래 코인 빠짐 안내)', (tester) async {
    final env = await pump(
      tester,
      utxos: [_utxo(incident, 1, 50000)],
      conflicts: const [SweepConflict(txid: _attackTxid, fee: 1410, vSize: 141, signalsRbf: true, confirmed: true)],
    );
    SafetyAssistFlow.moveNow(
      env.host(),
      walletId: 1,
      destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('safety-assist-review')), findsNothing);
    expect(_koText((t.premium.protect.reason_confirmed)), findsOneWidget);

    await tester.tap(find.byKey(const Key('safety-guide-button'))); // 남은 비트코인 보호 → 바로 검토
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
    expect(find.byKey(const Key('safety-assist-review-excludes')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.pushed.last, AppRouteNames.sendConfirm);
  });

  testWidgets('Grok §4: 수수료 API 값이 비정상이면 노드 추정으로 계산하고 검토에 알림', (tester) async {
    final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const [], fastFee: 5000);
    SafetyAssistFlow.nodeFeeRateOverride = () async => 3;
    env.start();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-assist-destination-wallet-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review-fee-fallback')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.sendInfo.feeRate, lessThan(10));
  });

  testWidgets('Grok §4: 수수료가 받는 금액의 20%를 넘으면 막고, 더 낮은 수수료로 다시 계산한 뒤에만 넘김', (tester) async {
    final env = await pump(tester, utxos: [_utxo(incident, 1, 2000)], conflicts: const [], fastFee: 10);
    env.start();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-assist-destination-wallet-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review-fee-excessive')), findsOneWidget);

    for (var i = 0; i < 4 && find.byKey(const Key('safety-assist-review-fee-excessive')).evaluate().isNotEmpty; i++) {
      await tester.tap(find.byKey(const Key('safety-guide-button'))); // 더 낮은 수수료로 다시 계산
      await tester.pumpAndSettle();
      expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
    }
    expect(find.byKey(const Key('safety-assist-review-fee-excessive')), findsNothing);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    final tx = env.sendInfo.transaction!;
    final fee = tx.totalInputAmount - tx.outputs.single.amount;
    expect(fee * 100, lessThanOrEqualTo(tx.outputs.single.amount * SweepFee.maxSharePercent));
  });

  group('lead: 대체 하한 20% 예외', () {
    // 상대가 약 110 vB를 200 sat/vB로(수수료 22,000) 가져가는 중. 되찾으려면 하한만으로도 받는 금액의 20%를 넘는다
    SweepConflict attack({required bool verified}) =>
        SweepConflict(txid: _attackTxid, fee: 22000, vSize: 110, signalsRbf: true, feeVerified: verified);
    late UtxoState stolen, rest;
    setUp(() {
      stolen = _utxo(incident, 0, 100000, status: UtxoStatus.outgoing, spentBy: _attackTxid);
      rest = _utxo(incident, 1, 30000);
    });
    int feeOf(Transaction tx) => tx.totalInputAmount - tx.outputs.single.amount;
    Finder button(String text) =>
        find.descendant(of: find.byKey(const Key('safety-guide-button')), matching: find.text(text));

    Future<void> openReview(WidgetTester tester, Future<AssistExit?> Function() start) async {
      start();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-guide-button'))); // 대체 거래 준비
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-assist-destination-wallet-2')));
      await tester.pumpAndSettle();
    }

    testWidgets('확인한 하한이 20%를 넘으면 수수료·비율 경고, 첫 누름은 넘기지 않고 두 번째에 하한 수수료로 넘김', (tester) async {
      final env = await pump(tester, utxos: [stolen, rest], conflicts: [attack(verified: true)]);
      await openReview(tester, env.start);
      final floor = SweepBuilder.plan(
        wallet: incident,
        utxos: [stolen, rest],
        conflicts: [attack(verified: true)],
        fastFeeRate: 0,
      );
      expect(SweepFee.isExcessive(floor), isTrue);
      final percent = (floor.fee * 100 / floor.amount).ceil();
      expect(
        find.descendant(
          of: find.byKey(const Key('safety-assist-review-replacement-fee-high')),
          matching: _koText((t.premium.assist.replacement_fee_high(percent: percent))),
        ),
        findsOneWidget,
      );
      // 정확한 수수료는 버튼 위 네트워크 수수료 줄
      expect(
        tester.widget<Text>(find.byKey(const Key('safety-assist-review-fee'))).data,
        contains(BitcoinUnit.btc.displayBitcoinAmount(floor.fee, withUnit: true)),
      );
      expect(find.byKey(const Key('safety-assist-review-fee-excessive')), findsNothing);
      // 남은 코인만 옮기기는 따로 고를 때만
      expect(
        find.descendant(
          of: find.byKey(const Key('safety-assist-review-remaining-only')),
          matching: find.text(t.premium.assist.move_remaining_only),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('safety-guide-button')));
      await tester.pumpAndSettle();
      expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
      expect(button(t.premium.assist.replacement_fee_confirm), findsOneWidget);

      await tester.tap(find.byKey(const Key('safety-guide-button')));
      await tester.pumpAndSettle();
      expect(env.pushed.last, AppRouteNames.sendConfirm);
      final tx = env.sendInfo.transaction!;
      expect(feeOf(tx), floor.feeFloor);
      expect(tx.inputs.map((i) => i.transactionHash), contains(stolen.transactionHash)); // 계속 대체
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('고른 수수료율 때문에 20%를 넘으면(하한은 아래) 더 낮은 수수료 → 하한, 계속 대체', (tester) async {
      const cheap = SweepConflict(txid: _attackTxid, fee: 1410, vSize: 141, signalsRbf: true);
      final env = await pump(tester, utxos: [stolen, rest], conflicts: const [cheap], fastFee: 300);
      await openReview(tester, env.start);
      expect(find.byKey(const Key('safety-assist-review-fee-excessive')), findsOneWidget);
      expect(button(t.premium.assist.recalculate_lower_fee), findsOneWidget);

      await tester.tap(find.byKey(const Key('safety-guide-button')));
      await tester.pumpAndSettle();
      expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
      expect(find.byKey(const Key('safety-assist-review-fee-excessive')), findsNothing);
      expect(find.byKey(const Key('safety-assist-review-updated')), findsOneWidget);
      expect(find.byKey(const Key('safety-assist-review-replace-warning')), findsOneWidget);
      expect(find.byKey(const Key('safety-assist-review-excludes')), findsNothing);

      await tester.tap(find.byKey(const Key('safety-guide-button')));
      await tester.pumpAndSettle();
      expect(env.pushed.last, AppRouteNames.sendConfirm);
      final tx = env.sendInfo.transaction!;
      final floor = SweepBuilder.plan(
        wallet: incident,
        utxos: [stolen, rest],
        conflicts: const [cheap],
        fastFeeRate: 0,
      );
      expect(feeOf(tx), floor.feeFloor);
      expect(tx.inputs.map((i) => i.transactionHash), contains(stolen.transactionHash));
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('값을 모르는 입력이 있는 충돌이면 하한이어도 20%로 막고, 남은 코인만은 직접 골라야 바뀜', (tester) async {
      final env = await pump(tester, utxos: [stolen, rest], conflicts: [attack(verified: false)]);
      await openReview(tester, env.start);
      expect(find.byKey(const Key('safety-assist-review-fee-excessive')), findsOneWidget);
      expect(find.byKey(const Key('safety-assist-review-replacement-fee-high')), findsNothing);

      // 하한이라 대체한 채로 더 낮출 수 없다(버튼 비활성), 남은 코인만으로 자동으로 바꾸지 않는다
      await tester.tap(find.byKey(const Key('safety-guide-button')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(env.pushed, isNot(contains(AppRouteNames.sendConfirm)));
      expect(find.byKey(const Key('safety-assist-review-replace-warning')), findsOneWidget);
      expect(find.byKey(const Key('safety-assist-review-excludes')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('safety-assist-review-remaining-only')));
      await tester.tap(find.byKey(const Key('safety-assist-review-remaining-only')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-assist-review-updated')), findsOneWidget);
      expect(find.byKey(const Key('safety-assist-review-excludes')), findsOneWidget);
      await tester.tap(find.byKey(const Key('safety-guide-button')));
      await tester.pumpAndSettle();
      expect(env.pushed.last, AppRouteNames.sendConfirm);
      expect(env.sendInfo.transaction!.inputs.single.transactionHash, rest.transactionHash);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  for (final verified in [false, true]) {
    testWidgets('Grok §5: 받는 지갑의 서명 기기 검증 상태를 주소 위에(${verified ? '검증됨·날짜' : '미검증'})', (tester) async {
      final env = await pump(
        tester,
        utxos: [_utxo(incident, 1, 50000)],
        conflicts: const [],
        verifications: {
          if (verified)
            2: WatchOnlyVerification(
              method: VerificationMethod.qr,
              result: VerificationResult.match,
              descriptorHash: WalletVerification.descriptorHash(destination.descriptor),
              at: DateTime(2026, 10, 19),
            ),
        },
      );
      env.start();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-guide-button')));
      await tester.pumpAndSettle();
      // H8: 목적지 줄 아래에도 같은 검증 표시(확인됨 shieldCheck, 미확인 circleInfo)
      final row = find.byKey(const Key('safety-assist-destination-wallet-2'));
      expect(
        find.descendant(
          of: row,
          matching: _koText(
            verified ? t.premium.destination.verified_on(date: '26.10.19') : t.premium.destination.not_verified,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (w) =>
                w is SvgPicture &&
                w.bytesLoader is SvgAssetLoader &&
                (w.bytesLoader as SvgAssetLoader).assetName.endsWith(verified ? 'shield-check.svg' : 'circle-info.svg'),
          ),
        ),
        findsWidgets,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      final line = find.byKey(const Key('safety-assist-review-verification'));
      expect(
        find.descendant(
          of: line,
          matching: _koTextContaining(
            verified ? t.premium.destination.verified_on(date: '26.10.19') : t.premium.destination.not_verified,
          ),
        ),
        findsOneWidget,
      );
    });
  }

  group('Grok G6: 열린 기준점 검토 거래(사용자 거래일 수 있어 대체 안 함)', () {
    const reviewTxid = 'c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3';
    final baselines = {
      1: WalletBaseline(height: 100, at: DateTime(2026, 10, 1), pendingSentAtBaseline: const {reviewTxid}),
    };
    final reviewRecord = TransactionRecord(
      reviewTxid,
      DateTime(2026, 10, 1),
      0,
      TransactionType.sent,
      null,
      -40000,
      200,
      const [],
      const [],
      110,
      DateTime(2026, 10, 1),
    );
    Finder line(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: _koText((text)));
    Future<void> moveNow(WidgetTester tester, BuildContext host) async {
      SafetyAssistFlow.moveNow(
        host,
        walletId: 1,
        destination: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('검토 거래만 빠지면 중립 안내(확인 중인 거래), 그 거래 코인은 넣지 않음', (tester) async {
      final rest = _utxo(incident, 1, 50000);
      final env = await pump(
        tester,
        utxos: [_utxo(incident, 0, 40000, status: UtxoStatus.outgoing, spentBy: reviewTxid), rest],
        conflicts: const [],
        withIncident: false,
        baselines: baselines,
      );
      env.wallets.records[reviewTxid] = reviewRecord;
      await moveNow(tester, env.host());

      expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
      expect(line('safety-assist-review-excludes-review', t.premium.assist.excludes_under_review), findsOneWidget);
      expect(find.byKey(const Key('safety-assist-review-excludes')), findsNothing); // 의심 거래 안내는 아님
      await tester.tap(find.byKey(const Key('safety-guide-button')));
      await tester.pumpAndSettle();
      expect(env.pushed.last, AppRouteNames.sendConfirm);
      final tx = env.sendInfo.transaction!;
      expect(tx.inputs.single.transactionHash, rest.transactionHash);
      expect(tx.inputs.every((i) => i.sequence == SweepBuilder.rbfSequence), isTrue);
    });

    testWidgets('사건 코인과 검토 거래 코인이 함께 빠지면 두 안내 모두', (tester) async {
      final env = await pump(
        tester,
        utxos: [_utxo(incident, 0, 40000, status: UtxoStatus.outgoing, spentBy: reviewTxid), _utxo(incident, 1, 50000)],
        conflicts: const [SweepConflict(txid: _attackTxid, fee: 1410, vSize: 141, signalsRbf: true, confirmed: true)],
        baselines: baselines,
      );
      env.wallets.records[reviewTxid] = reviewRecord;
      await moveNow(tester, env.host());
      await tester.tap(find.byKey(const Key('safety-guide-button'))); // 대체 불가(P6) → 남은 비트코인 검토
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
      expect(line('safety-assist-review-excludes', t.premium.assist.excludes_suspicious), findsOneWidget);
      expect(line('safety-assist-review-excludes-review', t.premium.assist.excludes_under_review), findsOneWidget);
    });
  });

  group('H1: 잔액 숨김·가짜 잔액이면 Assist에 실제 금액을 보이지 않음(safetyHidesAmounts)', () {
    for (final (mode, hidden, fake) in const [('표시', false, false), ('가짜 잔액', false, true), ('잔액 숨김', true, false)]) {
      testWidgets(mode, (tester) async {
        final shows = !hidden && !fake;
        final env = await pump(
          tester,
          utxos: [
            _utxo(incident, 0, 90000, status: UtxoStatus.outgoing, spentBy: _attackTxid),
            _utxo(incident, 1, 30000, status: UtxoStatus.locked),
          ],
          conflicts: const [SweepConflict(txid: _attackTxid, fee: 1410, vSize: 141, signalsRbf: true)],
          preferences: _Preferences(hidden: hidden, fake: fake),
        );
        env.wallets.balances[1] = 120000;
        env.start();
        await tester.pumpAndSettle();
        // P2 요약의 남은 비트코인(잠긴 30,000)
        expect(
          find.text(BitcoinUnit.btc.displayBitcoinAmount(30000, withUnit: true)),
          shows ? findsOneWidget : findsNothing,
        );
        expect(find.text(t.premium.assist.hidden), shows ? findsNothing : findsOneWidget);

        await tester.tap(find.byKey(const Key('safety-guide-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('safety-assist-destination-wallet-2')));
        await tester.pumpAndSettle();
        // 검토의 보내는 지갑 카드 잔액. 가짜 잔액이면 실제 대신 가짜 금액(앱 잔액 표시 설정과 같게)
        expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
        expect(
          find.text(BitcoinUnit.btc.displayBitcoinAmount(120000, withUnit: true)),
          shows ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(BitcoinUnit.btc.displayBitcoinAmount(777, withUnit: true)),
          fake ? findsWidgets : findsNothing,
        );
      });
    }
  });

  testWidgets('H2: 받는 주소는 줄 수 제한 없이 끝까지(320dp·2.0배 글자에서도 대조할 마지막 글자가 남음)', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 2000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const [], textScale: 2);
    env.start();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-guide-button'))); // 대체 없음(P6) → 남은 비트코인
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-assist-destination-wallet-2')));
    await tester.pumpAndSettle();

    final address = find.descendant(
      of: find.byKey(const Key('safety-assist-review-address')),
      matching: find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            RegExp(r'^(bc|tb|bcrt)1[02-9ac-hj-np-z]{8,}$').hasMatch(w.text.toPlainText().replaceAll(' ', '')),
      ),
    );
    expect(address, findsOneWidget);
    await tester.ensureVisible(address);
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(address);
    expect(tester.widget<RichText>(address).maxLines, isNull);
    expect(paragraph.didExceedMaxLines, isFalse);
    // 여러 줄로 감싸여도 마지막 묶음(굵게)까지 그려진다
    final last = tester.widget<RichText>(address).text.toPlainText().split(' ').last;
    expect(
      paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: paragraph.text.toPlainText().length - last.length,
          extentOffset: paragraph.text.toPlainText().length,
        ),
      ),
      isNotEmpty,
    );
  });

  testWidgets('H5: 이미 있는 다른 시드 핫월렛 목적지의 부제는 지갑 종류(새 니모닉 안내 아님)', (tester) async {
    final env = await pump(
      tester,
      utxos: [_utxo(incident, 1, 50000)],
      conflicts: const [],
      wallets: [incident, destination, _hotWallet(3, 3)],
    );
    env.start();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('safety-assist-destination-wallet-3'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: _koText((t.wallet_home_screen.wallet_filter.hot))), findsOneWidget);
    expect(find.descendant(of: row, matching: _koText((t.premium.destination.new_hot_wallet_body))), findsNothing);
    // 새 핫월렛 줄은 그대로 새 니모닉 안내
    expect(
      find.descendant(
        of: find.byKey(const Key('safety-assist-destination-new-hot')),
        matching: _koTextContaining((t.premium.destination.new_hot_wallet_body)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('H3: 준비된 이동 카드의 버튼은 비상 목적지로 바로 검토', (tester) async {
    final env = await pump(
      tester,
      utxos: [_utxo(incident, 1, 50000)],
      conflicts: const [],
      rescueReady: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)),
    );
    env.start();
    await tester.pumpAndSettle();
    final button = find.descendant(
      of: find.byKey(const Key('safety-assist-rescue-card')),
      matching: _koText((t.premium.rescue.move_now)),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-review')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-guide-button')));
    await tester.pumpAndSettle();
    expect(env.sendInfo.transaction!.outputs.single.getAddress(), destination.walletBase.getAddress(0));
  });

  testWidgets('H12: 준비된 비상 이동 단계는 초안 있음 → 마지막 갱신 · 검토할 때 다시 계산', (tester) async {
    final preparedAt = DateTime.now().subtract(const Duration(minutes: 3));
    final env = await pump(
      tester,
      utxos: [_utxo(incident, 1, 50000)],
      conflicts: const [],
      rescueReady: RescueDestination(walletId: 2, setAt: DateTime(2026, 10, 20)),
      rescueCanMoveNow: true,
      rescueDraft: RescueDraftSummary(
        destinationAddress: destination.walletBase.getAddress(0),
        amount: 49000,
        fee: 1000,
        inputCount: 1,
        feeRate: 3,
        preparedAt: preparedAt,
      ),
    );
    env.start();
    await tester.pumpAndSettle();
    final r = t.premium.rescue;
    final description = [
      r.card_body,
      [r.last_updated(time: formatHomeRelativeTime(preparedAt, DateTime.now())), r.recalc_note].join(' · '),
    ].join('\n');
    expect(
      find.descendant(of: find.byKey(const Key('safety-assist-rescue-ready')), matching: _koText((description))),
      findsOneWidget,
    );
  });

  testWidgets('H6: 주소 직접 입력은 공용 시트(형식이 틀리면 확인 비활성, 맞으면 활성)', (tester) async {
    final env = await pump(tester, utxos: [_utxo(incident, 1, 50000)], conflicts: const []);
    env.start();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-guide-button'))); // P6 → 목적지
    await tester.pumpAndSettle();
    final manual = find.byKey(const Key('safety-assist-destination-address'));
    await tester.ensureVisible(manual);
    await tester.pumpAndSettle();
    await tester.tap(manual);
    await tester.pumpAndSettle();
    expect(find.byType(SafetyAddressEntry), findsOneWidget);
    bool confirmActive() =>
        tester.widget<InlineActionButton>(find.byKey(const Key('safety-assist-address-confirm'))).isActive;

    await tester.enterText(find.byKey(const Key('safety-assist-address-field')), 'nope');
    await tester.pump();
    expect(confirmActive(), isFalse);
    await tester.enterText(
      find.byKey(const Key('safety-assist-address-field')),
      'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx',
    );
    await tester.pump();
    expect(confirmActive(), isTrue);
    expect(env.analyzer.calls, 1);
  });

  testWidgets('GPT M6: 독일어·2.0배·320dp에서도 Assist 요약 줄이 넘치지 않음', (tester) async {
    final previous = LocaleSettings.currentLocale;
    LocaleSettings.setLocaleSync(AppLocale.de);
    addTearDown(() => LocaleSettings.setLocaleSync(previous));
    tester.view.physicalSize = const Size(320 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final env = await pump(
      tester,
      utxos: [
        _utxo(incident, 0, 90000, status: UtxoStatus.outgoing, spentBy: _attackTxid),
        _utxo(incident, 1, 30000, status: UtxoStatus.locked),
      ],
      conflicts: const [SweepConflict(txid: _attackTxid, fee: 1410, vSize: 141, signalsRbf: true)],
      preferences: _Preferences(hidden: false),
      textScale: 2,
    );
    env.start();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-assist-options')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
