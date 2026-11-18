import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_backend.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_store.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeArkSecrets extends Fake implements HotWalletSecretRepository {
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

class FakeArkBackend implements ArkWalletBackend {
  final Set<String> wallets = {};
  final Set<String> opened = {};
  ArkBalance currentBalance = ArkBalance.zero;

  /// 주어지면 bark 생성이 이 완료를 기다림
  Completer<void>? createGate;
  bool failOpen = false;

  @override
  Future<String> fingerprintOf(Uint8List mnemonic) async => 'fp-${utf8.decode(mnemonic).split(' ').first}';

  @override
  Future<void> create(String fingerprint, Uint8List mnemonic, {required bool restore}) async {
    await createGate?.future;
    wallets.add(fingerprint);
    opened.add(fingerprint);
  }

  @override
  Future<void> open(String fingerprint, Uint8List mnemonic) async {
    if (failOpen) throw StateError('open failed');
    opened.add(fingerprint);
  }

  @override
  bool isOpen(String fingerprint) => opened.contains(fingerprint);

  @override
  Future<ArkBalance> balance(String fingerprint) async => currentBalance;

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

Future<ArkWalletProvider> fakeArkWalletProvider({
  FakeArkBackend? backend,
  FakeArkSecrets? secrets,
  bool keepPrefs = false,
}) async {
  if (!keepPrefs) SharedPreferences.setMockInitialValues({});
  // ignore: deprecated_member_use_from_same_package
  final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
  return ArkWalletProvider(
    store: ArkWalletStore(prefs, secrets ?? FakeArkSecrets()),
    backend: backend ?? FakeArkBackend(),
    generateMnemonic: () async => Uint8List.fromList(utf8.encode('${'zoo ' * 11}wrong')),
  );
}
