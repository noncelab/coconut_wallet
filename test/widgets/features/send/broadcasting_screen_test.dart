import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
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
  int broadcasts = 0;
  final pending = Completer<Result<String>>();
  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async => Result.success(BlockTimestamp(100, DateTime(2026)));
  @override
  Future<Result<String>> broadcast(Transaction transaction) {
    broadcasts++;
    return pending.future;
  }
}

void main() {
  late TestRealmManager manager;
  late UtxoRepository repository;
  late _Node node;
  late String target;
  late String transactionHash;
  final navigated = <String?>[];

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
  });
  tearDown(() => manager.dispose());

  List<String> tagIds(String utxoId) => repository.getUtxoTagsByTxHash(1, utxoId).value.map((tag) => tag.id).toList();

  Future<void> open(WidgetTester tester, {int count = 2}) async {
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
          Provider<TransactionDraftRepository>.value(value: TransactionDraftRepository(manager)),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const LoaderOverlay(child: BroadcastingScreen()),
          onGenerateRoute: (settings) {
            navigated.add(settings.name);
            return MaterialPageRoute<void>(settings: settings, builder: (_) => const SizedBox());
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(find.text(t.broadcasting_screen.btn_submit));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> finish(WidgetTester tester, {bool success = true}) async {
    await tester.pump(const Duration(seconds: 2));
    expect(node.broadcasts, 1);
    node.pending.complete(success ? Result.success(transactionHash) : Result.failure(ErrorCodes.broadcastError));
    bool completed() =>
        navigated.isNotEmpty ||
        find.text(t.broadcasting_screen.dialog.tag_apply_failed).evaluate().isNotEmpty ||
        find.text(t.broadcasting_screen.error_popup_title).evaluate().isNotEmpty;
    // Native Realm commits need real async time as well as Flutter's fake-clock frames.
    for (var attempt = 0; !completed() && attempt < 100; attempt++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(completed(), isTrue, reason: 'Broadcast did not reach completion or a result dialog');
  }

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
    expect(find.text(t.broadcasting_screen.error_popup_title), findsOneWidget);
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

  testWidgets('accepted send with tag storage failure warns then completes without resending', (tester) async {
    await open(tester);
    await tapSend(tester);
    await tester.tap(find.text(t.alert.tag_apply.btn_apply));
    expect(repository.deleteUtxoTag('tag-0').isSuccess, isTrue);

    await finish(tester);

    expect(find.text(t.broadcasting_complete_screen.complete), findsOneWidget);
    expect(find.text(t.broadcasting_screen.dialog.tag_apply_failed), findsOneWidget);
    expect(find.text(t.broadcasting_screen.error_popup_title), findsNothing);
    expect(navigated, isEmpty);
    expect(tagIds(_source), ['tag-1']);
    expect(tagIds(target), isEmpty);
    await tester.tap(find.text(t.OK));
    await tester.pumpAndSettle();
    expect(navigated, [AppRouteNames.broadcastingComplete]);
    expect(node.broadcasts, 1);
  });
}
