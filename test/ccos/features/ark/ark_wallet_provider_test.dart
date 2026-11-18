import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_backend.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_store.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _Backend implements ArkWalletBackend {
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
  late SharedPrefsRepository prefs;
  late _Secrets secrets;
  late _Backend backend;
  final created = '${'zoo ' * 11}wrong';
  final restored = '${'abandon ' * 11}about';

  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    SharedPreferences.setMockInitialValues({});
    // ignore: deprecated_member_use_from_same_package
    prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    secrets = _Secrets();
    backend = _Backend();
  });

  ArkWalletProvider create() {
    final provider = ArkWalletProvider(
      store: ArkWalletStore(prefs, secrets),
      backend: backend,
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
}
