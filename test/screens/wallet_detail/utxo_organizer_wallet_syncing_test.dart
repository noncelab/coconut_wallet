import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/enums/utxo_merge_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_merge/utxo_merge_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_split/utxo_split_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/send/utxo_selection_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_organizer_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_split_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/loading/wallet_syncing_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

import '../../mock/utxo_mock.dart';
import '../../mock/wallet_sync_node_provider_mock.dart';
import '../../repository/realm/test_realm_manager.dart';

const _captureDir = String.fromEnvironment('UTXO_ORGANIZER_SYNC_CAPTURE_DIR');
const _utxoCount = 12;

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  _Wallets(this.wallet, this.vault, this.utxos);
  final WalletItemBase wallet;
  final SingleSignatureVault vault;
  final UtxoRepository utxos;

  WalletAddress _address(int index, bool change) => WalletAddress(
    vault.getAddress(index, isChange: change),
    '${vault.derivationPath}/${change ? 1 : 0}/$index',
    index,
    change,
    false,
    0,
    0,
    0,
  );

  @override
  List<WalletItemBase> get walletItemList => [wallet];
  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  WalletAddress getReceiveAddress(int walletId) => _address(0, false);
  @override
  WalletAddress getChangeAddress(int walletId) => _address(1, true);
  @override
  List<UtxoState> getUtxoList(int walletId) => utxos.getUtxoStateList(walletId);
  @override
  List<UtxoState> getUtxoListByStatus(int walletId, UtxoStatus utxoStatus) => const [];
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '';
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
  @override
  String get language => 'ko';
  @override
  List<int> get walletOrder => const [1];
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
}

void main() {
  late TestRealmManager manager;
  late WalletSyncNodeProviderMock node;
  final boundaryKey = GlobalKey();
  final vault = SingleSignatureVault.fromEntropy(Uint8List(16));

  setUpAll(() async {
    NetworkType.setNetworkType(NetworkType.regtest);
    LocaleSettings.setLocaleSync(AppLocale.ko);
    if (_captureDir.isNotEmpty) {
      for (final family in ['Pretendard', 'SpaceGrotesk']) {
        final loader = FontLoader(family);
        // 테스트에는 한글 대체 폰트가 없어 숫자 글꼴 자리도 Pretendard로 그림 (캡처 전용)
        for (final weight in ['Regular', 'Bold']) {
          loader.addFont(
            Future.value(ByteData.sublistView(File('assets/fonts/Pretendard-$weight.ttf').readAsBytesSync())),
          );
        }
        await loader.load();
      }
    }
  });

  setUp(() {
    manager = TestRealmManager();
    node = WalletSyncNodeProviderMock();
    manager.realm.write(() {
      manager.realm.add(
        RealmWalletBase(
          1,
          0,
          0,
          vault.descriptor,
          'QA',
          WalletType.singleSignature.name,
          generatedReceiveIndex: 19,
          generatedChangeIndex: 19,
        ),
      );
      manager.realm.addAll<RealmWalletAddress>([
        for (final isChange in [false, true])
          for (var i = 0; i < 20; i++)
            RealmWalletAddress(
              getWalletAddressId(1, i, vault.getAddress(i, isChange: isChange)),
              1,
              vault.getAddress(i, isChange: isChange),
              i,
              isChange,
              '${vault.derivationPath}/${isChange ? 1 : 0}/$i',
              false,
              0,
              0,
              0,
            ),
      ]);
      manager.realm.add(
        UtxoMock.createUnspentRealmUtxo(
          walletId: 1,
          address: vault.getAddress(19),
          amount: 1000000,
          transactionHash: 'f' * 64,
          addressIndex: 19,
        ),
      );
      for (var i = 0; i < _utxoCount; i++) {
        manager.realm.add(
          UtxoMock.createUnspentRealmUtxo(
            walletId: 1,
            address: vault.getAddress(i),
            amount: 20000,
            transactionHash: i.toRadixString(16).padLeft(64, '0'),
            addressIndex: i,
          ),
        );
      }
    });
  });
  tearDown(() => manager.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openOrganizer(WidgetTester tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    addTearDown(tester.view.reset);
    final wallet = SinglesigWalletItem(id: 1, name: 'QA', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor);
    final utxos = UtxoRepository(manager);
    final wallets = _Wallets(wallet, vault, utxos);
    final tags = UtxoTagProvider(utxos);
    addTearDown(tags.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AnalyticsService>.value(value: AnalyticsService(null, false)),
          Provider<SendInfoProvider>.value(value: SendInfoProvider()),
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<UtxoTagProvider>.value(value: tags),
          ChangeNotifierProvider<NodeProvider>.value(value: node),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          Provider<UtxoRepository>.value(value: utxos),
          Provider<AddressRepository>.value(value: AddressRepository(manager)),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
            home: const LoaderOverlay(child: UtxoOrganizerScreen(id: 1)),
          ),
        ),
      ),
    );
    await settle(tester);
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

  UtxoMergeViewModel mergeViewModel(WidgetTester tester) =>
      tester.element(find.byType(Selector<UtxoMergeViewModel, UtxoMergeStep>)).read<UtxoMergeViewModel>();

  /// 소액 기준으로 합칠 준비를 마쳐 "적용" 버튼이 보이게 함
  Future<UtxoMergeViewModel> prepareMerge(WidgetTester tester, {Set<String>? editedSelection}) async {
    final viewModel = mergeViewModel(tester);
    viewModel
      ..confirmMergeMethodSelection(UtxoMergeMethod.smallAmounts)
      ..confirmAmountRangeSelection(range: UtxoAmountRange.below0001, customAmountText: null, isLessThan: true);
    if (editedSelection != null) viewModel.commitEditedSelectedUtxoIds(editedSelection);
    viewModel
      ..feeRateController.text = '1'
      ..setCurrentStep(UtxoMergeStep.selectReceiveAddress)
      ..runMergeTransactionPreparationNow();
    await settle(tester);
    return viewModel;
  }

  FixedBottomButton applyButton(WidgetTester tester) =>
      tester.widget<FixedBottomButton>(find.widgetWithText(FixedBottomButton, t.apply));

  testWidgets('합치기: 지갑이 업데이트 중이면 적용을 막고 업데이트 중을 보여 주며, 끝나면 다시 열어 준다', (tester) async {
    node.setSyncing(1, true);
    await openOrganizer(tester);
    final viewModel = await prepareMerge(tester);
    await settle(tester);
    await capture(tester, 'merge_syncing');

    expect(viewModel.mergeState, MergeState.ready);
    expect(find.byType(WalletSyncingLabel), findsOneWidget);
    expect(applyButton(tester).isActive, isFalse);

    node.setSyncing(1, false);
    await settle(tester);
    await capture(tester, 'merge_synced');

    expect(find.byType(WalletSyncingLabel), findsNothing);
    expect(applyButton(tester).isActive, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  for (final (label, spend) in <(String, void Function(RealmUtxo))>[
    ('spending', (utxo) => utxo.status = 'outgoing'),
    ('spent', (utxo) => manager.realm.delete(utxo)),
  ]) {
    testWidgets('합치기($label): 직접 고른 UTXO가 업데이트 중 사용되면 빼고 알린다', (tester) async {
      node.setSyncing(1, true);
      await openOrganizer(tester);
      final hashes = [for (var i = 0; i < 3; i++) i.toRadixString(16).padLeft(64, '0')];
      final ids = [for (final hash in hashes) getUtxoId(hash, 0)];
      final viewModel = await prepareMerge(tester, editedSelection: ids.toSet());

      manager.realm.write(() => spend(manager.realm.find<RealmUtxo>(getRealmUtxoId(1, hashes.first, 0))!));
      node.setSyncing(1, false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await capture(tester, 'merge_${label}_excluded');

      expect(find.text(t.send_screen.toast.draft_utxo_used), findsOneWidget);
      expect(viewModel.editedSelectedUtxoIds, ids.skip(1).toSet());
      await settle(tester);
      expect(viewModel.mergeState, MergeState.ready, reason: '남은 UTXO로 다시 만들어 적용 버튼이 돌아온다');
      expect(viewModel.preparedMergeTransactionBuildResult!.transaction!.inputs, hasLength(2));
      await capture(tester, 'merge_${label}_rebuilt');
      await settle(tester);
      await tester.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('합치기: 다른 지갑이 업데이트 중이어도 이 지갑은 막지 않는다', (tester) async {
    node
      ..setSyncing(1, false)
      ..setSyncing(2, true);
    await openOrganizer(tester);
    await prepareMerge(tester);

    expect(find.byType(WalletSyncingLabel), findsNothing);
    expect(applyButton(tester).isActive, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  UtxoSplitViewModel splitViewModel(WidgetTester tester) =>
      tester
          .element(find.descendant(of: find.byType(UtxoSplitScreen), matching: find.byType(Scaffold)))
          .read<UtxoSplitViewModel>();

  /// 큰 UTXO 하나를 두 개로 똑같이 나누도록 채워 "적용" 버튼이 보이게 함
  Future<UtxoSplitViewModel> prepareSplit(WidgetTester tester) async {
    await tester.tap(find.text(t.utxo_organizer_screen.split));
    await tester.pump();
    final viewModel = splitViewModel(tester);
    final utxo = UtxoRepository(manager).getUtxoStateList(1).firstWhere((utxo) => utxo.amount == 1000000);
    viewModel
      ..setSelectedUtxoList([utxo])
      ..setSplitMethod(SplitMethod.evenly)
      ..feeRateController.text = '1'
      ..splitCountController.text = '2';
    for (var i = 0; i < 30 && viewModel.splitResult == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle(tester);
    return viewModel;
  }

  testWidgets('나누기: 지갑이 업데이트 중이면 적용을 막고 업데이트 중을 보여 주며, 끝나면 다시 열어 준다', (tester) async {
    node.setSyncing(1, true);
    await openOrganizer(tester);
    final viewModel = await prepareSplit(tester);
    await capture(tester, 'split_syncing');

    expect(viewModel.splitResult?.isSuccess, isTrue);
    expect(find.byType(WalletSyncingLabel), findsOneWidget);
    expect(applyButton(tester).isActive, isFalse);

    node.setSyncing(1, false);
    await settle(tester);
    await capture(tester, 'split_synced');

    expect(find.byType(WalletSyncingLabel), findsNothing);
    expect(applyButton(tester).isActive, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  for (final (label, spend) in <(String, void Function(RealmUtxo))>[
    ('spending', (utxo) => utxo.status = 'outgoing'),
    ('spent', (utxo) => manager.realm.delete(utxo)),
  ]) {
    testWidgets('나누기($label): 고른 UTXO가 업데이트 중 사용되면 알린 뒤 첫 단계부터 다시 시작한다', (tester) async {
      node.setSyncing(1, true);
      await openOrganizer(tester);
      final viewModel = await prepareSplit(tester);

      manager.realm.write(() => spend(manager.realm.find<RealmUtxo>(getRealmUtxoId(1, 'f' * 64, 0))!));
      node.setSyncing(1, false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await capture(tester, 'split_${label}_toast');

      expect(find.text(t.send_screen.toast.draft_utxo_used), findsOneWidget);
      expect(viewModel.selectedUtxoList, hasLength(1), reason: '알림을 띄우고 화면이 사라질 때까지 선택을 비우지 않는다');

      await tester.pump(const Duration(milliseconds: 200));
      expect(viewModel.selectedUtxoList, isEmpty);
      expect(viewModel.selectedMethod, isNull);

      for (var i = 0; i < 17; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await capture(tester, 'split_${label}_restarted');

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(UtxoSelectionScreen), findsOneWidget, reason: '처음 들어왔을 때처럼 UTXO 선택 시트가 열린다');
      await capture(tester, 'split_${label}_sheet');
      await tester.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('나누기 선택이 있는 채로 합치기 탭을 보는 중에 업데이트가 끝나면, 합치기 화면에는 알리지 않고 나누기로 돌아올 때 처리한다', (tester) async {
    node.setSyncing(1, true);
    await openOrganizer(tester);
    final viewModel = await prepareSplit(tester);
    await tester.tap(find.text(t.utxo_organizer_screen.merge));
    await settle(tester);

    manager.realm.write(() => manager.realm.delete(manager.realm.find<RealmUtxo>(getRealmUtxoId(1, 'f' * 64, 0))!));
    node.setSyncing(1, false);
    await settle(tester);

    expect(find.text(t.send_screen.toast.draft_utxo_used), findsNothing);
    expect(viewModel.selectedUtxoList, hasLength(1), reason: '보이지 않는 나누기 선택을 지우지 않는다');

    await tester.tap(find.text(t.utxo_organizer_screen.split));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(t.send_screen.toast.draft_utxo_used), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(viewModel.selectedUtxoList, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('합치기 선택을 고친 채로 나누기 탭을 보는 중에 업데이트가 끝나면, 합치기로 돌아올 때 처리한다', (tester) async {
    node.setSyncing(1, true);
    await openOrganizer(tester);
    final hashes = [for (var i = 0; i < 3; i++) i.toRadixString(16).padLeft(64, '0')];
    final ids = [for (final hash in hashes) getUtxoId(hash, 0)];
    final viewModel = await prepareMerge(tester, editedSelection: ids.toSet());
    await tester.tap(find.text(t.utxo_organizer_screen.split));
    await tester.pump();
    final split = splitViewModel(tester);
    split
      ..setSelectedUtxoList([UtxoRepository(manager).getUtxoStateList(1).firstWhere((utxo) => utxo.amount == 1000000)])
      ..setSplitMethod(SplitMethod.evenly);
    await settle(tester);

    manager.realm.write(() => manager.realm.find<RealmUtxo>(getRealmUtxoId(1, hashes.first, 0))!.status = 'outgoing');
    node.setSyncing(1, false);
    await settle(tester);

    expect(find.text(t.send_screen.toast.draft_utxo_used), findsNothing);
    expect(viewModel.editedSelectedUtxoIds, ids.toSet(), reason: '보이지 않는 합치기 선택을 바꾸지 않는다');

    await tester.tap(find.text(t.utxo_organizer_screen.merge));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(t.send_screen.toast.draft_utxo_used), findsOneWidget);
    expect(viewModel.editedSelectedUtxoIds, ids.skip(1).toSet());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('다른 화면이 위에 있는 동안 업데이트가 끝나면 알리지 않고, 돌아왔을 때 처리한다', (tester) async {
    node.setSyncing(1, true);
    await openOrganizer(tester);
    final viewModel = await prepareSplit(tester);
    final navigator = Navigator.of(tester.element(find.byType(UtxoOrganizerScreen)));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('confirm'))));
    await settle(tester);

    manager.realm.write(() => manager.realm.delete(manager.realm.find<RealmUtxo>(getRealmUtxoId(1, 'f' * 64, 0))!));
    node.setSyncing(1, false);
    await settle(tester);

    expect(find.text(t.send_screen.toast.draft_utxo_used), findsNothing);
    expect(viewModel.selectedUtxoList, hasLength(1), reason: '가려진 화면의 선택을 지우지 않는다');

    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(t.send_screen.toast.draft_utxo_used), findsOneWidget);
    await settle(tester);
    expect(viewModel.selectedUtxoList, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
  });
}
