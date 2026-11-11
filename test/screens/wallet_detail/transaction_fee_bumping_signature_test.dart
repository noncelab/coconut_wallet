import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../mock/transaction_mock.dart';
import '../../repository/realm/test_realm_manager.dart';

/// 서버(ElectrumService)만 가짜. 기록 조회·거래 원문·이전 거래·블록 시각을 정해진 값으로 돌려준다
class _Server implements ElectrumService {
  final Map<String, String> rawByHash = {};
  final Map<String, List<GetTxHistoryRes>> historyByAddress = {};

  @override
  Future<List<GetTxHistoryRes>> getHistory(AddressType addressType, String address) async =>
      historyByAddress[address] ?? [];

  @override
  Future<String> getTransaction(String txHash, {bool? verbose, Duration timeout = const Duration(seconds: 5)}) async =>
      rawByHash[txHash] ?? (throw StateError('unknown transaction $txHash'));

  @override
  Future<List<Transaction>> getPreviousTransactions(
    Transaction transaction, {
    List<Transaction>? existingTxList,
  }) async => [
    for (final input in transaction.inputs)
      if (rawByHash[input.transactionHash] case final raw?) Transaction.parse(raw),
  ];

  @override
  Future<Map<int, BlockTimestamp>> fetchBlocksByHeight(Set<int> heights) async => {
    for (final height in heights) height: BlockTimestamp(height, DateTime(2026, 11, 1)),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _State implements StateManagerInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 수수료 추천(FeeService → Dio → dart:io HttpClient)에 정해진 값을 돌려준다. 실제 네트워크는 쓰지 않는다
class _FeeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FeeHttpClient();
}

class _FeeHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {
    'content-type': ['application/json; charset=utf-8'],
  };
  @override
  void forEach(void Function(String name, List<String> values) action) => _map.forEach(action);
  @override
  String? value(String name) => _map[name.toLowerCase()]?.first;
  @override
  List<String>? operator [](String name) => _map[name.toLowerCase()];
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) => _map[name.toLowerCase()] = ['$value'];
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      (_map[name.toLowerCase()] ??= []).add('$value');
  @override
  void removeAll(String name) => _map.remove(name.toLowerCase());
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FeeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _FeeRequest(method, url);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FeeRequest implements HttpClientRequest {
  _FeeRequest(this.method, this.uri);
  @override
  final String method;
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _FeeHeaders();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  int contentLength = -1;
  @override
  bool bufferOutput = true;
  @override
  Future<HttpClientResponse> close() async => _FeeResponse();
  @override
  Future<HttpClientResponse> get done async => _FeeResponse();
  @override
  void add(List<int> data) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<void> flush() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FeeResponse extends Stream<List<int>> implements HttpClientResponse {
  final List<int> _body = utf8.encode('{"fastestFee":20,"halfHourFee":15,"hourFee":10,"economyFee":5,"minimumFee":1}');
  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  int get contentLength => _body.length;
  @override
  HttpHeaders get headers => _FeeHeaders()..set('content-length', _body.length);
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  bool get persistentConnection => false;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([
    _body,
  ]).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _walletId = 1;
const _depositAmount = 1000000;
const _paidAmount = 600000;

enum _Signer { hot, vault, hardware }

/// 지갑(합성 키 0x11)과 서버. 앞서 확정된 입금 거래 하나(코인 [coins]개)를 가진 채로 시작한다
class _Scenario {
  _Scenario(this.realm, _Signer signer, {int coins = 1}) {
    NetworkType.setNetworkType(NetworkType.regtest);
    final base = SingleSignatureWallet.fromDescriptor(vault.descriptor);
    wallet = SinglesigWalletItem(
      id: _walletId,
      name: 'Wallet',
      colorIndex: 0,
      iconIndex: 0,
      descriptor: vault.descriptor,
      walletImportSource: signer == _Signer.hardware ? WalletImportSource.trezor : WalletImportSource.coconutVault,
      hotWalletMetadata:
          signer == _Signer.hot
              ? HotWalletMetadata(
                walletId: _walletId,
                secureStorageKey: 'unused',
                masterFingerprint: vault.keyStore.masterFingerprint,
                derivationPath: vault.derivationPath,
                accountIndex: 0,
                backupVerified: true,
                enterPassphraseWhenSigning: false,
                createdAt: DateTime(2026),
              )
              : null,
    );
    receive0 = base.getAddress(0);
    realm.realm.write(() {
      realm.realm.add(RealmWalletBase(_walletId, 0, 0, wallet.descriptor, wallet.name, wallet.walletType.name));
      var id = 1;
      for (final isChange in [false, true]) {
        for (var i = 0; i < 10; i++) {
          realm.realm.add(
            RealmWalletAddress(
              id++,
              _walletId,
              base.getAddress(i, isChange: isChange),
              i,
              isChange,
              '${base.derivationPath}/${isChange ? 1 : 0}/$i',
              false,
              0,
              0,
              0,
            ),
          );
        }
      }
    });
    addresses = AddressRepository(realm);
    utxos = UtxoRepository(realm);
    txs = TransactionRepository(realm);
    final depositInput = TransactionInput.forPayment('ab' * 32, 0, sequence: 0xfffffffe)
      ..witnessList = ['30${'11' * 69}01', '02${'22' * 32}'];
    deposit = Transaction.withInputsAndOutputs(
      [depositInput],
      [for (var i = 0; i < coins; i++) TransactionOutput.forPayment(_depositAmount, receive0)],
      AddressType.p2wpkh,
    );
    server.rawByHash[deposit.transactionHash] = deposit.serialize();
  }

  final TestRealmManager realm;
  final vault = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 0x11)));
  final other = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 0x99))).getAddress(0);
  final shop = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 0x77))).getAddress(0);
  final server = _Server();
  late final SinglesigWalletItem wallet;
  late final String receive0;
  late final AddressRepository addresses;
  late final UtxoRepository utxos;
  late final TransactionRepository txs;
  late final Transaction deposit;

  String get _change0 => wallet.walletBase.getAddress(0, isChange: true);

  /// 이 지갑 키로 서명한 결제(상점에 600,000 sats)
  Transaction ownPayment() {
    final unsigned = Transaction.forSinglePayment(
      [
        for (var i = 0; i < deposit.outputs.length; i++)
          Utxo(deposit.transactionHash, i, _depositAmount, '${vault.derivationPath}/0/0'),
      ],
      shop,
      '${vault.derivationPath}/1/0',
      _paidAmount,
      5,
      vault,
    );
    return Psbt.parse(
      vault.addSignatureToPsbt(Psbt.fromTransaction(unsigned, vault).serialize()),
    ).getSignedTransaction(AddressType.p2wpkh);
  }

  /// 같은 입금을 다른 주소로 보내는, 서명이 맞지 않는 대기 거래
  Transaction unsignedSpend() {
    final input = TransactionInput.forPayment(deposit.transactionHash, 0, sequence: 0xfffffffd)
      ..witnessList = ['3044022011${'33' * 31}022022${'44' * 31}01', '03${'55' * 32}'];
    return Transaction.withInputsAndOutputs(
      [input],
      [
        TransactionOutput.forPayment(_paidAmount, other),
        TransactionOutput.forPayment(_depositAmount - _paidAmount - 1410, _change0),
      ],
      AddressType.p2wpkh,
    );
  }

  Future<void> start() => utxos.addAllUtxos(_walletId, [
    UtxoState(
      transactionHash: deposit.transactionHash,
      index: 0,
      amount: _depositAmount,
      derivationPath: '${vault.derivationPath}/0/0',
      blockHeight: 100,
      to: receive0,
      timestamp: DateTime(2026, 11, 1),
    ),
  ]);

  /// 서버가 받기 주소 0의 기록으로 [pending]을 보여 줄 때의 동기화. 대기 거래 서명 확인이 생기기 전 앱처럼
  /// 확인 없이 저장한다(업데이트 전에 이미 저장된 기록)
  Future<void> sync(Transaction pending, String status) async {
    server.rawByHash[pending.transactionHash] = pending.serialize();
    server.historyByAddress[receive0] = [
      GetTxHistoryRes(height: 100, txHash: deposit.transactionHash),
      GetTxHistoryRes(height: 0, txHash: pending.transactionHash),
    ];
    await TransactionSyncService(
      server,
      txs,
      TransactionRecordService(server, addresses),
      _State(),
      utxos,
      ScriptCallbackService(),
      pendingTransactionVerifier: UncheckedPendingTransactionVerifier(),
    ).fetchScriptTransaction(
      wallet,
      ScriptStatus(
        scriptPubKey: receive0,
        status: status,
        timestamp: DateTime.now(),
        derivationPath: '${vault.derivationPath}/0/0',
        address: receive0,
        index: 0,
        isChange: false,
      ),
      now: DateTime.now().subtract(const Duration(minutes: 20)),
    );
  }
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  _Wallets(this.scenario);
  final _Scenario scenario;
  @override
  WalletItemBase getWalletById(int id) => scenario.wallet;
  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) =>
      scenario.addresses.containsAddress(walletId, address, isChange: isChange);
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  @override
  bool hasTransactionConfirmed(int walletId, String txHash) => false;
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  String get language => 'ko';
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '';
  @override
  int? get bitcoinPriceKrw => null;
}

/// 수수료 올리기 화면이 원래 거래를 다시 받는 노드(NodeProvider.getTransaction)는 같은 서버를 본다
class _Node extends Fake with ChangeNotifier implements NodeProvider {
  _Node(this.scenario);
  final _Scenario scenario;
  @override
  Future<Result<String>> getTransaction(String txHash) async {
    final raw = scenario.server.rawByHash[txHash];
    return raw == null ? Result.failure(ErrorCodes.nodeUnknown) : Result.success(raw);
  }
}

/// 한국어 문장 사이 이음 문자(U+2060)를 빼고 비교한다
Finder _text(String text) => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.data ?? widget.textSpan?.toPlainText())?.replaceAll('⁠', '') == text,
  description: 'text "$text"',
);

Future<void> _openFeeBumping(WidgetTester tester, _Scenario scenario, TransactionRecord pending) async {
  final previous = HttpOverrides.current;
  HttpOverrides.global = _FeeHttpOverrides();
  addTearDown(() => HttpOverrides.global = previous);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SendInfoProvider>.value(value: SendInfoProvider()),
        ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets(scenario)),
        ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
        ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
        ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
        ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
        ChangeNotifierProvider<NodeProvider>(create: (_) => _Node(scenario)),
        Provider<AddressRepository>.value(value: scenario.addresses),
        Provider<UtxoRepository>.value(value: scenario.utxos),
        Provider<WalletPreferencesRepository>.value(value: WalletPreferencesRepository(scenario.realm)),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        home: CustomLoadingOverlay(
          child: TransactionFeeBumpingScreen(
            transaction: pending,
            feeBumpingType: FeeBumpingType.rbf,
            walletId: _walletId,
            walletName: scenario.wallet.name,
          ),
        ),
      ),
    ),
  );
  // 수수료 추천(가짜 HTTP)과 원래 거래 다시 받기가 끝날 때까지 실제 시간을 흘린다
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// UTXO를 몇 번 읽었는지 센다(수수료 올리기 준비가 화면을 닫은 뒤에도 이어지는지 보려고)
class _ObservedUtxos extends UtxoRepository {
  _ObservedUtxos(super.realmManager);
  int reads = 0;

  @override
  UtxoState? getUtxoState(int walletId, String utxoId, {bool includeDeleted = false}) {
    reads++;
    return super.getUtxoState(walletId, utxoId, includeDeleted: includeDeleted);
  }
}

/// 이전 화면 위에 수수료 올리기 화면을 연다(닫으면 이전 화면으로 돌아간다)
Future<void> _openFeeBumpingRoute(
  WidgetTester tester,
  _Scenario scenario,
  TransactionRecord pending,
  UtxoRepository utxos,
  GlobalKey<NavigatorState> navigator,
) async {
  final previous = HttpOverrides.current;
  HttpOverrides.global = _FeeHttpOverrides();
  addTearDown(() => HttpOverrides.global = previous);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SendInfoProvider>.value(value: SendInfoProvider()),
        ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets(scenario)),
        ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
        ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
        ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
        ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
        ChangeNotifierProvider<NodeProvider>(create: (_) => _Node(scenario)),
        Provider<AddressRepository>.value(value: scenario.addresses),
        Provider<UtxoRepository>.value(value: utxos),
        Provider<WalletPreferencesRepository>.value(value: WalletPreferencesRepository(scenario.realm)),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        navigatorKey: navigator,
        home: const Scaffold(body: Text('previous route')),
        initialRoute: '/fee',
        routes: {
          '/fee':
              (_) => CustomLoadingOverlay(
                child: TransactionFeeBumpingScreen(
                  transaction: pending,
                  feeBumpingType: FeeBumpingType.rbf,
                  walletId: _walletId,
                  walletName: scenario.wallet.name,
                ),
              ),
        },
      ),
    ),
  );
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  for (final signer in _Signer.values) {
    group('빨리 보내기(RBF) 원래 거래 서명 확인 (${signer.name})', () {
      late TestRealmManager realm;
      late _Scenario scenario;

      setUp(() {
        realm = TestRealmManager();
        scenario = _Scenario(realm, signer);
      });
      tearDown(() => realm.dispose());

      testWidgets('서명이 맞지 않는 대기 거래는 수수료 올리기 대신 서명 확인 불가 안내를 띄운다', (tester) async {
        final unsigned = scenario.unsignedSpend();
        await tester.runAsync(() async {
          await scenario.start();
          await scenario.sync(unsigned, 'unsigned');
        });
        final pending = scenario.txs.getTransactionRecord(_walletId, unsigned.transactionHash)!;

        await _openFeeBumping(tester, scenario, pending);

        expect(_text(t.transaction_fee_bumping_screen.dialog.unverified_original_title), findsOneWidget);
        expect(_text(t.transaction_fee_bumping_screen.dialog.unverified_original), findsOneWidget);
        expect(_text(t.transaction_fee_bumping_screen.current_fee), findsNothing);
      });

      testWidgets('같은 코인을 쓰는 서명 없는 거래가 내 결제를 대신한 것으로 기록돼도, 그 거래로는 수수료를 올리지 않는다', (tester) async {
        final own = scenario.ownPayment();
        final unsigned = scenario.unsignedSpend();
        await tester.runAsync(() async {
          await scenario.start();
          await scenario.sync(own, 'own');
          await scenario.sync(unsigned, 'replaced');
        });
        // 동기화는 이 거래를 내 결제의 수수료 올림으로 기록한다(빨리 보내기는 이 마지막 거래로 열린다)
        expect(scenario.txs.getRbfHistoryList(_walletId, unsigned.transactionHash), isNotEmpty);
        final pending = scenario.txs.getTransactionRecord(_walletId, unsigned.transactionHash)!;

        await _openFeeBumping(tester, scenario, pending);

        expect(_text(t.transaction_fee_bumping_screen.dialog.unverified_original_title), findsOneWidget);
      });

      testWidgets('이 지갑 키로 서명한 내 결제는 그대로 수수료를 올릴 수 있다', (tester) async {
        final own = scenario.ownPayment();
        await tester.runAsync(() async {
          await scenario.start();
          await scenario.sync(own, 'own');
        });
        final pending = scenario.txs.getTransactionRecord(_walletId, own.transactionHash)!;

        await _openFeeBumping(tester, scenario, pending);

        expect(_text(t.transaction_fee_bumping_screen.dialog.unverified_original_title), findsNothing);
        expect(_text(t.transaction_fee_bumping_screen.current_fee), findsOneWidget);
      });
    });
  }

  testWidgets('서명을 확인하는 동안 화면을 닫으면 늦게 끝난 결과로 수수료 올리기 준비를 이어 가지 않는다 (입력 180개)', (tester) async {
    final realm = TestRealmManager();
    addTearDown(realm.dispose);
    final scenario = _Scenario(realm, _Signer.hot, coins: 180);
    final own = scenario.ownPayment();
    expect(own.inputs, hasLength(180));
    await tester.runAsync(() async {
      await scenario.utxos.addAllUtxos(_walletId, [
        for (var i = 0; i < 180; i++)
          UtxoState(
            transactionHash: scenario.deposit.transactionHash,
            index: i,
            amount: _depositAmount,
            derivationPath: '${scenario.vault.derivationPath}/0/0',
            blockHeight: 100,
            to: scenario.receive0,
            timestamp: DateTime(2026, 11, 1),
          ),
      ]);
      await scenario.sync(own, 'own');
    });
    final pending = scenario.txs.getTransactionRecord(_walletId, own.transactionHash)!;
    final observed = _ObservedUtxos(realm);
    final navigator = GlobalKey<NavigatorState>();
    await _openFeeBumpingRoute(tester, scenario, pending, observed, navigator);

    // 입력 UTXO를 모두 읽고 다른 아이솔레이트에서 서명을 확인하는 동안 화면을 닫는다
    for (var i = 0; i < 200 && observed.reads < own.inputs.length; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(observed.reads, own.inputs.length);
    final viewModel = tester.element(find.byType(Scaffold)).read<FeeBumpingViewModel>();
    expect(viewModel.isInitializedSuccess, isNull);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('previous route'), findsOneWidget);
    final readsAtClose = observed.reads;

    // 다른 아이솔레이트의 확인이 끝날 만큼 실제 시간을 흘린다
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(tester.takeException(), isNull);
    expect(observed.reads, readsAtClose, reason: '닫은 뒤에는 UTXO를 다시 읽지 않는다');
    expect(viewModel.isInitializedSuccess, isNot(true), reason: '늦게 끝난 결과는 버린다');
  });
}
