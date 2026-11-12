import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/transaction_detail_view_model.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/network/socket/socket_manager.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../repository/realm/test_realm_manager.dart';

/// mainnet 블록 974348의 segwit coinbase (witness commitment·OP_RETURN 출력 포함)
const _segwitCoinbase =
    '010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff54030cde0e174d696e6564206279204c75786f72c500a5066efcffb601fabe6d6da908b586aba7f6acac5bab755ca68c0bcbf3acf63aa36658a8811e288ebd509c100000000000000000000ad0000000000000001affffffff05220200000000000017a914bf73ad4cf3a107812bad3deb310611bee49a3c79875181a2120000000017a914056adde53ebc396a1b3b678bb0d3a5c116ff430c870000000000000000266a24aa21a9ede81ab8ab0f420793c41e1b720e64683981756d14bd63c30ae4cc357f5dc983e000000000000000002f6a2d434f524501a21cbd3caa4fe89bccd1d716c92ce4533e4d4733f459cc4ca322d298304ff163b2a360d756c5db8400000000000000002b6a2952534b424c4f434b3ae027f6b7e503f9e32b9e598a5d16bdc9d2a223bda39073ba11117f1d008f1f7e0120000000000000000000000000000000000000000000000000000000000000000000000000';

/// mainnet 블록 974375의 일반 거래 (P2SH 멀티시그 지출)
final _knownInputs = [TransactionAddress('bc1qknowninput0000000000000000000000000000', 100000)];

const _normalTransaction =
    '020000000102817ff5816ab1089c3ab748c396966c95f6804d3fd4d2502f26239b6028114400000000fc0047304402202e62a8721861731146eb233300b6bb69f874e96fd00014406de81cf5bef36c8402206fe7b73a97f51bd0f41c4df15c0b13748029b714053b2f2497e4c118ada82c2a0147304402201405683cd4dbbb0a276e44dba891555ab46c8f0e70bc897a3f551e7116a351f902206052a0f6975865d600835bd046079eb11392605a74619b42a730fc146465e4cd014c6952210222a9e782e240e4af71abc5a3596ea79cae3464c0b24068aed78bb152f730248d210259ed71ed808ada292c5b53ff5dbacad2c92be4d6d77e4369c57732b31ea3fdc1210368960b9ac05e1b8a7bd8b914ab116e82f9846964201e4f4c876747c3abd5407b53aefdffffff01dd4c00000000000016001456c3ae770a0af960fc238745f7a73d919cd24b5824de0e00';

late WalletItemBase _wallet;
late TransactionRecord _tx;
late String _txHex;
String? _myAddress;

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  @override
  WalletItemBase getWalletById(int id) => _wallet;
  @override
  bool isTransactionSuspicious(TransactionRecord transaction) => false;
  @override
  bool containsAddressInAnyWallet(String address) => address == _myAddress;
  @override
  List<WalletItemBase> get walletItemList => [_wallet];
  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => address == _myAddress;
  @override
  int? findWalletIdContainingAddress(String address) => address == _myAddress ? 1 : null;
  @override
  UtxoState? getUtxoState(int walletId, String utxoId) => null;
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  @override
  TransactionRecord? getTransaction(int walletId, String txHash, {String? utxoTo}) => _tx;
  @override
  TransactionRecord? getTransactionRecord(int walletId, String txHash) => _tx;
  @override
  TransactionRecord? get transaction => _tx;
  @override
  void initTransaction(int walletId, String txHash, {String? utxoTo}) {}

  @override
  Future<void> updateTransaction(int walletId, String txHash, TransactionRecord updatedTx) async => _tx = updatedTx;

  /// 동기화·멤풀 보정으로 저장된 기록이 바뀐 것처럼 알림
  void replaceRecord(TransactionRecord record) {
    _tx = record;
    notifyListeners();
  }
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
}

class _Explorer extends Fake with ChangeNotifier implements BlockExplorerProvider {}

class _Addresses extends Fake implements AddressRepository {
  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => address == _myAddress;
  @override
  String getDerivationPath(int walletId, String address) => "m/84'/0'/0'/0/0";
}

/// 지갑별 업데이트 상태를 직접 바꿀 수 있는 노드
class _Node extends Fake with ChangeNotifier implements NodeProvider {
  final _walletStates = StreamController<Map<int, WalletUpdateInfo>>.broadcast();
  Map<int, WalletUpdateInfo> _registered = {};
  TransactionRecord? refreshedRecord;

  @override
  Future<Result<TransactionRecord>> getTransactionRecord(
    WalletItemBase walletItem,
    String txHash, {
    Duration? timeout,
  }) async => Result.success(refreshedRecord!);

  void setSyncing(int walletId, bool syncing) {
    _registered = {
      ..._registered,
      walletId: WalletUpdateInfo(
        walletId,
        subscription: WalletSyncState.completed,
        balance: WalletSyncState.completed,
        transaction: WalletSyncState.completed,
        utxo: WalletSyncState.completed,
        isSyncQueued: syncing,
        balanceSnapshot: 0,
      ),
    };
    _walletStates.add(_registered);
  }

  @override
  NodeProviderState get state =>
      NodeProviderState(nodeSyncState: NodeSyncState.completed, registeredWallets: _registered);
  @override
  Stream<NodeSyncState> get syncStateStream => const Stream.empty();
  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async =>
      Result.success(BlockTimestamp(974400, DateTime(2026, 11, 3)));
  @override
  Future<Result<String>> getTransaction(String txHash) async => Result.success(_txHex);
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) =>
      _walletStates.stream.map((wallets) => wallets[walletId]).where((state) => state != null).cast<WalletUpdateInfo>();
}

const _captureDir = String.fromEnvironment('TX_DETAIL_CAPTURE_DIR');

void main() {
  late TestRealmManager manager;
  late _Node node;
  late List<String?> pushedRoutes;
  late List<Object?> pushedArguments;
  final boundaryKey = GlobalKey();

  setUpAll(() async {
    NetworkType.setNetworkType(NetworkType.mainnet);
    LocaleSettings.setLocaleSync(AppLocale.ko);
    if (_captureDir.isNotEmpty) {
      // 테스트에는 한글 대체 폰트가 없어 숫자 글꼴 자리도 Pretendard로 그림 (캡처 전용)
      for (final family in ['Pretendard', 'SpaceGrotesk']) {
        final loader = FontLoader(family);
        for (final weight in ['Regular', 'Bold']) {
          loader.addFont(
            Future.value(ByteData.sublistView(File('assets/fonts/Pretendard-$weight.ttf').readAsBytesSync())),
          );
        }
        await loader.load();
      }
    }
  });
  tearDownAll(() => NetworkType.setNetworkType(NetworkType.regtest));
  setUp(() {
    manager = TestRealmManager();
    node = _Node();
    pushedRoutes = [];
    pushedArguments = [];
  });
  tearDown(() => manager.dispose());

  /// 이전 거래 없이 기록을 만들어 입력 목록이 빈 상태로 상세 화면을 연다
  TransactionRecord correctedSentRecord() => TransactionRecord.fromTransactions(
    transactionHash: _tx.transactionHash,
    timestamp: _tx.timestamp,
    blockHeight: 0,
    transactionType: TransactionType.sent,
    amount: -_tx.amount,
    fee: 300,
    inputAddressList: _knownInputs,
    outputAddressList: _tx.outputAddressList,
    vSize: _tx.vSize,
  );

  Future<void> openDetail(
    WidgetTester tester,
    String hex, {
    int blockHeight = 974348,
    List<TransactionAddress>? inputAddressList,
  }) async {
    _txHex = hex;
    final tx = Transaction.parse(hex);
    _myAddress = tx.outputs.map((output) => output.scriptPubKey.getAddress()).first;
    _wallet = SinglesigWalletItem(
      id: 1,
      name: 'QA',
      colorIndex: 0,
      iconIndex: 0,
      descriptor: SingleSignatureVault.fromEntropy(Uint8List(16)).descriptor,
    );
    final details = TransactionRecordService(
      ElectrumService(socketManager: SocketManager()),
      _Addresses(),
    ).processTransactionDetails(tx, const [], 1);
    _tx = TransactionRecord.fromTransactions(
      transactionHash: tx.transactionHash,
      timestamp: DateTime(2026, 11, 3),
      blockHeight: blockHeight,
      transactionType: details.txType,
      amount: details.amount,
      fee: details.fee,
      inputAddressList: inputAddressList ?? details.inputAddressList,
      outputAddressList: details.outputAddressList,
      vSize: tx.getVirtualByte(),
    );
    final tags = UtxoTagProvider(UtxoRepository(manager));
    addTearDown(tags.dispose);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1179, 2556);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets()),
          ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          ChangeNotifierProvider<BlockExplorerProvider>(create: (_) => _Explorer()),
          ChangeNotifierProvider<NodeProvider>.value(value: node),
          ChangeNotifierProvider<UtxoTagProvider>.value(value: tags),
          Provider<AddressRepository>.value(value: _Addresses()),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
            home: TransactionDetailScreen(id: 1, txHash: tx.transactionHash),
            onGenerateRoute: (settings) {
              pushedRoutes.add(settings.name);
              pushedArguments.add(settings.arguments);
              return MaterialPageRoute<void>(builder: (_) => const SizedBox());
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> expandInputOutput(WidgetTester tester) async {
    await tester.tap(find.text(t.transaction_detail_screen.input_output_detail_title));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (_captureDir.isEmpty) return;
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('$_captureDir/$name.png').writeAsBytes(png.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('segwit coinbase는 입력 경고 대신 채굴 보상 안내를 보여 준다', (tester) async {
    await openDetail(tester, _segwitCoinbase);
    await expandInputOutput(tester);

    expect(find.text(t.transaction_detail_screen.coinbase_input), findsOneWidget);
    expect(find.text(t.errors.empty_input), findsNothing);
  });

  testWidgets('이전 거래를 찾지 못한 일반 거래는 입력 경고를 그대로 보여 준다', (tester) async {
    await openDetail(tester, _normalTransaction);
    await expandInputOutput(tester);

    expect(find.text(t.errors.empty_input), findsOneWidget);
    expect(find.text(t.transaction_detail_screen.coinbase_input), findsNothing);
  });

  group('빨리 받기', () {
    testWidgets('이 지갑이 업데이트 중이면 눌러도 수수료 올리기로 넘어가지 않고, 끝나면 넘어간다', (tester) async {
      node.setSyncing(1, true);
      await openDetail(tester, _normalTransaction, blockHeight: 0, inputAddressList: _knownInputs);
      await capture(tester, 'quick_receive_syncing');

      await tester.tap(find.text(t.quick_receive));
      await tester.pump(const Duration(milliseconds: 300));
      expect(pushedRoutes, isEmpty);

      node.setSyncing(1, false);
      await tester.pump(const Duration(milliseconds: 100));
      await capture(tester, 'quick_receive_synced');
      await tester.tap(find.text(t.quick_receive));
      await tester.pump(const Duration(milliseconds: 300));
      expect(pushedRoutes, [AppRouteNames.transactionFeeBumping]);
    });

    testWidgets('다른 지갑만 업데이트 중이면 막지 않는다', (tester) async {
      node.setSyncing(2, true);
      await openDetail(tester, _normalTransaction, blockHeight: 0, inputAddressList: _knownInputs);

      await tester.tap(find.text(t.quick_receive));
      await tester.pump(const Duration(milliseconds: 300));
      expect(pushedRoutes, [AppRouteNames.transactionFeeBumping]);
    });

    testWidgets('이전 거래를 못 받아 입력을 모르는 기록이면 업데이트가 끝나도 막는다', (tester) async {
      node.setSyncing(1, false);
      await openDetail(tester, _normalTransaction, blockHeight: 0);
      await capture(tester, 'quick_receive_unknown_inputs');

      await tester.tap(find.text(t.quick_receive));
      await tester.pump(const Duration(milliseconds: 300));
      expect(pushedRoutes, isEmpty);
    });

    testWidgets('입력을 모르던 보낸 거래가 보정되면 빨리 보내기(RBF)로 열린다', (tester) async {
      node.setSyncing(1, false);
      await openDetail(tester, _normalTransaction, blockHeight: 0);
      expect(find.text(t.quick_receive), findsOneWidget);

      final corrected = correctedSentRecord();
      (tester.element(find.byType(TransactionDetailScreen)).read<TransactionProvider>() as _Transactions).replaceRecord(
        corrected,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(t.quick_send), findsOneWidget);
      await tester.tap(find.text(t.quick_send));
      await tester.pump(const Duration(milliseconds: 300));
      expect(pushedRoutes, [AppRouteNames.transactionFeeBumping]);
      expect((pushedArguments.single as TransactionFeeBumpingRouteArgs).feeBumpingType, FeeBumpingType.rbf);
    });

    testWidgets('당겨서 새로고침으로 보정된 보낸 거래도 빨리 보내기(RBF)로 열린다', (tester) async {
      node.setSyncing(1, false);
      await openDetail(tester, _normalTransaction, blockHeight: 0);
      expect(find.text(t.quick_receive), findsOneWidget);

      node.refreshedRecord = correctedSentRecord();
      await tester.element(find.text(t.quick_receive)).read<TransactionDetailViewModel>().onRefresh();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(t.quick_send), findsOneWidget);
      await tester.tap(find.text(t.quick_send));
      await tester.pump(const Duration(milliseconds: 300));
      expect((pushedArguments.single as TransactionFeeBumpingRouteArgs).feeBumpingType, FeeBumpingType.rbf);
    });
  });
}
