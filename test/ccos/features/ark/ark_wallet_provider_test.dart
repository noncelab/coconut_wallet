import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_backend.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_store.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ark_test_fakes.dart';

class _Secrets extends Fake implements HotWalletSecretRepository {
  final Map<String, Uint8List> stored = {};
  var _next = 0;

  @override
  String newSecretStorageKey() => 'hot_wallet_secret_${_next++}';

  @override
  Future<void> create({required String storageKey, required Uint8List mnemonic, required Uint8List passphrase}) async =>
      stored[storageKey] = Uint8List.fromList(mnemonic);

  @override
  Future<HotWalletPlaintext> unlockAfterAuthentication(String storageKey) async =>
      HotWalletPlaintext(mnemonic: Uint8List.fromList(stored[storageKey]!), passphrase: Uint8List(0));

  @override
  Future<void> delete(String storageKey) async => stored.remove(storageKey);

  @override
  Future<List<String>> getSecretStorageKeys() async => stored.keys.toList();
}

class _Backend with FakeArkVtxos implements ArkWalletBackend {
  List<ArkMovement> movements = [];
  String address = 'tark1fakeaddress';
  int sendFee = 0;
  Object? sendError;
  int syncCount = 0;
  final List<(ArkPaymentRail, String, int)> sent = [];
  final List<int> invoiceAmounts = [];

  @override
  Future<void> sync(String fingerprint) async => syncCount++;

  @override
  Future<List<ArkMovement>> history(String fingerprint) async => movements;

  int addressCalls = 0;

  @override
  Future<String> newArkAddress(String fingerprint) async {
    addressCalls++;
    return address;
  }

  @override
  Future<ArkLightningInvoice> createLightningInvoice(String fingerprint, int amountSats, {String? description}) async {
    invoiceAmounts.add(amountSats);
    return ArkLightningInvoice(
      invoice: 'lnbcrt${amountSats}n1fake',
      paymentHash: 'hash-$amountSats',
      amountSats: amountSats,
      feeSats: 0,
    );
  }

  @override
  Future<int> estimateSendFee(String fingerprint, ArkPaymentRail rail, int amountSats) async => sendFee;

  @override
  Future<int?> send(
    String fingerprint,
    ArkPaymentRail rail,
    String destination,
    int amountSats, {
    bool invoiceHasAmount = false,
  }) async {
    if (sendError != null) throw ArkPaymentException(sendError!);
    sent.add((rail, destination, amountSats));
    return 99;
  }

  final Set<String> wallets = {};
  final Set<String> opened = {};
  final List<String> openedWith = [];
  bool failCreate = false;
  bool failOpen = false;
  Completer<void>? openGate;

  @override
  Future<String> fingerprintOf(Uint8List mnemonic) async => 'fp-${utf8.decode(mnemonic).split(' ').first}';

  @override
  Future<void> create(String fingerprint, Uint8List mnemonic, {required bool restore}) async {
    if (failCreate) throw StateError('bark failed');
    wallets.add(fingerprint);
    opened.add(fingerprint);
  }

  @override
  Future<void> open(String fingerprint, Uint8List mnemonic) async {
    await openGate?.future;
    if (failOpen) throw StateError('open failed');
    openedWith.add(utf8.decode(mnemonic));
    opened.add(fingerprint);
  }

  @override
  bool isOpen(String fingerprint) => opened.contains(fingerprint);

  @override
  Future<ArkBalance> balance(String fingerprint) async => ArkBalance.zero;

  @override
  Future<bool> isRecoveryPending(String fingerprint) async => false;

  @override
  Future<List<String>> listFingerprints() async => wallets.toList();

  @override
  Future<void> wipeAll() async {
    wallets.clear();
    opened.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPrefsRepository prefs;
  late _Secrets secrets;
  late _Backend backend;
  late FakeArkReminder reminder;
  final created = '${'zoo ' * 11}wrong';
  final restored = '${'abandon ' * 11}about';

  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    SharedPreferences.setMockInitialValues({});
    // ignore: deprecated_member_use_from_same_package
    prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    secrets = _Secrets();
    backend = _Backend();
    reminder = FakeArkReminder();
  });

  ArkWalletProvider create() {
    final provider = ArkWalletProvider(
      store: ArkWalletStore(prefs, secrets),
      backend: backend,
      reminder: reminder,
      generateMnemonic: () async => Uint8List.fromList(utf8.encode(created)),
    );
    addTearDown(provider.dispose);
    return provider;
  }

  List<ArkCreateStep> recordSteps(ArkWalletProvider provider) {
    final steps = <ArkCreateStep>[];
    provider.addListener(() {
      final step = provider.step;
      if (step != null && (steps.isEmpty || steps.last != step)) steps.add(step);
    });
    return steps;
  }

  test('there is no wallet at first', () async {
    final provider = create();
    await provider.openAfterAppEntrance();

    expect(provider.state, ArkWalletState.none);
    expect(provider.hasWallet, isFalse);
  });

  test('a new wallet opens and still needs a backup', () async {
    final provider = create();
    final steps = recordSteps(provider);

    await provider.createNew();

    expect(provider.state, ArkWalletState.open);
    expect(provider.needsBackup, isTrue);
    expect(steps, [ArkCreateStep.keys, ArkCreateStep.connecting, ArkCreateStep.ready]);
  });

  test('a restored wallet needs no backup', () async {
    final provider = create();
    final steps = recordSteps(provider);

    await provider.restore(Uint8List.fromList(utf8.encode(restored)));

    expect(provider.needsBackup, isFalse);
    expect(provider.info!.source, ArkSeedSource.restored);
    expect(steps, [ArkCreateStep.restoring, ArkCreateStep.findingFunds, ArkCreateStep.ready]);
  });

  test('a failed bark create stores nothing', () async {
    backend.failCreate = true;
    final provider = create();

    await expectLater(provider.createNew(), throwsStateError);

    expect(provider.state, ArkWalletState.none);
    expect(ArkWalletStore(prefs, secrets).read(), isNull);
    expect(secrets.stored, isEmpty);
  });

  test('bark data without stored info is wiped at start', () async {
    backend.wallets.add('fp-leftover');
    final provider = create();

    await provider.openAfterAppEntrance();

    expect(backend.wallets, isEmpty);
    expect(provider.state, ArkWalletState.none);
  });

  test('a stored wallet opens with its words after app entrance', () async {
    await create().createNew();
    backend.opened.clear();
    final provider = create();

    await provider.openAfterAppEntrance();

    expect(provider.state, ArkWalletState.open);
    expect(backend.openedWith, [created]);
  });

  test('wiping removes the wallet everywhere', () async {
    final provider = create();
    await provider.createNew();

    await provider.wipe();

    expect(provider.state, ArkWalletState.none);
    expect(backend.wallets, isEmpty);
    expect(secrets.stored, isEmpty);
    expect(ArkWalletStore(prefs, secrets).read(), isNull);
  });

  test('the store cannot remove ark while a wallet exists', () async {
    final provider = create();
    expect(ArkFeature.status(provider, isActivated: true).canRemove, isTrue);

    await provider.createNew();

    final status = ArkFeature.status(provider, isActivated: true);
    expect(status.inUse, isTrue);
    expect(status.removeBlockedReason, t.ark_wallet.remove_blocked);
  });

  test('wiping while the wallet is still opening ends with no wallet', () async {
    await create().createNew();
    backend.opened.clear();
    final gate = Completer<void>();
    backend.openGate = gate;
    final provider = create();

    final opening = provider.openAfterAppEntrance();
    await Future<void>.delayed(Duration.zero);
    final wiping = provider.wipe();
    gate.complete();
    await opening;
    await wiping;

    expect(provider.state, ArkWalletState.none);
    expect(provider.hasWallet, isFalse);
    expect(backend.wallets, isEmpty);
    expect(backend.opened, isEmpty);
  });

  test('a seed left without wallet info is removed at start', () async {
    secrets.stored['hot_wallet_secret_orphan'] = Uint8List.fromList(utf8.encode(created));
    final provider = create();

    await provider.openAfterAppEntrance();

    expect(secrets.stored, isEmpty);
  });

  test('balance counts as known only after a successful open', () async {
    await create().createNew();
    backend.opened.clear();
    backend.failOpen = true;
    final provider = create();

    await provider.openAfterAppEntrance();

    expect(provider.state, ArkWalletState.failed);
    expect(provider.isBalanceKnown, isFalse);
  });

  ArkMovement movement(
    int id, {
    String subsystem = 'bark.arkoor',
    String kind = 'receive',
    String status = 'successful',
    int sats = 1000,
    String? hash,
  }) => ArkMovement.fromBark(
    bark.Movement(
      id: id,
      status: status,
      subsystemName: subsystem,
      subsystemKind: kind,
      metadataJson: '{}',
      intendedBalanceSats: sats,
      effectiveBalanceSats: sats,
      offchainFeeSats: 0,
      sentToAddresses: const [],
      receivedOnAddresses: const [],
      inputVtxoIds: const [],
      outputVtxoIds: const [],
      exitedVtxoIds: const [],
      createdAt: '2026-11-18T10:00:0${id % 10}Z',
      updatedAt: '2026-11-18T10:00:00Z',
      paymentHash: hash,
    ),
  );

  group('activity', () {
    test('an open wallet syncs its history newest first and hides empty failures', () async {
      backend.movements = [movement(1), movement(2, status: 'failed', sats: 0), movement(3)];
      final provider = create();
      await provider.createNew();

      await provider.syncNow();

      expect(backend.syncCount, greaterThan(0));
      expect(provider.movements.map((m) => m.id), [3, 1]);
      expect(provider.arkAddress, backend.address);
    });

    test('showing an invoice syncs fast until it is paid or closed', () async {
      final provider = create();
      await provider.createNew();
      expect(provider.syncInterval, const Duration(seconds: 30));

      final invoice = await provider.createInvoice(1000);
      expect(provider.syncInterval, const Duration(seconds: 3));
      expect(provider.isInvoicePaid(invoice.paymentHash), isFalse);

      backend.movements = [movement(5, subsystem: 'bark.lightning_receive', hash: invoice.paymentHash)];
      await provider.syncNow();
      expect(provider.isInvoicePaid(invoice.paymentHash), isTrue);

      provider.stopAwaitingInvoice();
      expect(provider.syncInterval, const Duration(seconds: 30));
    });

    test('a send reports the state bark recorded', () async {
      final provider = create();
      await provider.createNew();
      backend.movements = [movement(99, kind: 'send', sats: -500)];

      final sent = await provider.send(ArkPaymentRail.ark, 'tark1to', 500);
      expect(sent.outcome, ArkSendOutcome.sent);
      expect(backend.sent.single, (ArkPaymentRail.ark, 'tark1to', 500));

      backend.movements = [movement(99, subsystem: 'bark.lightning_send', kind: 'send', status: 'pending', sats: -500)];
      expect((await provider.send(ArkPaymentRail.lightningInvoice, 'lnbcrt1', 500)).outcome, ArkSendOutcome.pending);

      backend.sendError = StateError('refused');
      expect((await provider.send(ArkPaymentRail.ark, 'tark1to', 500)).outcome, ArkSendOutcome.failed);
    });

    test('wiping stops syncing', () async {
      final provider = create();
      await provider.createNew();

      await provider.wipe();

      expect(provider.isSyncing, isFalse);
      expect(provider.movements, isEmpty);
    });
  });

  test('the receive address is taken only after the first sync with the server', () async {
    final provider = create();
    await provider.createNew();

    expect(provider.arkAddress, isNull);
    expect(backend.addressCalls, 0);

    await provider.syncNow();
    expect(provider.arkAddress, backend.address);

    await provider.syncNow();
    expect(backend.addressCalls, 1);
  });

  group('renew', () {
    test('a sync reads the VTXOs and which ones are due within a day', () async {
      backend.vtxoList = [
        fakeVtxo('a', expiry: 1100),
        fakeVtxo('b', expiry: 5000),
        fakeVtxo('c', expiry: 1050, locked: true),
      ];
      backend.expiring = ['a', 'c'];
      backend.tip = 1000;
      final provider = create();
      await provider.createNew();

      await provider.syncNow();

      expect(provider.vtxos.map((vtxo) => vtxo.id), ['c', 'a', 'b']);
      expect(provider.tipHeight, 1000);
      expect(provider.vtxosToRenew.map((vtxo) => vtxo.id), ['a']);
      expect(provider.renewAmount, 1000);
    });

    test('renewing hands exactly the chosen VTXOs to a round and stops nudging for them', () async {
      backend.vtxoList = [fakeVtxo('a', expiry: 1100)];
      backend.expiring = ['a'];
      backend.renewFee = 21;
      final provider = create();
      await provider.createNew();
      await provider.syncNow();

      expect(await provider.estimateRenewFee(['a']), 21);
      await provider.renew(['a']);

      expect(backend.renewed.single, ['a']);
      expect(provider.isRenewing('a'), isTrue);
      expect(provider.vtxosToRenew, isEmpty);
    });

    test('expired VTXOs are still offered for renewal, as the server may take them back', () async {
      backend.vtxoList = [fakeVtxo('gone', expiry: 990), fakeVtxo('due', expiry: 1010)];
      backend.expiring = ['gone', 'due'];
      final provider = create();
      await provider.createNew();

      await provider.syncNow();

      expect(provider.vtxosToRenew.map((vtxo) => vtxo.id), ['gone', 'due']);
      expect(provider.hasExpiredToRenew, isTrue);
    });

    test('the server VTXO lifetime is read after a sync', () async {
      backend.lifetime = 4320;
      final provider = create();
      await provider.createNew();

      await provider.syncNow();

      expect(provider.vtxoLifetime, 4320);
    });

    test('a failed VTXO read keeps the wallet usable', () async {
      final provider = create();
      await provider.createNew();
      backend.tip = null;

      await provider.syncNow();

      expect(provider.tipHeight, isNull);
      expect(provider.vtxosToRenew, isEmpty);
    });
  });

  group('memo', () {
    test('a send keeps its memo on the movement it made', () async {
      final provider = create();
      await provider.createNew();

      await provider.send(ArkPaymentRail.ark, 'tark1to', 500, memo: ' Coffee ');

      expect(provider.memoOf(99), 'Coffee');
    });

    test('a memo can be edited, cleared and survives a restart', () async {
      final provider = create();
      await provider.createNew();

      await provider.setMemo(7, 'Rent');
      expect(create().memoOf(7), 'Rent');

      await provider.setMemo(7, '  ');
      expect(provider.memoOf(7), isNull);
    });

    test('wiping removes the memos', () async {
      final provider = create();
      await provider.createNew();
      await provider.setMemo(7, 'Rent');

      await provider.wipe();

      expect(create().memoOf(7), isNull);
    });
  });

  test('a payment that arrives after opening is announced once', () async {
    backend.movements = [movement(1)];
    final provider = create();
    final announced = <int>[];
    provider.received.listen((movement) => announced.add(movement.id));
    await provider.createNew();
    await provider.syncNow();

    backend.movements = [
      movement(1),
      movement(2, sats: 500),
      movement(3, kind: 'send', sats: -100),
      movement(4, subsystem: 'bark.lightning_receive', status: 'pending'),
    ];
    await provider.syncNow();
    await provider.syncNow();
    backend.movements = [...backend.movements.take(3), movement(4, subsystem: 'bark.lightning_receive')];
    await provider.syncNow();
    await Future<void>.delayed(Duration.zero);

    expect(announced, [2, 4]);
  });

  group('expiry reminder', () {
    test('is set for when the first VTXO enters the renew window, once per expiry', () async {
      backend.vtxoList = [fakeVtxo('a', expiry: 1300), fakeVtxo('b', expiry: 2000)];
      backend.tip = 1000;
      final provider = create();
      await provider.createNew();

      final before = DateTime.now();
      await provider.syncNow();
      await provider.syncNow();

      expect(reminder.calls, hasLength(1));
      final expected = before.add(const Duration(minutes: 10) * (300 - ArkWalletProvider.renewWindowBlocks));
      expect(reminder.calls.single!.difference(expected).inSeconds.abs(), lessThan(5));
    });

    test('is cleared once nothing waits, inside the window and on wipe', () async {
      backend.vtxoList = [fakeVtxo('a', expiry: 1100)];
      final provider = create();
      await provider.createNew();

      await provider.syncNow();
      expect(reminder.calls.last, isNull);

      backend.vtxoList = [fakeVtxo('a', expiry: 1300)];
      await provider.syncNow();
      expect(reminder.calls.last, isNotNull);

      await provider.wipe();
      expect(reminder.calls.last, isNull);
    });
  });

  test('the Ark wallet shows sats by default and keeps a switch to ₿', () async {
    final provider = create();
    await provider.createNew();
    expect(provider.unit, BitcoinUnit.sats);

    await provider.toggleUnit();
    expect(provider.unit, BitcoinUnit.bip177);
    expect(create().unit, BitcoinUnit.bip177);

    await provider.toggleUnit();
    expect(provider.unit, BitcoinUnit.sats);
  });
}
