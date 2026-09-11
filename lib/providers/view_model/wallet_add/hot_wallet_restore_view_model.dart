import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:flutter/foundation.dart';

String _deriveDescriptor(({Uint8List mnemonic, Uint8List passphrase}) input) {
  final seed = Seed.fromMnemonic(input.mnemonic, passphrase: input.passphrase);
  try {
    return SingleSignatureVault.fromSeed(seed).descriptor;
  } finally {
    seed.wipe();
    input.mnemonic.fillRange(0, input.mnemonic.length, 0);
    input.passphrase.fillRange(0, input.passphrase.length, 0);
  }
}

String _deriveMasterFingerprint(({Uint8List mnemonic, Uint8List passphrase}) input) {
  final seed = Seed.fromMnemonic(input.mnemonic, passphrase: input.passphrase);
  try {
    final vault = SingleSignatureVault.fromSeed(seed);
    try {
      return vault.keyStore.masterFingerprint;
    } finally {
      vault.keyStore.wipeSeed();
    }
  } finally {
    seed.wipe();
    input.mnemonic.fillRange(0, input.mnemonic.length, 0);
    input.passphrase.fillRange(0, input.passphrase.length, 0);
  }
}

class HotWalletRestoreViewModel extends ChangeNotifier {
  HotWalletRestoreViewModel({HotWalletSecretRepository? secretRepository})
    : _secretRepository = secretRepository ?? HotWalletSecretRepository(),
      _words = List.filled(12, '');

  final HotWalletSecretRepository _secretRepository;
  int _wordCount = 12;
  List<String> _words;
  int? _activeWordIndex;
  bool _usePassphrase = false;
  bool _enterPassphraseWhenSigning = true;
  String _passphrase = '';
  bool _isRestoring = false;
  Uint8List? _scannedMnemonic;
  int? _scannedMnemonicWordCount;
  bool _disposed = false;

  int get wordCount => _wordCount;
  List<String> get words => List.unmodifiable(_words);
  int? get activeWordIndex => _activeWordIndex;
  bool get usePassphrase => _usePassphrase;
  bool get enterPassphraseWhenSigning => _enterPassphraseWhenSigning;
  String get passphrase => _passphrase;
  bool get isRestoring => _isRestoring;
  bool get hasScannedMnemonic => _scannedMnemonic != null;
  int? get scannedMnemonicWordCount => _scannedMnemonicWordCount;

  bool isKnownWord(int index) => _words[index].isEmpty || WalletUtility.isInMnemonicWordList(_words[index]);

  bool get areAllWordsFilled => _words.every((word) => word.isNotEmpty);

  bool get isMnemonicValid {
    final scannedMnemonic = _scannedMnemonic;
    if (scannedMnemonic != null) {
      final bytes = Uint8List.fromList(scannedMnemonic);
      try {
        return WalletUtility.validateMnemonic(bytes);
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    }
    if (!areAllWordsFilled || _words.any((word) => !WalletUtility.isInMnemonicWordList(word))) {
      return false;
    }
    final bytes = Uint8List.fromList(utf8.encode(_words.join(' ')));
    try {
      return WalletUtility.validateMnemonic(bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  bool get isPassphraseValid => !_usePassphrase || (_passphrase.isNotEmpty && _passphrase.length <= 100);

  bool get canRestore => isMnemonicValid && isPassphraseValid && !_isRestoring;

  List<String> get suggestions {
    final index = _activeWordIndex;
    if (index == null) return const [];
    final query = _words[index];
    if (query.length < 2) {
      return const [];
    }
    return wordList.where((word) => word.startsWith(query)).take(12).toList(growable: false);
  }

  void setWordCount(int value) {
    if (value == _wordCount || (value != 12 && value != 24)) return;
    final previous = _words;
    _wordCount = value;
    _words = List.generate(value, (index) => index < previous.length ? previous[index] : '');
    _activeWordIndex = null;
    _notifySafely();
  }

  void setActiveWordIndex(int? index) {
    if (_activeWordIndex == index) return;
    _activeWordIndex = index;
    _notifySafely();
  }

  void updateWord(int index, String value) {
    _words[index] = value.trim().toLowerCase();
    _activeWordIndex = index;
    _notifySafely();
  }

  int applyWords(int startIndex, Iterable<String> values) {
    var index = startIndex;
    for (final value in values) {
      if (index >= _wordCount) break;
      final normalized = value.trim().toLowerCase();
      if (normalized.isNotEmpty) _words[index++] = normalized;
    }
    _activeWordIndex = index < _wordCount ? index : null;
    _notifySafely();
    return index;
  }

  void clearWords() {
    _words = List.filled(_wordCount, '');
    _activeWordIndex = 0;
    _notifySafely();
  }

  void setScannedMnemonic(Uint8List mnemonic, int wordCount) {
    clearScannedMnemonic(notify: false);
    _scannedMnemonic = Uint8List.fromList(mnemonic);
    _scannedMnemonicWordCount = wordCount;
    _activeWordIndex = null;
    _notifySafely();
  }

  void clearScannedMnemonic({bool notify = true}) {
    _scannedMnemonic?.fillRange(0, _scannedMnemonic!.length, 0);
    _scannedMnemonic = null;
    _scannedMnemonicWordCount = null;
    if (notify) _notifySafely();
  }

  Uint8List _copyMnemonic() {
    final scannedMnemonic = _scannedMnemonic;
    return scannedMnemonic != null
        ? Uint8List.fromList(scannedMnemonic)
        : Uint8List.fromList(utf8.encode(_words.join(' ')));
  }

  void setUsePassphrase(bool value) {
    _usePassphrase = value;
    if (!value) {
      _passphrase = '';
      _enterPassphraseWhenSigning = true;
    }
    _notifySafely();
  }

  void setPassphrase(String value) {
    _passphrase = value;
    _notifySafely();
  }

  void setEnterPassphraseWhenSigning(bool value) {
    _enterPassphraseWhenSigning = value;
    _notifySafely();
  }

  Future<String> deriveDescriptor() async {
    if (!isMnemonicValid || !isPassphraseValid) {
      throw StateError('Invalid restore input');
    }
    final mnemonic = _copyMnemonic();
    final passphrase = Uint8List.fromList(utf8.encode(_usePassphrase ? _passphrase : ''));
    try {
      return await compute(_deriveDescriptor, (
        mnemonic: Uint8List.fromList(mnemonic),
        passphrase: Uint8List.fromList(passphrase),
      ));
    } finally {
      mnemonic.fillRange(0, mnemonic.length, 0);
      passphrase.fillRange(0, passphrase.length, 0);
    }
  }

  Future<String> deriveMasterFingerprint() async {
    if (!hasScannedMnemonic || !isPassphraseValid) {
      throw StateError('Invalid Seed QR input');
    }
    final mnemonic = _copyMnemonic();
    final passphrase = Uint8List.fromList(utf8.encode(_usePassphrase ? _passphrase : ''));
    try {
      return await compute(_deriveMasterFingerprint, (
        mnemonic: Uint8List.fromList(mnemonic),
        passphrase: Uint8List.fromList(passphrase),
      ));
    } finally {
      mnemonic.fillRange(0, mnemonic.length, 0);
      passphrase.fillRange(0, passphrase.length, 0);
    }
  }

  Future<SinglesigWalletItem> restore({
    required WalletProvider walletProvider,
    required String walletName,
    int colorIndex = 0,
    int iconIndex = 0,
    String? derivedDescriptor,
    int? watchOnlyWalletIdToPromote,
  }) async {
    if (!isMnemonicValid || !isPassphraseValid || _isRestoring) {
      throw StateError('Invalid restore input');
    }
    _isRestoring = true;
    _notifySafely();

    final mnemonic = _copyMnemonic();
    final passphrase = Uint8List.fromList(utf8.encode(_usePassphrase ? _passphrase : ''));
    final storageKey = _secretRepository.newSecretStorageKey();
    try {
      final String descriptor;
      if (derivedDescriptor != null) {
        descriptor = derivedDescriptor;
      } else {
        descriptor = await compute(_deriveDescriptor, (
          mnemonic: Uint8List.fromList(mnemonic),
          passphrase: Uint8List.fromList(passphrase),
        ));
      }
      final wallet = WatchOnlyWallet(
        walletName,
        colorIndex,
        iconIndex,
        descriptor,
        null,
        null,
        WalletImportSource.coconutVault.name,
      );
      final passphraseToStore = _enterPassphraseWhenSigning ? Uint8List(0) : Uint8List.fromList(passphrase);
      try {
        await AppGuard.runWithoutPrivacyScreen(
          () => _secretRepository.create(storageKey: storageKey, mnemonic: mnemonic, passphrase: passphraseToStore),
        );
      } finally {
        passphraseToStore.fillRange(0, passphraseToStore.length, 0);
      }
      return await walletProvider.addHotWallet(
        wallet,
        secureStorageKey: storageKey,
        backupVerified: true,
        enterPassphraseWhenSigning: _enterPassphraseWhenSigning,
        createdAt: DateTime.now(),
        watchOnlyWalletIdToPromote: watchOnlyWalletIdToPromote,
      );
    } catch (_) {
      await _secretRepository.delete(storageKey).catchError((_) {});
      rethrow;
    } finally {
      mnemonic.fillRange(0, mnemonic.length, 0);
      passphrase.fillRange(0, passphrase.length, 0);
      _isRestoring = false;
      _notifySafely();
    }
  }

  void _notifySafely() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    clearScannedMnemonic(notify: false);
    super.dispose();
  }
}
