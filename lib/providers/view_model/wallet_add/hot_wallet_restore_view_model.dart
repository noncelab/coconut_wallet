import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/utils/nfkd_util.dart';
import 'package:flutter/foundation.dart';

String _deriveDescriptor(({Uint8List mnemonic, Uint8List passphrase, String networkType}) input) {
  Seed? seed;
  try {
    NetworkType.setNetworkType(NetworkType.getNetworkType(input.networkType));
    seed = Seed.fromMnemonic(input.mnemonic, passphrase: input.passphrase);
    return SingleSignatureVault.fromSeed(seed).descriptor;
  } finally {
    seed?.wipe();
    input.mnemonic.fillRange(0, input.mnemonic.length, 0);
    input.passphrase.fillRange(0, input.passphrase.length, 0);
  }
}

String _deriveMasterFingerprint(({Uint8List mnemonic, Uint8List passphrase, String networkType}) input) {
  Seed? seed;
  try {
    NetworkType.setNetworkType(NetworkType.getNetworkType(input.networkType));
    seed = Seed.fromMnemonic(input.mnemonic, passphrase: input.passphrase);
    final vault = SingleSignatureVault.fromSeed(seed);
    try {
      return vault.keyStore.masterFingerprint;
    } finally {
      vault.keyStore.wipeSeed();
    }
  } finally {
    seed?.wipe();
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
  String? _validatedDescriptor;
  int _inputRevision = 0;
  List<(int, String, String, WalletType)>? _nameValidationSnapshot;
  final Set<String> _conflictingNames = {};

  void _invalidateDescriptor() {
    _validatedDescriptor = null;
    _nameValidationSnapshot = null;
    _conflictingNames.clear();
    _inputRevision++;
  }

  bool hasWalletNameConflict(WalletProvider walletProvider, String walletName) {
    final descriptor = _validatedDescriptor;
    if (descriptor == null) return false;
    // Reuse identity checks while only the text field changes. Include names and
    // descriptors so wallet additions, renames and replacements invalidate the cache.
    final snapshot = [
      for (final wallet in walletProvider.walletItemList)
        (wallet.id, wallet.name, wallet.descriptor, wallet.walletType),
    ];
    if (!listEquals(_nameValidationSnapshot, snapshot)) {
      _conflictingNames.clear();
      for (final name in snapshot.map((wallet) => wallet.$2).toSet()) {
        if (walletProvider.resolveWalletNameConflict(desiredName: name, descriptor: descriptor, isSingleSig: true) ==
            null) {
          _conflictingNames.add(name);
        }
      }
      _nameValidationSnapshot = snapshot;
    }
    return _conflictingNames.contains(walletName);
  }

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
    _invalidateDescriptor();
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
    _invalidateDescriptor();
    _words[index] = value.trim().toLowerCase();
    _activeWordIndex = index;
    _notifySafely();
  }

  int applyWords(int startIndex, Iterable<String> values) {
    _invalidateDescriptor();
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
    _invalidateDescriptor();
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
    _invalidateDescriptor();
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
    _invalidateDescriptor();
    _usePassphrase = value;
    if (!value) {
      _passphrase = '';
      _enterPassphraseWhenSigning = true;
    }
    _notifySafely();
  }

  void setPassphrase(String value) {
    _invalidateDescriptor();
    _passphrase = value;
    _notifySafely();
  }

  void setEnterPassphraseWhenSigning(bool value) {
    _enterPassphraseWhenSigning = value;
    _notifySafely();
  }

  Future<String> deriveDescriptor() async {
    final revision = _inputRevision;
    if (!isMnemonicValid || !isPassphraseValid) {
      throw StateError('Invalid restore input');
    }
    final mnemonic = _copyMnemonic();
    var passphrase = Uint8List(0);
    try {
      passphrase = NfkdUtil.encodeNfkd(_usePassphrase ? _passphrase : '');
      final descriptor = await compute(_deriveDescriptor, (
        mnemonic: mnemonic,
        passphrase: passphrase,
        networkType: NetworkType.currentNetworkType.toString(),
      ));
      if (revision != _inputRevision || _disposed) {
        throw StateError('Restore input changed during derivation');
      }
      if (_validatedDescriptor != descriptor) _nameValidationSnapshot = null;
      _validatedDescriptor = descriptor;
      _notifySafely();
      return descriptor;
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
    var passphrase = Uint8List(0);
    try {
      passphrase = NfkdUtil.encodeNfkd(_usePassphrase ? _passphrase : '');
      return await compute(_deriveMasterFingerprint, (
        mnemonic: mnemonic,
        passphrase: passphrase,
        networkType: NetworkType.currentNetworkType.toString(),
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
    int? watchOnlyWalletIdToConvert,
  }) async {
    if (!isMnemonicValid || !isPassphraseValid || _isRestoring) {
      throw StateError('Invalid restore input');
    }
    final storageKey = _secretRepository.newSecretStorageKey();
    _isRestoring = true;
    _notifySafely();

    var mnemonic = Uint8List(0);
    var passphrase = Uint8List(0);
    var secretCleanupHandledUnderLock = false;
    try {
      mnemonic = _copyMnemonic();
      passphrase = NfkdUtil.encodeNfkd(_usePassphrase ? _passphrase : '');
      final String descriptor;
      if (derivedDescriptor != null) {
        descriptor = derivedDescriptor;
      } else {
        final mnemonicCopy = Uint8List.fromList(mnemonic);
        final passphraseCopy = Uint8List.fromList(passphrase);
        try {
          descriptor = await compute(_deriveDescriptor, (
            mnemonic: mnemonicCopy,
            passphrase: passphraseCopy,
            networkType: NetworkType.currentNetworkType.toString(),
          ));
        } finally {
          mnemonicCopy.fillRange(0, mnemonicCopy.length, 0);
          passphraseCopy.fillRange(0, passphraseCopy.length, 0);
        }
      }
      return await walletProvider.runHotWalletLifecycleOperation(() async {
        try {
          final enterPassphraseWhenSigning = _usePassphrase && _enterPassphraseWhenSigning;
          final wallet = WatchOnlyWallet(
            walletName,
            colorIndex,
            iconIndex,
            descriptor,
            null,
            null,
            WalletImportSource.coconutVault.name,
          );
          final passphraseToStore = enterPassphraseWhenSigning ? Uint8List(0) : Uint8List.fromList(passphrase);
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
            enterPassphraseWhenSigning: enterPassphraseWhenSigning,
            createdAt: DateTime.now(),
            watchOnlyWalletIdToConvert: watchOnlyWalletIdToConvert,
          );
        } catch (_) {
          secretCleanupHandledUnderLock = true;
          await _secretRepository.delete(storageKey).catchError((_) {});
          rethrow;
        }
      });
    } catch (_) {
      if (!secretCleanupHandledUnderLock) {
        await _secretRepository.delete(storageKey).catchError((_) {});
      }
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
