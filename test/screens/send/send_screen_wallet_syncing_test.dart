import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart' as app_field;
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/screens/send/utxo_selection_screen.dart';
import 'package:coconut_wallet/screens/send/send_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _captureDir = String.fromEnvironment('SEND_SYNC_CAPTURE_DIR');

late List<WalletItemBase> _wallets;
var _isManualUtxoSelectionMode = false;
final Map<int, List<UtxoState>> _utxosByWallet = {};

UtxoState _utxo(String hash, int amount, {UtxoStatus status = UtxoStatus.unspent}) => UtxoState(
  transactionHash: hash * 64,
  index: 0,
  amount: amount,
  derivationPath: "m/84'/1'/0'/0/0",
  blockHeight: 100,
  to: 'bcrt1qtest',
  timestamp: DateTime(2026, 11, 4),
  status: status,
);

WalletAddress _address(int index, {bool isChange = false}) =>
    WalletAddress('bcrt1q${'q' * 38}', "m/84'/1'/0'/${isChange ? 1 : 0}/$index", index, isChange, false, 0, 0, 0);

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  @override
  List<WalletItemBase> get walletItemList => _wallets;
  @override
  WalletItemBase getWalletById(int id) => _wallets.firstWhere((wallet) => wallet.id == id);
  @override
  List<UtxoState> getUtxoList(int walletId) => _utxosByWallet[walletId] ?? [];
  @override
  WalletAddress getChangeAddress(int walletId) => _address(0, isChange: true);
  @override
  WalletAddress getReceiveAddress(int walletId) => _address(0);
  @override
  Map<int, WalletAddress> getReceiveAddressMap() => {for (final wallet in _wallets) wallet.id: _address(0)};
  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => false;
}

class _Tags extends Fake with ChangeNotifier implements UtxoTagProvider {
  @override
  List<UtxoTag> getUtxoTagList(int walletId) => const [];
  @override
  List<UtxoTag> getUtxoTagsByUtxoId(int walletId, String utxoId) => const [];
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '';
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  bool get isManualUtxoSelectionMode => _isManualUtxoSelectionMode;
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
  @override
  List<int> get walletOrder => const [];
  @override
  String get language => 'ko';
  @override
  bool get hasSeenAddRecipientCard => true;
  @override
  Future<void> setHasSeenAddRecipientCard() async {}
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

class _Auth extends Fake with ChangeNotifier implements AuthProvider {}

class _Drafts extends Fake implements TransactionDraftRepository {}

class _Utxos extends Fake implements UtxoRepository {
  @override
  (List<UtxoState>, SelectedUtxoExcludedStatus?) getValidatedSelectedUtxoList(
    int walletId,
    List<String> selectedUtxoIds,
  ) {
    final valid =
        (_utxosByWallet[walletId] ?? [])
            .where((utxo) => selectedUtxoIds.contains(utxo.utxoId) && utxo.status == UtxoStatus.unspent)
            .toList();
    return (valid, valid.length < selectedUtxoIds.length ? SelectedUtxoExcludedStatus.used : null);
  }
}

/// 지갑별 업데이트 상태를 직접 바꿀 수 있는 노드
class _Node extends Fake with ChangeNotifier implements NodeProvider {
  final _walletStates = StreamController<Map<int, WalletUpdateInfo>>.broadcast();
  final _syncStates = StreamController<NodeSyncState>.broadcast();
  Map<int, WalletUpdateInfo> _registered = {};

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
  Stream<NodeSyncState> get syncStateStream => _syncStates.stream;
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) =>
      _walletStates.stream.map((wallets) => wallets[walletId]).where((state) => state != null).cast<WalletUpdateInfo>();
}

void main() {
  late _Node node;
  final boundaryKey = GlobalKey();

  setUpAll(() async {
    NetworkType.setNetworkType(NetworkType.regtest);
    LocaleSettings.setLocaleSync(AppLocale.ko);
    if (_captureDir.isNotEmpty) {
      for (final family in ['Pretendard', 'SpaceGrotesk']) {
        final loader = FontLoader(family);
        // 테스트에는 한글 대체 폰트가 없어 숫자 글꼴 자리도 Pretendard로 그림 (캡처 전용)
        for (final source in {'Pretendard'}) {
          for (final weight in ['Regular', 'Bold']) {
            loader.addFont(
              Future.value(ByteData.sublistView(File('assets/fonts/$source-$weight.ttf').readAsBytesSync())),
            );
          }
        }
        await loader.load();
      }
    }
  });

  setUp(() {
    final descriptor = SingleSignatureVault.fromEntropy(Uint8List(16)).descriptor;
    _wallets = [
      SinglesigWalletItem(id: 1, name: 'A 지갑', colorIndex: 0, iconIndex: 0, descriptor: descriptor),
      SinglesigWalletItem(id: 2, name: 'B 지갑', colorIndex: 1, iconIndex: 1, descriptor: descriptor),
    ];
    _utxosByWallet
      ..clear()
      ..[1] = [_utxo('a', 50000000), _utxo('b', 30000000)]
      ..[2] = [_utxo('c', 10000000)];
    node = _Node();
    _isManualUtxoSelectionMode = false;
  });

  Future<void> openSend(WidgetTester tester, int walletId, {List<UtxoState>? selectedUtxoList}) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets()),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
          ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
          ChangeNotifierProvider<NodeProvider>.value(value: node),
          ChangeNotifierProvider<UtxoTagProvider>(create: (_) => _Tags()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          Provider<SendInfoProvider>(create: (_) => SendInfoProvider()),
          Provider<TransactionDraftRepository>(create: (_) => _Drafts()),
          Provider<UtxoRepository>(create: (_) => _Utxos()),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
            home: SendScreen(
              walletId: walletId,
              sendEntryPoint: SendEntryPoint.walletDetail,
              selectedUtxoList: selectedUtxoList,
            ),
          ),
        ),
      ),
    );
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

  testWidgets('보내는 지갑이 업데이트 중이면 UTXO 버튼 자리에 업데이트 중을 보여 주고, 끝나면 갱신된 잔액으로 돌아온다', (tester) async {
    node.setSyncing(1, true);
    await openSend(tester, 1);
    await capture(tester, 'send_syncing');

    expect(find.text(t.status_updating), findsOneWidget);
    expect(find.text(t.send_screen.utxo_auto_selection), findsNothing);

    await tester.tap(find.text(t.status_updating));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(t.utxo_selection_screen.title), findsNothing, reason: '업데이트 중에는 UTXO 선택 시트가 열리지 않는다');

    _utxosByWallet[1] = [_utxo('a', 50000000), _utxo('b', 30000000, status: UtxoStatus.outgoing)];
    node.setSyncing(1, false);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await capture(tester, 'send_synced');

    expect(find.text(t.status_updating), findsNothing);
    expect(find.text(t.send_screen.utxo_auto_selection), findsOneWidget);
  });

  testWidgets('다른 지갑이 업데이트 중이어도 보내는 지갑이 끝났으면 막지 않는다', (tester) async {
    node.setSyncing(1, false);
    node.setSyncing(2, true);
    await openSend(tester, 1);
    await capture(tester, 'send_other_wallet_syncing');

    expect(find.text(t.status_updating), findsNothing);
    expect(find.text(t.send_screen.utxo_auto_selection), findsOneWidget);
  });

  testWidgets('직접 고른 UTXO가 업데이트 중 사용되면 빼고 알린다', (tester) async {
    node.setSyncing(1, true);
    await openSend(tester, 1, selectedUtxoList: [_utxo('a', 50000000), _utxo('b', 30000000)]);

    _utxosByWallet[1] = [_utxo('a', 50000000), _utxo('b', 30000000, status: UtxoStatus.outgoing)];
    node.setSyncing(1, false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await capture(tester, 'send_used_utxo_excluded');

    expect(find.text(t.send_screen.toast.draft_utxo_used), findsOneWidget);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('다음 화면으로 넘어가 가려진 동안 고른 UTXO가 빠지면, 그 화면 위에 알리지 않고 돌아왔을 때 알린다', (tester) async {
    node.setSyncing(1, true);
    await openSend(tester, 1, selectedUtxoList: [_utxo('a', 50000000), _utxo('b', 30000000)]);
    final navigator = Navigator.of(tester.element(find.byType(SendScreen)));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('confirm'))));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    _utxosByWallet[1] = [_utxo('a', 50000000), _utxo('b', 30000000, status: UtxoStatus.outgoing)];
    node.setSyncing(1, false);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(t.send_screen.toast.draft_utxo_used), findsNothing);

    navigator.pop();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(t.send_screen.toast.draft_utxo_used), findsOneWidget);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('수동 선택 모드에서 업데이트를 기다리는 동안 다른 화면을 열면, 그 위에 UTXO 선택 시트를 띄우지 않고 돌아왔을 때 띄운다', (tester) async {
    _isManualUtxoSelectionMode = true;
    node.setSyncing(1, true);
    await openSend(tester, 1);
    final navigator = Navigator.of(tester.element(find.byType(SendScreen)));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('scanner'))));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    node.setSyncing(1, false);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(UtxoSelectionScreen, skipOffstage: false), findsNothing);

    navigator.pop();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(UtxoSelectionScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('주소를 입력하다가 금액 영역을 한 번 누르면 바로 금액 입력으로 넘어간다', (tester) async {
    await openSend(tester, 1);
    // 금액은 화면에 보이지 않는 입력란(커서·선택 없음)이 받고, 주소는 CoconutTextField 안의 입력란이 받는다.
    final amountField = find.byWidgetPredicate(
      (w) => w is TextField && w.showCursor == false && w.enableInteractiveSelection == false,
    );
    final addressField = find.descendant(
      of: find.byType(app_field.CoconutTextField).first,
      matching: find.byType(CupertinoTextField),
    );
    FocusNode focusOf(Finder finder) => switch (tester.widget(finder.first)) {
      final TextField field => field.focusNode!,
      final CupertinoTextField field => field.focusNode!,
      _ => throw StateError('not a text field'),
    };

    await tester.tap(addressField.first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(focusOf(addressField).hasFocus, isTrue);

    final page = tester.getRect(find.byType(PageView).first);
    await tester.tapAt(Offset(page.center.dx, page.top + 60));
    await tester.pump(const Duration(milliseconds: 300));
    expect(focusOf(addressField).hasFocus, isFalse);
    expect(focusOf(amountField).hasFocus, isTrue, reason: '한 번 누르면 바로 금액 키보드가 떠야 한다');

    // 금액 키보드가 떠 있을 때 금액 영역을 다시 누르면 지금처럼 키보드를 닫는다.
    await tester.tapAt(Offset(page.center.dx, page.top + 60));
    await tester.pump(const Duration(milliseconds: 300));
    expect(focusOf(amountField).hasFocus, isFalse);
    // 주소 포커스 때 예약된 1초 뒤 확인 타이머를 끝낸다.
    await tester.pump(const Duration(milliseconds: 1500));
  });
}
