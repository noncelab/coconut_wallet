import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/hot_wallet_restore_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/utils/nfkd_util.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecretRepository extends Fake implements HotWalletSecretRepository {
  @override
  String newSecretStorageKey() => 'hot_wallet_secret_restore_test';

  @override
  Future<void> create({required String storageKey, required Uint8List mnemonic, required Uint8List passphrase}) async {}

  @override
  Future<void> delete(String storageKey) async {}
}

class _GatedWalletProvider extends Fake implements WalletProvider {
  final gate = Completer<void>();
  bool addStarted = false;
  bool? enterPassphraseWhenSigning;
  bool? backupVerified;
  int? convertedWalletId;
  Object? addError;

  @override
  Future<T> runHotWalletLifecycleOperation<T>(Future<T> Function() operation) => operation();

  @override
  Future<SinglesigWalletItem> addHotWallet(
    WatchOnlyWallet wallet, {
    required String secureStorageKey,
    required bool backupVerified,
    required bool enterPassphraseWhenSigning,
    required DateTime createdAt,
    int? watchOnlyWalletIdToConvert,
  }) async {
    addStarted = true;
    this.enterPassphraseWhenSigning = enterPassphraseWhenSigning;
    this.backupVerified = backupVerified;
    convertedWalletId = watchOnlyWalletIdToConvert;
    await gate.future;
    if (addError != null) throw addError!;
    return SinglesigWalletItem(
      id: 1,
      name: wallet.name,
      colorIndex: wallet.colorIndex,
      iconIndex: wallet.iconIndex,
      descriptor: wallet.descriptor,
    );
  }
}

class _RecordingSecretRepository extends _FakeSecretRepository {
  _RecordingSecretRepository({this.createError});

  final Object? createError;
  int createCalls = 0;
  int deleteCalls = 0;
  Uint8List? borrowedMnemonic;
  Uint8List? borrowedPassphrase;
  Uint8List? storedMnemonic;
  Uint8List? storedPassphrase;

  @override
  Future<void> create({required String storageKey, required Uint8List mnemonic, required Uint8List passphrase}) async {
    createCalls++;
    borrowedMnemonic = mnemonic;
    borrowedPassphrase = passphrase;
    storedMnemonic = Uint8List.fromList(mnemonic);
    storedPassphrase = Uint8List.fromList(passphrase);
    if (createError != null) throw createError!;
  }

  @override
  Future<void> delete(String storageKey) async => deleteCalls++;
}

class _NameValidationWallet extends Fake implements WalletItemBase {
  @override
  int get id => 1;
  @override
  String name = 'taken';
  @override
  String get descriptor => 'test-descriptor';
  @override
  WalletType get walletType => WalletType.singleSignature;
}

class _NameConflictProvider extends Fake implements WalletProvider {
  final wallet = _NameValidationWallet();
  int validationCalls = 0;
  @override
  List<WalletItemBase> get walletItemList => [wallet];
  @override
  String? resolveWalletNameConflict({
    required String desiredName,
    required String descriptor,
    required bool isSingleSig,
    int? excludeWalletId,
  }) {
    validationCalls++;
    return desiredName == wallet.name ? null : desiredName;
  }
}

void main() {
  test('완성된 니모닉 단어도 추천 목록에 유지한다', () {
    final viewModel = HotWalletRestoreViewModel();
    viewModel.setActiveWordIndex(0);
    viewModel.updateWord(0, 'apple');

    expect(viewModel.suggestions, contains('apple'));
  });

  test('이름 검사는 지갑 식별 후 적용하고 시드 입력이 바뀌면 초기화한다', () async {
    final vm = HotWalletRestoreViewModel();
    final provider = _NameConflictProvider();
    vm.applyWords(0, [...List.filled(11, 'abandon'), 'about']);
    expect(vm.hasWalletNameConflict(provider, 'taken'), isFalse);
    await vm.deriveDescriptor();
    expect(vm.hasWalletNameConflict(provider, 'taken'), isTrue);
    expect(vm.hasWalletNameConflict(provider, 'available'), isFalse);
    final initialCalls = provider.validationCalls;
    for (final name in ['t', 'ta', 'tak', 'taken', 'other']) {
      vm.hasWalletNameConflict(provider, name);
    }
    expect(provider.validationCalls, initialCalls);
    provider.wallet.name = 'renamed';
    expect(vm.hasWalletNameConflict(provider, 'taken'), isFalse);
    expect(vm.hasWalletNameConflict(provider, 'renamed'), isTrue);
    expect(provider.validationCalls, initialCalls + 1);
    provider.wallet.name = 'taken';

    vm.setPassphrase('changed');
    expect(vm.hasWalletNameConflict(provider, 'taken'), isFalse);
    await vm.deriveDescriptor();
    expect(vm.hasWalletNameConflict(provider, 'taken'), isTrue);
    vm.updateWord(0, 'ability');
    expect(vm.hasWalletNameConflict(provider, 'taken'), isFalse);
    vm.dispose();
  });

  test('조합형과 NFKD 분해형 패스프레이즈로 같은 descriptor를 파생한다', () async {
    final composed = HotWalletRestoreViewModel();
    final decomposed = HotWalletRestoreViewModel();
    final words = [...List.filled(11, 'abandon'), 'about'];
    composed.applyWords(0, words);
    decomposed.applyWords(0, words);
    composed.setUsePassphrase(true);
    decomposed.setUsePassphrase(true);
    composed.setPassphrase('코코넛-Café');
    decomposed.setPassphrase('\u110F\u1169\u110F\u1169\u1102\u1165\u11BA-Cafe\u0301');

    expect(await composed.deriveDescriptor(), await decomposed.deriveDescriptor());

    composed.dispose();
    decomposed.dispose();
  });

  group('HotWalletRestoreViewModel', () {
    for (final wordCount in [12, 24]) {
      for (final passphraseAtSigning in [false, true]) {
        test('restores $wordCount words with correct passphrase storage (input=$passphraseAtSigning)', () async {
          final secrets = _RecordingSecretRepository();
          final provider = _GatedWalletProvider()..gate.complete();
          final model = HotWalletRestoreViewModel(secretRepository: secrets);
          addTearDown(model.dispose);
          final words = [...List.filled(wordCount - 1, 'abandon'), wordCount == 12 ? 'about' : 'art'];
          model.setWordCount(wordCount);
          model.applyWords(0, words);
          model.setUsePassphrase(true);
          model.setPassphrase('Café');
          model.setEnterPassphraseWhenSigning(passphraseAtSigning);

          final restored = await model.restore(
            walletProvider: provider,
            walletName: 'Restored test wallet',
            watchOnlyWalletIdToConvert: 42,
          );
          final normalizedPassphrase = NfkdUtil.encodeNfkd('Café');
          final mnemonic = Uint8List.fromList(utf8.encode(words.join(' ')));
          final vault = SingleSignatureVault.fromMnemonic(mnemonic, passphrase: normalizedPassphrase);
          try {
            expect(restored.descriptor, vault.descriptor);
            expect(secrets.storedMnemonic, mnemonic);
            expect(secrets.storedPassphrase, passphraseAtSigning ? isEmpty : normalizedPassphrase);
            expect(provider.enterPassphraseWhenSigning, passphraseAtSigning);
            expect(provider.backupVerified, isTrue);
            expect(provider.convertedWalletId, 42);
            expect(secrets.deleteCalls, 0);
            expect(secrets.borrowedMnemonic, everyElement(0));
            expect(secrets.borrowedPassphrase, everyElement(0));
          } finally {
            vault.keyStore.wipeSeed();
            mnemonic.fillRange(0, mnemonic.length, 0);
            normalizedPassphrase.fillRange(0, normalizedPassphrase.length, 0);
          }
        });
      }
    }

    for (final failSecretWrite in [true, false]) {
      test('failed restoration cleans secret and resets retry guard (secret=$failSecretWrite)', () async {
        final failure = StateError('Injected persistence failure');
        final secrets = _RecordingSecretRepository(createError: failSecretWrite ? failure : null);
        final provider =
            _GatedWalletProvider()
              ..addError = failSecretWrite ? null : failure
              ..gate.complete();
        final model = HotWalletRestoreViewModel(secretRepository: secrets);
        addTearDown(model.dispose);
        model.applyWords(0, [...List.filled(11, 'abandon'), 'about']);
        model.setUsePassphrase(true);
        model.setPassphrase('test-passphrase');

        await expectLater(
          model.restore(walletProvider: provider, walletName: 'Failed test restore'),
          throwsA(same(failure)),
        );
        expect(secrets.createCalls, 1);
        expect(secrets.deleteCalls, 1);
        expect(provider.addStarted, !failSecretWrite);
        expect(model.isRestoring, isFalse);
        expect(model.canRestore, isTrue);
        expect(secrets.borrowedMnemonic, everyElement(0));
        expect(secrets.borrowedPassphrase, everyElement(0));
      });
    }

    test('concurrent restoration cannot create a second secret', () async {
      final secrets = _RecordingSecretRepository();
      final provider = _GatedWalletProvider()..gate.complete();
      final model = HotWalletRestoreViewModel(secretRepository: secrets);
      addTearDown(model.dispose);
      model.applyWords(0, [...List.filled(11, 'abandon'), 'about']);

      final first = model.restore(walletProvider: provider, walletName: 'First test restore');
      await expectLater(
        model.restore(walletProvider: provider, walletName: 'Duplicate test restore'),
        throwsStateError,
      );
      await first;
      expect(secrets.createCalls, 1);
    });

    test('mainnet에서는 mainnet descriptor를 파생한다', () async {
      NetworkType.setNetworkType(NetworkType.mainnet);
      final viewModel = HotWalletRestoreViewModel();
      viewModel.applyWords(0, [...List.filled(11, 'abandon'), 'about']);

      try {
        final descriptor = await viewModel.deriveDescriptor();

        expect(descriptor, contains('zpub'));
        expect(descriptor, contains("/84'/0'/0'"));
        expect(() => SingleSignatureWallet.fromDescriptor(descriptor), returnsNormally);
      } finally {
        viewModel.dispose();
        NetworkType.setNetworkType(NetworkType.testnet);
      }
    });

    test('validates a complete BIP39 mnemonic', () {
      final viewModel = HotWalletRestoreViewModel();
      viewModel.applyWords(0, [
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'about',
      ]);

      expect(viewModel.isMnemonicValid, isTrue);
      expect(viewModel.canRestore, isTrue);
    });

    test('rejects invalid checksum and incomplete input', () {
      final viewModel = HotWalletRestoreViewModel();
      viewModel.applyWords(0, List.filled(12, 'abandon'));

      expect(viewModel.isMnemonicValid, isFalse);
      expect(viewModel.canRestore, isFalse);
    });

    test('suggests BIP39 words from a prefix', () {
      final viewModel = HotWalletRestoreViewModel();
      viewModel.updateWord(0, 'aban');

      expect(viewModel.suggestions, contains('abandon'));
    });

    test('requires a non-empty passphrase when enabled', () {
      final viewModel = HotWalletRestoreViewModel();
      viewModel.applyWords(0, [
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'about',
      ]);
      viewModel.setUsePassphrase(true);

      expect(viewModel.canRestore, isFalse);
      viewModel.setPassphrase('secret');
      expect(viewModel.canRestore, isTrue);
    });

    test('복원 작업 중 dispose되어도 완료 시 notifyListeners를 호출하지 않는다', () async {
      const descriptor =
          "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";
      final walletProvider = _GatedWalletProvider();
      final viewModel = HotWalletRestoreViewModel(secretRepository: _FakeSecretRepository());
      viewModel.applyWords(0, [
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'abandon',
        'about',
      ]);

      final restoration = viewModel.restore(
        walletProvider: walletProvider,
        walletName: 'Restored Wallet',
        derivedDescriptor: descriptor,
      );
      while (!walletProvider.addStarted) {
        await Future<void>.delayed(Duration.zero);
      }

      viewModel.dispose();
      walletProvider.gate.complete();
      final result = await restoration;

      expect(result.id, 1);
      expect(walletProvider.enterPassphraseWhenSigning, isFalse);
      expect(viewModel.isRestoring, isFalse);
    });
  });
}
