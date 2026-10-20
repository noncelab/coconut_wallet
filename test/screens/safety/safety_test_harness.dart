import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../mock/transaction_record_mock.dart';

/// Track D 안전 화면 테스트 공용 하네스(지갑 1, 거래 tx1 = 사건 '1:tx1')
const kWalletId = 1;
const kTxid = 'tx1';
const kIncidentId = '$kWalletId:$kTxid';

SafetyIncident testIncident({
  String txid = kTxid,
  IncidentState state = IncidentState.detected,
  IncidentTxState txState = IncidentTxState.pending,
  IncidentResponseMode? mode,
  int guideStep = 0,
}) => SafetyIncident(
  walletId: kWalletId,
  txid: txid,
  detectedAt: DateTime(2026, 10, 20, 9),
  state: state,
  txState: txState,
  responseMode: mode ?? (state == IncidentState.detected ? null : IncidentResponseMode.free),
  guideStep: guideStep,
);

SafetyProvider fixedSafety({
  List<SafetyIncident> incidents = const [],
  Set<int> caution = const {},
  WalletHealthReport? report,
}) => SafetyProvider.fixed(report, state: SafetyState(incidents: incidents, cautionWalletIds: caution));

/// 사건 거래 기록: 5만 sats를 [kRecipient]로 보냄(거스름 1만 sats는 [kChange], 내 주소)
const kRecipient = 'bcrt1qrecipient0000000000000000000000000000';
const kChange = 'bcrt1qchange000000000000000000000000000000';

TransactionRecord _record(String txid, List<TransactionAddress>? outputs) =>
    TransactionRecordMock.createMockTransactionRecord(
      transactionHash: txid,
      amount: -50000,
      inputAddressList: [TransactionAddress('bcrt1qinput', 60141)],
      outputAddressList: outputs ?? [TransactionAddress(kRecipient, 50000), TransactionAddress(kChange, 10000)],
    );

/// 사건 화면이 쓰는 것만: 지갑 목록·잔액·거래 기록·내 주소
class FakeWallets extends Fake with ChangeNotifier implements WalletProvider {
  FakeWallets(
    this.wallets, {
    this.balance = 0,
    this.records = const {},
    this.owned = const {
      kWalletId: {kChange},
    },
    this.outputs,
  });

  final List<WalletItemBase> wallets;
  final int balance;
  final Set<String> records;

  /// 거래 기록의 출력(기본: [kRecipient] 5만 + 거스름 [kChange] 1만)
  final List<TransactionAddress>? outputs;

  /// 지갑 id → 그 지갑 주소(기본: 사건 지갑의 거스름만)
  final Map<int, Set<String>> owned;

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => owned[walletId]?.contains(address) ?? false;

  @override
  List<WalletItemBase> get walletItemList => wallets;

  @override
  Balance getWalletBalance(int walletId) => Balance(balance, 0);

  @override
  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) =>
      records.contains(transactionHash) ? _record(transactionHash, outputs) : null;
}

/// 잔액 숨김·가짜 잔액 설정만(단위는 BTC)
class FakePreferences extends Fake with ChangeNotifier implements PreferenceProvider {
  FakePreferences({this.isBalanceHidden = false, this.isFakeBalanceActive = false});

  @override
  final bool isBalanceHidden;

  @override
  final bool isFakeBalanceActive;

  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
}

/// 비상 이동 초안이 준비된 지갑(목적지 주소 [destination])
class FakeRescue extends Fake with ChangeNotifier implements RescueReadyProvider {
  FakeRescue({this.destination = 'bc1qvault'});

  final String destination;
  int moves = 0;

  @override
  bool canMoveNow(int walletId) => true;

  @override
  RescueDestination? destinationOf(int walletId) =>
      RescueDestination(address: destination, setAt: DateTime(2026, 10, 20));

  @override
  Future<void> moveNow(BuildContext context, int walletId) async => moves++;
}

Widget safetyTestApp(
  Widget home, {
  required SafetyProvider safety,
  WalletProvider? wallets,
  EntitlementService? entitlement,
  RescueReadyProvider? rescue,
  PreferenceProvider? preferences,
  CoconutThemeVariant variant = CoconutThemeVariant.light,
  Map<String, WidgetBuilder> routes = const {},
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<SafetyProvider>.value(value: safety),
    if (wallets != null) ChangeNotifierProvider<WalletProvider>.value(value: wallets),
    if (entitlement != null) Provider<EntitlementService>.value(value: entitlement),
    if (rescue != null) ChangeNotifierProvider<RescueReadyProvider>.value(value: rescue),
    if (preferences != null) ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
  ],
  child: MaterialApp(theme: buildCoconutThemeData(variant: variant), home: home, routes: routes),
);

/// 가이드·시트를 여는 쪽 화면(내비게이터 아래 context)
Widget origin({Widget? child}) =>
    Scaffold(key: const Key('origin'), body: SingleChildScrollView(child: child ?? const SizedBox()));

BuildContext originContext(WidgetTester tester) => tester.element(find.byKey(const Key('origin')));

/// 390×844 휴대폰 화면
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// 320×640 작은 휴대폰 + 시스템 글자 배율 [scale](POLISH §5·GPT adaptive 검사 조건)
void useSmallPhone(WidgetTester tester, double scale) {
  tester.view.physicalSize = const Size(320 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// 이 테스트 동안만 [locale](긴 독일어 등). 문구는 테스트 안에서 `t.…`로 읽는다
void useLocale(AppLocale locale) {
  final before = LocaleSettings.currentLocale;
  LocaleSettings.setLocaleSync(locale);
  addTearDown(() => LocaleSettings.setLocaleSync(before));
}

/// 화면 글로 찾되 R1 이음 문자(U+2060)는 뺀다. 한국어 제목·본문은 단어 가운데 줄바꿈을 막으려고 글자 사이에 넣는다
Finder findText(String text, {bool skipOffstage = true}) => find.byWidgetPredicate(
  (widget) => widget is Text && _plainText(widget) == text,
  description: 'text "$text"',
  skipOffstage: skipOffstage,
);

Finder findTextContaining(String text) => find.byWidgetPredicate(
  (widget) => widget is Text && (_plainText(widget)?.contains(text) ?? false),
  description: 'text containing "$text"',
);

String? _plainText(Text widget) => (widget.data ?? widget.textSpan?.toPlainText())?.replaceAll('\u2060', '');

/// 보이게 스크롤한 뒤 누른다
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 토스트 닫힘 타이머(3초)까지 흘려보낸다
Future<void> settleToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}
