import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/unverified_transaction/unverified_transaction_listener.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/node_provider/transaction/pending_sync_harness.dart';
import '../repository/realm/test_realm_manager.dart';

class _Node extends Fake with ChangeNotifier implements NodeProvider {
  final dropped = StreamController<List<String>>.broadcast();
  @override
  Stream<List<String>> get unverifiedPendingTransactionStream => dropped.stream;
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  String get language => 'kr';
}

/// 동기화가 메인으로 보내는 "넣지 않은 거래" 알림만 모은다
class _Recording implements StateManagerInterface {
  final reported = <List<String>>[];
  @override
  void addUnverifiedPendingTransactions(int walletId, List<String> txHashes) => reported.add(txHashes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 한국어 문구에는 줄바꿈용 단어 결합자(U+2060)가 들어가므로 빼고 비교한다
Finder _text(String text) => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.data ?? widget.textSpan?.toPlainText() ?? '').replaceAll('\u2060', '') == text,
);

Uint8List _doubleHash(String hex) => Codec.decodeHex(Hash.sha256fromHex(Hash.sha256fromHex(hex)));

/// 레거시 SIGHASH_ALL 서명 해시(증인 없음, 다른 입력의 scriptSig는 비움)
Uint8List _legacyDigest(Transaction tx, int index, TransactionOutput prevout) {
  final forSig = Transaction(
    Codec.decodeHex(tx.version),
    [
      for (final input in tx.inputs)
        TransactionInput.forPayment(input.transactionHash, input.index, sequence: input.sequence),
    ],
    tx.outputs,
    Codec.decodeHex(tx.lockTime),
    false,
  );
  forSig.inputs[index].scriptSig = ScriptSignature.parse(prevout.scriptPubKey.serialize());
  return _doubleHash('${forSig.serialize()}01000000');
}

/// 첫 입력(내 Taproot 스크립트 경로)의 BIP341 서명 해시. 모든 입력의 이전 출력이 들어간다
Uint8List _scriptDigest(Transaction tx, List<TransactionOutput> prevouts) {
  final witness = tx.inputs.first.witnessList;
  final script = Codec.decodeHex(witness[witness.length - 2]);
  final leaf = Hash.taggedHash(
    'TapLeaf',
    Uint8List.fromList([
      Codec.decodeHex(witness.last).first & 0xfe,
      ...Codec.encodeVariableInteger(script.length),
      ...script,
    ]),
  );
  return Codec.decodeHex(tx.getTaprootSigHash(0, prevouts, isTapscript: true, tapleafHash: leaf, keyVersion: 0));
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  group('UnverifiedTransactionListener', () {
    late _Node node;

    Future<void> pump(WidgetTester tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NodeProvider>.value(value: node),
            ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => UnverifiedTransactionListener(navigatorKey: navigatorKey, child: child!),
            routes: {AppRouteNames.electrumServer: (_) => const Scaffold(body: Text('electrum server settings'))},
            home: const Scaffold(body: Text('home')),
          ),
        ),
      );
    }

    Future<void> drop(WidgetTester tester, List<String> txHashes) async {
      node.dropped.add(txHashes);
      await tester.pumpAndSettle();
    }

    setUp(() async {
      node = _Node();
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsRepository().init();
    });

    testWidgets('넣지 않은 거래마다 한 번만 띄운다', (tester) async {
      await pump(tester);

      await drop(tester, ['aa' * 32]);
      expect(_text(t.unverified_transaction_dialog.title), findsOneWidget);
      expect(_text(t.unverified_transaction_dialog.description), findsOneWidget);
      await tester.tap(_text(t.close));
      await tester.pumpAndSettle();

      await drop(tester, ['aa' * 32]);
      expect(_text(t.unverified_transaction_dialog.title), findsNothing);

      await drop(tester, ['aa' * 32, 'bb' * 32]);
      expect(_text(t.unverified_transaction_dialog.title), findsOneWidget);
    });

    testWidgets('앱을 다시 켜도 이미 알린 거래는 다시 띄우지 않는다', (tester) async {
      await pump(tester);
      await drop(tester, ['aa' * 32]);
      await tester.tap(_text(t.close));
      await tester.pumpAndSettle();
      expect(SharedPrefsRepository().getShownUnverifiedTransactionIds(), ['aa' * 32]);

      await tester.pumpWidget(const SizedBox());
      node = _Node();
      await pump(tester);
      await drop(tester, ['aa' * 32]);

      expect(_text(t.unverified_transaction_dialog.title), findsNothing);
    });

    testWidgets('서버 바꾸기는 일렉트럼 서버 설정을 연다', (tester) async {
      await pump(tester);
      await drop(tester, ['aa' * 32]);

      await tester.tap(_text(t.unverified_transaction_dialog.change_server));
      await tester.pumpAndSettle();

      expect(find.text('electrum server settings'), findsOneWidget);
      expect(_text(t.unverified_transaction_dialog.title), findsNothing);
    });
  });

  group('동기화가 알리는 거래', () {
    NetworkType.setNetworkType(NetworkType.regtest);
    final signer = walletSigners(0x10).first;
    final shop = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 0x77))).getAddress(0);
    late TestRealmManager realm;

    setUp(() => realm = TestRealmManager());
    tearDown(() => realm.dispose());

    /// 받기 주소 0의 기록으로 [historyList]를 보여 주는 동기화를 돌리고, 메인으로 알린 거래 번호를 돌려준다
    Future<List<List<String>>> reportedBy(
      SyncedWallet wallet,
      WalletSigner signer,
      List<GetTxHistoryRes> historyList,
    ) async {
      final recording = _Recording();
      wallet.server.historyByAddress[wallet.address(0)] = historyList;
      await TransactionSyncService(
        wallet.server,
        wallet.txs,
        TransactionRecordService(wallet.server, wallet.addresses),
        recording,
        wallet.utxos,
        ScriptCallbackService(),
      ).fetchScriptTransaction(
        signer.item,
        ScriptStatus(
          scriptPubKey: wallet.address(0),
          status: 'pending',
          timestamp: DateTime.now(),
          derivationPath: signer.path(0),
          address: wallet.address(0),
          index: 0,
          isChange: false,
        ),
        now: DateTime(2026, 11, 11),
      );
      return recording.reported;
    }

    Future<List<List<String>>> syncShown(Transaction Function(Transaction own) serve) async {
      final wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
      final funded = signer.funded([100000], 1);
      final shown = serve(signer.pay(funded.coins, {shop: 30000}));
      wallet.publish([funded.funding, shown]);
      await wallet.sync([history(funded.funding, 100)], unspentList: wallet.unspent(funded.funding, 100));
      return reportedBy(wallet, signer, [history(funded.funding, 100), history(shown, 0)]);
    }

    test('정직한 서버의 내 결제는 알리지 않는다', () async {
      expect(await syncShown((own) => own), isEmpty);
    });

    test('서명이 맞지 않는 내 코인 지출은 그 거래 번호만 알린다', () async {
      late Transaction fake;
      final reported = await syncShown((own) => fake = withGarbageSignatures(own, shop, AddressType.p2wpkh));

      expect(reported, [
        [fake.transactionHash],
      ]);
    });

    // Codex 리뷰 F1 재현: 내 상속 스크립트 경로 입력 + 남의 입력(실제 서명)이 섞인 정직한 거래
    for (final legacy in [false, true]) {
      test('정직한 섞인 거래(내 Taproot 스크립트 경로 + 남의 ${legacy ? 'P2PKH' : 'P2WPKH'})는 넣고 알리지 않는다', () async {
        final scriptPath = walletSigners(0x10).last;
        final wallet = SyncedWallet(realm, scriptPath.item, purpose: scriptPath.purpose, addressCount: 3);
        final known = scriptPath.funded([100000], 1);
        final foreign = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 0x55)));
        final foreignKey = foreign.keyStore.hdWallet.derive(0).derive(0);
        final foreignAddress =
            legacy ? AddressType.getP2pkhAddress(Codec.encodeHex(foreignKey.publicKey)) : foreign.getAddress(0);
        final parent = fundingTransaction([(foreignAddress, 50000)], 2);
        final tx = scriptPath.pay(known.coins, {shop: 30000});
        tx.inputs.add(TransactionInput.forPayment(parent.transactionHash, 0, sequence: 0xfffffffd));
        tx.outputs.add(TransactionOutput.forPayment(48000, foreignAddress));
        final prevouts = [known.funding.outputs.first, parent.outputs.first];
        final beneficiary = KeyStore.fromSeed(
          Seed.fromEntropy(Uint8List.fromList(List.filled(16, 0x16))),
          AddressType.p2tr,
        );
        final ownHash = _scriptDigest(tx, prevouts);
        tx.inputs.first.witnessList[0] = Codec.encodeHex(
          Ecc.signSchnorr(ownHash, beneficiary.hdWallet.derive(0).derive(0).privateKey!),
        );
        expect(tx.inputs.first.verifySpend(ownHash, prevouts.first), isTrue);
        if (legacy) {
          final rawSignature = Ecc.signEcdsa(_legacyDigest(tx, 1, prevouts[1]), foreignKey.privateKey!);
          tx.inputs[1].scriptSig = ScriptSignature.p2pkh(
            Converter.rawToDerSignature(rawSignature),
            foreignKey.publicKey,
          );
          expect(
            Ecc.verifyEcdsa(
              _legacyDigest(tx, 1, prevouts[1]),
              foreignKey.publicKey,
              Converter.derToRawSignature(Uint8List.fromList(tx.inputs[1].scriptSig.commands[0])),
            ),
            isTrue,
          );
        } else {
          signP2wpkhInput(tx, 1, prevouts[1], foreignKey);
          expect(tx.validateSpend(prevouts), isTrue);
        }
        expect(tx.inputs.first.verifySpend(_scriptDigest(tx, prevouts), prevouts.first), isTrue);
        wallet.publish([known.funding, parent, tx]);
        await wallet.sync([history(known.funding, 100)], unspentList: wallet.unspent(known.funding, 100));

        final reported = await reportedBy(wallet, scriptPath, [history(tx, 0)]);

        expect(reported, isEmpty, reason: '서명이 모두 맞는 정직한 거래로 서버를 의심하면 안 된다');
        expect(wallet.txs.getTransactionRecord(walletId, tx.transactionHash), isNotNull);
      });
    }

    test('남의 이전 거래를 받지 못해 확인을 미룬 거래(unavailable)는 넣지 않고 알리지도 않는다', () async {
      final taproot = walletSigners(0x10).firstWhere((s) => s.name == 'p2tr 키 경로');
      final wallet = SyncedWallet(realm, taproot.item, purpose: taproot.purpose);
      final known = taproot.funded([60000], 1);
      // 같은 지갑의 코인이지만 이 기기가 아직 모르고, 서버도 그 이전 거래를 주지 않는다
      final unseen = taproot.funded([50000], 2, indexes: [1]);
      final tx = taproot.pay([...known.coins, ...unseen.coins], {shop: 100000});
      wallet.publish([known.funding, tx]);
      await wallet.sync([history(known.funding, 100)], unspentList: wallet.unspent(known.funding, 100));

      final reported = await reportedBy(wallet, taproot, [history(known.funding, 100), history(tx, 0)]);

      expect(wallet.txs.getTransactionRecord(walletId, tx.transactionHash), isNull);
      expect(reported, isEmpty);
    });

    test('내 Taproot 스크립트 경로 + 남의 레거시 입력이 섞인 거래는 내 서명이 맞으면 넣고 알리지 않는다', () async {
      final scriptPath = walletSigners(0x10).firstWhere((s) => s.name == 'p2tr 스크립트 경로');
      final wallet = SyncedWallet(realm, scriptPath.item, purpose: scriptPath.purpose);
      final known = scriptPath.funded([60000], 1);
      final coin = known.coins.single;
      final real = scriptPath.pay(known.coins, {shop: 30000});
      final legacyFunding = fundingTransaction([('mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn', 80000)], 4);
      final mixed = Transaction.withInputsAndOutputs(
        [
          TransactionInput.forPayment(legacyFunding.transactionHash, 0),
          TransactionInput.forPayment(coin.transactionHash, coin.index, sequence: real.inputs.single.sequence),
        ],
        [TransactionOutput.forPayment(130000, shop)],
        AddressType.p2tr,
        lockTime: Converter.littleEndianToInt(Codec.decodeHex(real.lockTime)),
      );
      signTaprootScriptPathInput(
        mixed,
        1,
        [legacyFunding.outputs.single, TransactionOutput.forPayment(coin.amount, coin.to)],
        taprootKeys(0x10).beneficiary.hdWallet.derive(0).derive(0),
        real.inputs.single.witnessList[1],
        real.inputs.single.witnessList[2],
      );
      wallet.publish([known.funding, legacyFunding, mixed]);
      await wallet.sync([history(known.funding, 100)], unspentList: wallet.unspent(known.funding, 100));

      final reported = await reportedBy(wallet, scriptPath, [history(known.funding, 100), history(mixed, 0)]);

      expect(wallet.txs.getTransactionRecord(walletId, mixed.transactionHash), isNotNull);
      expect(reported, isEmpty);
    });
  });
}
