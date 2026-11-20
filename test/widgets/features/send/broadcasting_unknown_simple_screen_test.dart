import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/send/broadcasting_screen.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../../mock/utxo_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';

const _hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
final _source = getUtxoId(_hash, 0);

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final WalletItemBase wallet;
  _Wallets(this.wallet);
  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  bool containsAddress(int id, String address, {bool? isChange}) => false;
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
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

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {}

class _Node extends Fake with ChangeNotifier implements NodeProvider {
  int broadcasts = 0;
  int lookups = 0;
  int reconnects = 0;
  final pending = Completer<Result<String>>();
  bool connected = true;
  Completer<bool>? reconnecting;
  @override
  String get host => 'localhost';
  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async =>
      connected ? Result.success(BlockTimestamp(100, DateTime(2026))) : Result.failure(ErrorCodes.nodeConnectionError);
  @override
  Future<bool> reconnectWithoutWaitingForSync() {
    reconnects++;
    return reconnecting?.future ?? Future.value(true);
  }

  Completer<Result<String>>? lookup;
  @override
  Future<Result<String>> getTransaction(String txHash) {
    lookups++;
    return lookup?.future ?? Future.value(Result.failure(ErrorCodes.nodeUnknown));
  }

  @override
  Future<Result<String>> broadcast(Transaction transaction) {
    broadcasts++;
    return pending.future;
  }
}

class _NavigationObserver extends NavigatorObserver {
  final List<String?> navigated;
  _NavigationObserver(this.navigated);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && route is PageRoute) navigated.add(route.settings.name);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestRealmManager manager;
  late UtxoRepository repository;
  late TransactionDraftRepository drafts;
  late _Node node;
  late SingleSignatureVault vault;
  late WalletItemBase wallet;
  late SendInfoProvider send;
  late Transaction signed;
  late String recipient;
  late int unsignedId;
  final navigated = <String?>[];
  final navigator = GlobalKey<NavigatorState>();

  setUpAll(() async {
    NetworkType.setNetworkType(NetworkType.testnet);
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await AssetLottie(TransactionLottiePath.checkSpinning).load();
  });
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    manager = TestRealmManager();
    repository = UtxoRepository(manager);
    drafts = TransactionDraftRepository(manager);
    navigated.clear();
    vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    recipient = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 1))).getAddress(0);
    wallet = SinglesigWalletItem(
      id: 1,
      name: 'Synthetic QA',
      colorIndex: 0,
      iconIndex: 0,
      descriptor: vault.descriptor,
    );
    final tx = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment(_hash, 0)],
      [
        TransactionOutput.forPayment(400000, recipient),
        TransactionOutput.forPayment(
          599000,
          vault.getAddress(1, isChange: true),
          derivationPath: '${vault.derivationPath}/1/1',
          isChangeOutput: true,
        ),
      ],
      AddressType.p2wpkh,
    );
    tx.utxoList.add(Utxo(_hash, 0, 1000000, '${vault.derivationPath}/0/0'));
    tx.changeAddressDerivationPath = '${vault.derivationPath}/1/1';
    final psbt = Psbt.fromTransaction(tx, vault);
    signed = Psbt.parse(vault.addSignatureToPsbt(psbt.serialize())).getSignedTransaction(AddressType.p2wpkh);
    send =
        SendInfoProvider()
          ..setWalletId(1)
          ..setTransaction(tx)
          ..setTxWaitingForSign(psbt.serialize())
          ..setSignedResult(signed.serialize())
          ..setFeeRate(1)
          ..setIsMaxMode(false);
    manager.realm.write(() {
      manager.realm.add(
        UtxoMock.createUnspentRealmUtxo(walletId: 1, address: vault.getAddress(0), transactionHash: _hash)
          ..derivationPath = '${vault.derivationPath}/0/0',
      );
    });
    final saved = await drafts.saveUnsignedDraft(
      walletId: 1,
      feeRate: 1,
      isMaxMode: false,
      isFeeSubtractedFromSendAmount: false,
      recipients: [RecipientDraft(address: recipient, amount: 400000)],
      bitcoinUnit: BitcoinUnit.sats,
      selectedUtxoIds: [_source],
    );
    expect(saved.isSuccess, isTrue);
    unsignedId = saved.value.id;
    send.setUnsignedDraftId(unsignedId);
  });
  tearDown(() {
    node.dispose();
    manager.dispose();
  });

  Future<BroadcastingViewModel> open(WidgetTester tester, int? signedDraftId) async {
    final tags = UtxoTagProvider(repository);
    addTearDown(tags.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SendInfoProvider>.value(value: send),
          ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets(wallet)),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          ChangeNotifierProvider<NodeProvider>.value(value: node),
          ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
          ChangeNotifierProvider<UtxoTagProvider>.value(value: tags),
          Provider<UtxoRepository>.value(value: repository),
          Provider<TransactionDraftRepository>.value(value: drafts),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          navigatorKey: navigator,
          navigatorObservers: [_NavigationObserver(navigated)],
          home: const Scaffold(body: Text('previous-route')),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRouteNames.broadcasting),
        builder: (_) => LoaderOverlay(child: BroadcastingScreen(signedTransactionDraftId: signedDraftId)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    final vm = tester.element(find.byType(Consumer<BroadcastingViewModel>)).read<BroadcastingViewModel>();
    expect(vm.isInitDone, isTrue);
    return vm;
  }

  List<UtxoState> expectInputReserved() {
    final input = repository.getUtxoState(1, _source)!;
    expect(input.status, UtxoStatus.outgoing);
    expect(input.spentByTransactionHash, signed.transactionHash);
    final (valid, excluded) = repository.getValidatedSelectedUtxoList(1, [_source]);
    expect(valid, isEmpty);
    expect(excluded, SelectedUtxoExcludedStatus.used);
    return valid;
  }

  for (final fromSignedDraft in [false, true]) {
    testWidgets('C6 back preserves outgoing input/drafts and late success finalizes after dispose '
        '(signed draft entry=$fromSignedDraft)', (tester) async {
      node = _Node();
      int? signedId;
      if (fromSignedDraft) {
        final saved = await tester.runAsync(
          () => drafts.saveSignedDraft(
            walletId: 1,
            recipients: [RecipientDraft(address: recipient, amount: 400000)],
            feeRate: 1,
            isMaxMode: false,
            txWaitingForSign: send.txWaitingForSign!,
            signedPsbtBase64Encoded: send.signedResult!,
          ),
        );
        expect(saved!.isSuccess, isTrue);
        signedId = saved.value.id;
      }
      final vm = await open(tester, signedId);
      var notifications = 0;
      vm.addListener(() => notifications++);
      if (!fromSignedDraft) {
        final saved = await tester.runAsync(vm.saveTransactionDraft);
        expect(saved!.isSuccess, isTrue);
        signedId = saved.value.id;
      }
      expect(manager.realm.all<RealmTransactionDraft>().length, 2);
      expect(vm.signedTx!.inputs.single.sequence, 0xffffffff);
      node.lookup = Completer<Result<String>>();
      await tester.tap(find.text(t.broadcasting_screen.btn_submit));
      for (var frame = 0; node.broadcasts == 0 && frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(node.broadcasts, 1);
      expect(vm.isBroadcastDispatched, isTrue);
      await tester.pump();
      // A real back event must be blocked while the initial response is pending.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(BroadcastingScreen), findsOneWidget);

      // 14 seconds reconnecting leaves < 3 seconds for a late lookup: consistent
      // with the production clearnet RPC's separate 3-second response bound.
      node.connected = false;
      node.reconnecting = Completer<bool>();
      node.pending.complete(Result.failure(ErrorCodes.nodeIsolateError));
      await tester.pump();
      expect(ErrorCodes.nodeIsolateError.code, '1301');
      expect(node.reconnects, 1);
      await tester.pump(const Duration(seconds: 14));
      node.reconnecting!.complete(true);
      await tester.pump();
      expect(node.lookups, 1);
      final lookupStarted = tester.binding.clock.now();
      await tester.pump(const Duration(seconds: 1));
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      expect(
        find.text(TextUtils.preventLineBreakInsideWords(t.broadcasting_screen.dialog.result_unknown_title)),
        findsOneWidget,
      );
      expect(
        find.text(TextUtils.preventLineBreakInsideWords(t.broadcasting_screen.dialog.result_unknown)),
        findsOneWidget,
      );
      expect(vm.isBroadcastResultUnknown, isTrue);
      expect(vm.isBroadcastDispatched, isFalse);
      expect(vm.isTransactionAccepted, isFalse);
      expectInputReserved();
      expect(drafts.getUnsignedTransactionDraft(unsignedId), isNotNull);
      final remainingSigned = await tester.runAsync(() => drafts.getSignedDraft(signedId!));
      expect(remainingSigned!.value.signedPsbtBase64Encoded, signed.serialize());

      await tester.tap(find.text(t.OK));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BroadcastingScreen), findsNothing);
      expect(find.text('previous-route'), findsOneWidget);
      final notificationsAfterBack = notifications;
      expect(manager.realm.all<RealmTransactionDraft>().length, 2);
      expect(send.walletId, fromSignedDraft ? isNull : 1);
      final validAfterBack = expectInputReserved();

      // The actual app builder has no valid input after leaving the screen.
      final rebuilt =
          TransactionBuilder(
            availableUtxos: validAfterBack,
            recipients: {recipient: 400000},
            feeRate: 12,
            changeDerivationPath: '${vault.derivationPath}/1/2',
            walletItemBase: wallet,
            isFeeSubtractedFromAmount: false,
            isUtxoFixed: true,
          ).build();
      expect(rebuilt.isFailure, isTrue);

      // Complete only after the route has fully gone, but within the 3-second RPC bound.
      expect(tester.binding.clock.now().difference(lookupStarted), lessThan(const Duration(seconds: 3)));
      node.lookup!.complete(Result.success(signed.serialize()));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        if (repository.getUtxoState(1, _source)!.status == UtxoStatus.outgoing &&
            manager.realm.find<RealmTransactionDraft>(signedId!) == null) {
          break;
        }
      }
      expect(vm.isTransactionAccepted, isTrue);
      expect(notifications, notificationsAfterBack, reason: 'A late success must not notify a disposed screen');
      expectInputReserved();
      expect(manager.realm.find<RealmTransactionDraft>(signedId!), isNull);
      final signedKeys = await tester.runAsync(() => const FlutterSecureStorage().readAll());
      expect(signedKeys, isEmpty);
      expect(manager.realm.find<RealmTransactionDraft>(unsignedId), fromSignedDraft ? isNotNull : isNull);
      expect(navigated, isNot(contains(AppRouteNames.broadcastingComplete)));
      expect(find.text('previous-route'), findsOneWidget);
      expect(node.broadcasts, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
