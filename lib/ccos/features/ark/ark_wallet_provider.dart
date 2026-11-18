import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_backend.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_store.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';

enum ArkWalletState { none, opening, open, failed }

enum ArkCreateStep { keys, connecting, restoring, findingFunds, ready }

Uint8List _randomMnemonic(int wordCount) {
  final seed = Seed.random(mnemonicLength: wordCount, passphrase: Uint8List(0));
  try {
    return Uint8List.fromList(seed.mnemonic);
  } finally {
    seed.wipe();
  }
}

Future<Uint8List> _generateMnemonicInIsolate() => compute(_randomMnemonic, 12);

/// 앱의 아크 지갑 하나. 앱이 켜져 있는 동안 bark 지갑을 열어 둠
class ArkWalletProvider extends ChangeNotifier {
  ArkWalletProvider({
    required ArkWalletStore store,
    required ArkWalletBackend backend,
    Future<Uint8List> Function()? generateMnemonic,
  }) : _store = store,
       _backend = backend,
       _generateMnemonic = generateMnemonic ?? _generateMnemonicInIsolate,
       _info = store.read();

  final ArkWalletStore _store;
  final ArkWalletBackend _backend;
  final Future<Uint8List> Function() _generateMnemonic;

  ArkWalletInfo? _info;
  ArkWalletState _state = ArkWalletState.none;
  ArkCreateStep? _step;
  ArkBalance _balance = ArkBalance.zero;
  bool _isRecoveryPending = false;

  ArkWalletInfo? get info => _info;
  bool get hasWallet => _info != null;
  ArkWalletState get state => _state;
  ArkCreateStep? get step => _step;
  ArkBalance get balance => _balance;
  bool get needsBackup => _info != null && !_info!.backupVerified;
  bool get isRecoveryPending => _isRecoveryPending;

  /// 지갑이 열려 잔액을 읽은 상태
  bool get isBalanceKnown => _state == ArkWalletState.open;

  Future<void> _tail = Future.value();

  /// 만들기·열기·지우기를 하나씩 차례로
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> createNew() => _serial(() async {
    _setStep(ArkCreateStep.keys);
    final mnemonic = await _generateMnemonic();
    await _create(mnemonic, ArkSeedSource.created);
  });

  Future<void> restore(Uint8List mnemonic) => _serial(() => _create(mnemonic, ArkSeedSource.restored));

  Future<void> _create(Uint8List mnemonic, ArkSeedSource source) async {
    final restore = source == ArkSeedSource.restored;
    try {
      if (restore) _setStep(ArkCreateStep.restoring);
      final fingerprint = await _backend.fingerprintOf(mnemonic);
      if (!restore) _setStep(ArkCreateStep.connecting);
      await _backend.create(fingerprint, mnemonic, restore: restore);
      if (restore) _setStep(ArkCreateStep.findingFunds);
      _balance = await _backend.balance(fingerprint);
      _isRecoveryPending = await _backend.isRecoveryPending(fingerprint);
      _info = await _store.save(mnemonic: mnemonic, fingerprint: fingerprint, source: source);
      _state = ArkWalletState.open;
      _setStep(ArkCreateStep.ready);
    } catch (_) {
      await _backend.wipeAll();
      await _store.clear();
      _info = null;
      _state = ArkWalletState.none;
      _setStep(null);
      rethrow;
    } finally {
      mnemonic.fillRange(0, mnemonic.length, 0);
    }
  }

  Future<void> openAfterAppEntrance() => _serial(_openAfterAppEntrance);

  Future<void> _openAfterAppEntrance() async {
    final info = _info = _store.read();
    if (info == null) {
      if ((await _backend.listFingerprints()).isNotEmpty) await _backend.wipeAll();
      await _store.clear();
      _state = ArkWalletState.none;
      notifyListeners();
      return;
    }
    if (_backend.isOpen(info.fingerprint)) {
      try {
        await refreshBalance();
      } catch (error) {
        Logger.error('ArkWalletProvider: failed to refresh the Ark balance: $error');
      }
      return;
    }
    _state = ArkWalletState.opening;
    notifyListeners();
    try {
      final mnemonic = await _store.readMnemonic(info);
      try {
        await _backend.open(info.fingerprint, mnemonic);
      } finally {
        mnemonic.fillRange(0, mnemonic.length, 0);
      }
      _state = ArkWalletState.open;
      await refreshBalance();
    } catch (error) {
      Logger.error('ArkWalletProvider: failed to open the Ark wallet: $error');
      _state = ArkWalletState.failed;
      notifyListeners();
    }
  }

  Future<void> refreshBalance() async {
    final info = _info;
    if (info == null || !_backend.isOpen(info.fingerprint)) return;
    _balance = await _backend.balance(info.fingerprint);
    _isRecoveryPending = await _backend.isRecoveryPending(info.fingerprint);
    notifyListeners();
  }

  Future<Uint8List> readMnemonicForBackup() => _store.readMnemonic(_info!);

  Future<void> markBackupVerified() async {
    await _store.markBackupVerified();
    _info = _store.read();
    notifyListeners();
  }

  Future<void> wipe() => _serial(_wipe);

  Future<void> _wipe() async {
    await _backend.wipeAll();
    await _store.clear();
    _info = null;
    _state = ArkWalletState.none;
    _step = null;
    _balance = ArkBalance.zero;
    _isRecoveryPending = false;
    notifyListeners();
  }

  void _setStep(ArkCreateStep? step) {
    _step = step;
    notifyListeners();
  }
}
