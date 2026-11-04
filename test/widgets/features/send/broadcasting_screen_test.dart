import 'package:coconut_wallet/utils/text_utils.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:lottie/lottie.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/send/broadcasting_screen.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_tween_button.dart';
import 'package:coconut_wallet/widgets/features/send/tag_inheritance_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

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
  @override
  String get host => 'node.example';
  int broadcasts = 0;
  final pending = Completer<Result<String>>();
  bool connected = true;
  int readinessRequests = 0;
  // Created on request so it completes inside the test's fake-async zone.
  Completer<Result<bool>>? readiness;
  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async =>
      connected ? Result.success(BlockTimestamp(100, DateTime(2026))) : Result.failure(ErrorCodes.nodeConnectionError);
  @override
  Future<Result<bool>> ensureConnectedForBroadcast() {
    readinessRequests++;
    return (readiness = Completer<Result<bool>>()).future;
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

class _PendingDraftRepository extends Fake implements TransactionDraftRepository {
  final completion = Completer<Result<void>>();
  @override
  Future<Result<void>> deleteOne(int draftId) => completion.future;
}

void main() {
  late TestRealmManager manager;
  late UtxoRepository repository;
  late _Node node;
  late String target;
  late String transactionHash;
  final navigated = <String?>[];
  final navigatorKey = GlobalKey<NavigatorState>();
  _PendingDraftRepository? pendingDraft;

  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.testnet);
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });
  setUp(() {
    manager = TestRealmManager();
    repository = UtxoRepository(manager);
    node = _Node();
    addTearDown(node.dispose);
    navigated.clear();
    pendingDraft = null;
  });
  tearDown(() => manager.dispose());

  List<String> tagIds(String utxoId) => repository.getUtxoTagsByTxHash(1, utxoId).value.map((tag) => tag.id).toList();

  Future<void> open(WidgetTester tester, {int count = 2, bool slowCleanup = false, bool pushed = false}) async {
    // Asset I/O must finish outside the fake clock before the send animation can start.
    await tester.runAsync(() => AssetLottie(TransactionLottiePath.checkSpinning).load());
    final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    final tx = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment(_hash, 0, sequence: 0xfffffffd)],
      [
        TransactionOutput.forPayment(
          999000,
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
    final signed = Psbt.parse(vault.addSignatureToPsbt(psbt.serialize())).getSignedTransaction(AddressType.p2wpkh);
    transactionHash = signed.transactionHash;
    target = getUtxoId(transactionHash, 0);
    final send =
        SendInfoProvider()
          ..setWalletId(1)
          ..setTxWaitingForSign(psbt.serialize())
          ..setSignedResult(signed.serialize());
    if (slowCleanup) {
      send.setUnsignedDraftId(123);
      pendingDraft = _PendingDraftRepository();
    }
    manager.realm.write(() {
      for (var i = 0; i < count; i++) {
        manager.realm.add(RealmUtxoTag('tag-$i', 1, 'tag-$i', i, DateTime(2026), utxoIdList: [_source]));
      }
    });
    final tags = UtxoTagProvider(repository);
    addTearDown(tags.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SendInfoProvider>.value(value: send),
          ChangeNotifierProvider<WalletProvider>(
            create:
                (_) => _Wallets(
                  SinglesigWalletItem(id: 1, name: 'QA', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor),
                ),
          ),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          ChangeNotifierProvider<NodeProvider>.value(value: node),
          ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
          ChangeNotifierProvider<UtxoTagProvider>.value(value: tags),
          Provider<UtxoRepository>.value(value: repository),
          Provider<TransactionDraftRepository>.value(value: pendingDraft ?? TransactionDraftRepository(manager)),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          navigatorKey: navigatorKey,
          navigatorObservers: [_NavigationObserver(navigated)],
          home: pushed ? const SizedBox() : const LoaderOverlay(child: BroadcastingScreen()),
          onGenerateRoute: (settings) {
            return MaterialPageRoute<void>(settings: settings, builder: (_) => const SizedBox());
          },
        ),
      ),
    );
    if (pushed) {
      // Opened from another screen so a back gesture has somewhere to return to.
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const LoaderOverlay(child: BroadcastingScreen())),
      );
      await tester.pump();
      navigated.clear();
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(find.text(t.broadcasting_screen.btn_submit));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> finish(WidgetTester tester, {bool success = true}) async {
    // Keep the two-second bound while advancing sequential animation timers.
    for (var frame = 0; frame < 20 && node.broadcasts == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(node.broadcasts, 1);
    node.pending.complete(success ? Result.success(transactionHash) : Result.failure(ErrorCodes.broadcastError));
    bool completed() =>
        navigated.isNotEmpty ||
        find
            .text(TextUtils.preventLineBreakInsideWords(t.broadcasting_screen.dialog.tag_apply_failed))
            .evaluate()
            .isNotEmpty ||
        find.text(TextUtils.preventLineBreakInsideWords(t.broadcasting_screen.error_popup_title)).evaluate().isNotEmpty;
    // Native Realm commits need real async time as well as Flutter's fake-clock frames.
    for (var attempt = 0; !completed() && attempt < 200; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(completed(), isTrue, reason: 'Broadcast did not reach completion or a result dialog');
  }

  testWidgets('slow connection displays inline notice and hides it once ready', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, count: 0);
    node.connected = false;
    await tapSend(tester);
    for (var frame = 0; frame < 30 && node.readinessRequests == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(find.byKey(const ValueKey('connection-delay-notice')), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text(t.broadcasting_screen.connection_delay_message), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    expect(find.byType(Dialog), findsNothing);
    expect(node.readinessRequests, 1);
    expect(node.broadcasts, 0);
    node.readiness!.complete(Result.success(true));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('connection-delay-notice')), findsNothing);
    await finish(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('going back while waiting for the connection cancels the send', (tester) async {
    await open(tester, count: 0, pushed: true);
    node.connected = false;
    await tapSend(tester);
    for (var frame = 0; frame < 30 && node.readinessRequests == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(node.readinessRequests, 1);
    await tester.binding.handlePopRoute();
    // Let the route exit transition finish.
    for (var frame = 0; frame < 30 && find.byType(BroadcastingScreen).evaluate().isNotEmpty; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(BroadcastingScreen), findsNothing);
    node.readiness!.complete(Result.success(true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(node.broadcasts, 0, reason: 'a send the user left must never reach the node');
    expect(tester.takeException(), isNull);
  });

  testWidgets('going back after the broadcast request is sent keeps the screen until the result', (tester) async {
    await open(tester, count: 0, pushed: true);
    await tapSend(tester);
    for (var frame = 0; frame < 30 && node.broadcasts == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(node.broadcasts, 1);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BroadcastingScreen), findsOneWidget, reason: 'the sent request cannot be cancelled');
    await finish(tester);
    expect(navigated, [AppRouteNames.broadcastingComplete]);
  });

  testWidgets('cancel consent preserves tags and allows opening consent again without broadcasting', (tester) async {
    await open(tester);
    await tapSend(tester);
    expect(find.byType(TagInheritanceDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(node.broadcasts, 0);
    expect(tagIds(_source), ['tag-0', 'tag-1']);
    expect(tagIds(target), isEmpty);
    await tapSend(tester);
    expect(find.byType(TagInheritanceDialog), findsOneWidget);
    expect(node.broadcasts, 0);
  });

  testWidgets('two rapid send callbacks create one consent and one pending network broadcast', (tester) async {
    await open(tester);
    // Dispatch both actual button callbacks before modal hit-testing can hide the second.
    final button = tester.widget<FixedBottomTweenButton>(find.byType(FixedBottomTweenButton));
    button.rightButtonClicked();
    button.rightButtonClicked();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TagInheritanceDialog), findsOneWidget);
    await tester.tap(find.text(t.alert.tag_apply.btn_apply));
    await finish(tester, success: false);
    expect(node.broadcasts, 1);
    expect(tagIds(_source), ['tag-0', 'tag-1']);
    expect(tagIds(target), isEmpty);
    expect(navigated, isEmpty);
    expect(find.text(TextUtils.preventLineBreakInsideWords(t.broadcasting_screen.error_popup_title)), findsOneWidget);
  });

  testWidgets('explicit decline sends once and clears consumed links without inheriting', (tester) async {
    await open(tester);
    await tapSend(tester);
    await tester.tap(find.text(t.alert.tag_apply.btn_without_tags));
    await finish(tester);
    expect(tagIds(_source), isEmpty);
    expect(tagIds(target), isEmpty);
    expect(repository.getUtxoTags(1).value, hasLength(2));
    expect(navigated, [AppRouteNames.broadcastingComplete]);
  });

  testWidgets('six candidates persist only the selected subset after real screen consent', (tester) async {
    await open(tester, count: 6);
    await tapSend(tester);
    await tester.tap(find.byKey(const ValueKey('tag-1')));
    await tester.tap(find.byKey(const ValueKey('tag-4')));
    await tester.pump();
    await tester.tap(find.text(t.alert.tag_apply.btn_apply));
    await finish(tester);
    expect(tagIds(_source), isEmpty);
    expect(tagIds(target), ['tag-1', 'tag-4']);
    expect(navigated, [AppRouteNames.broadcastingComplete]);
  });

  testWidgets('pending draft cleanup cannot block the sent screen', (tester) async {
    await open(tester, count: 0, slowCleanup: true);
    await tapSend(tester);
    await finish(tester);
    expect(navigated, [AppRouteNames.broadcastingComplete]);
    expect(node.broadcasts, 1);
    pendingDraft!.completion.completeError(StateError('late cleanup failure'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepted send with tag storage failure warns then completes without resending', (tester) async {
    await open(tester);
    await tapSend(tester);
    await tester.tap(find.text(t.alert.tag_apply.btn_apply));
    expect(repository.deleteUtxoTag('tag-0').isSuccess, isTrue);

    await finish(tester);

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(TextUtils.preventLineBreakInsideWords(t.broadcasting_complete_screen.complete)),
      ),
      findsOneWidget,
    );
    expect(
      find.text(TextUtils.preventLineBreakInsideWords(t.broadcasting_screen.dialog.tag_apply_failed)),
      findsOneWidget,
    );
    expect(find.text(TextUtils.preventLineBreakInsideWords(t.broadcasting_screen.error_popup_title)), findsNothing);
    expect(navigated, isEmpty);
    expect(tagIds(_source), ['tag-1']);
    expect(tagIds(target), isEmpty);
    await tester.tap(find.text(t.OK));
    await tester.pumpAndSettle();
    expect(navigated, [AppRouteNames.broadcastingComplete]);
    expect(node.broadcasts, 1);
  });
}
