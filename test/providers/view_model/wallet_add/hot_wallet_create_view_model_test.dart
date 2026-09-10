import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/wallet_name_conflict_exception.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/hot_wallet_create_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecretRepository extends Fake implements HotWalletSecretRepository {
  _FakeSecretRepository({this.createError});

  final Object? createError;
  final String storageKey = 'hot_wallet_secret_test';
  Uint8List? mnemonic;
  Uint8List? passphrase;
  int createCallCount = 0;
  int deleteCallCount = 0;
  Completer<void>? createGate;

  @override
  String newSecretStorageKey() => storageKey;

  @override
  Future<void> create({required String storageKey, required Uint8List mnemonic, required Uint8List passphrase}) async {
    createCallCount++;
    this.mnemonic = Uint8List.fromList(mnemonic);
    this.passphrase = Uint8List.fromList(passphrase);
    await createGate?.future;
    if (createError != null) throw createError!;
  }

  @override
  Future<void> delete(String storageKey) async {
    deleteCallCount++;
    mnemonic = null;
    passphrase = null;
  }
}

class _FakeWalletProvider extends Fake implements WalletProvider {
  _FakeWalletProvider({List<WalletItemBase>? wallets, this.addError}) : _wallets = wallets ?? [];

  final List<WalletItemBase> _wallets;
  final Object? addError;
  int addCallCount = 0;
  WatchOnlyWallet? addedWallet;
  String? secureStorageKey;
  bool? backupVerified;
  bool? enterPassphraseWhenSigning;
  DateTime? createdAt;

  @override
  List<WalletItemBase> get walletItemList => List.unmodifiable(_wallets);

  @override
  Future<SinglesigWalletItem> addHotWallet(
    WatchOnlyWallet wallet, {
    required String secureStorageKey,
    required bool backupVerified,
    required bool enterPassphraseWhenSigning,
    required DateTime createdAt,
    int? watchOnlyWalletIdToPromote,
  }) async {
    addCallCount++;
    addedWallet = wallet;
    this.secureStorageKey = secureStorageKey;
    this.backupVerified = backupVerified;
    this.enterPassphraseWhenSigning = enterPassphraseWhenSigning;
    this.createdAt = createdAt;
    if (addError != null) throw addError!;
    return SinglesigWalletItem(
      id: 7,
      name: wallet.name,
      colorIndex: wallet.colorIndex,
      iconIndex: wallet.iconIndex,
      descriptor: wallet.descriptor,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HotWalletCreateViewModel', () {
    for (final wordCount in [12, 24]) {
      test('$wordCount단어를 생성하고 실제 passphrase의 descriptor와 저장 secret이 일치한다', () async {
        final secretRepository = _FakeSecretRepository();
        final walletProvider = _FakeWalletProvider();
        final viewModel = HotWalletCreateViewModel(walletProvider, secretRepository: secretRepository);

        final result = await viewModel.createWallet(
          walletName: 'Hot Wallet',
          colorIndex: 2,
          iconIndex: 3,
          mnemonicWordCount: wordCount,
          passphrase: 'real-passphrase',
          enterPassphraseWhenSigning: false,
        );

        final storedMnemonic = secretRepository.mnemonic!;
        final storedPassphrase = secretRepository.passphrase!;
        expect(utf8.decode(storedMnemonic).split(' '), hasLength(wordCount));
        expect(utf8.decode(storedPassphrase), 'real-passphrase');
        expect(result.mnemonic, storedMnemonic);
        expect(result.passphrase, storedPassphrase);

        final seed = Seed.fromMnemonic(storedMnemonic, passphrase: storedPassphrase);
        final descriptor = SingleSignatureVault.fromSeed(seed).descriptor;
        seed.wipe();
        expect(walletProvider.addedWallet!.descriptor, descriptor);
        expect(result.descriptor, descriptor);

        result.clearSensitiveBytes();
        viewModel.dispose();
      });
    }

    test('서명 시 입력 옵션이 켜지면 passphrase를 저장하지 않지만 결과와 descriptor에는 적용한다', () async {
      final secretRepository = _FakeSecretRepository();
      final walletProvider = _FakeWalletProvider();
      final viewModel = HotWalletCreateViewModel(walletProvider, secretRepository: secretRepository);

      final result = await viewModel.createWallet(
        walletName: 'Hot Wallet',
        colorIndex: 0,
        iconIndex: 0,
        mnemonicWordCount: 12,
        passphrase: 'sign-time-passphrase',
        enterPassphraseWhenSigning: true,
      );

      expect(secretRepository.passphrase, isEmpty);
      expect(utf8.decode(result.passphrase), 'sign-time-passphrase');
      final resultPassphrase = Uint8List.fromList(result.passphrase);
      final seed = Seed.fromMnemonic(secretRepository.mnemonic!, passphrase: resultPassphrase);
      final descriptor = SingleSignatureVault.fromSeed(seed).descriptor;
      expect(walletProvider.addedWallet!.descriptor, descriptor);
      expect(result.descriptor, descriptor);
      seed.wipe();
      resultPassphrase.fillRange(0, resultPassphrase.length, 0);
      result.clearSensitiveBytes();
      viewModel.dispose();
    });

    test('backup 상태, 생성 시각, storage key와 저장 옵션을 Provider에 전달한다', () async {
      final now = DateTime.utc(2026, 9, 10, 12, 30);
      final secretRepository = _FakeSecretRepository();
      final walletProvider = _FakeWalletProvider();
      final viewModel = HotWalletCreateViewModel(walletProvider, secretRepository: secretRepository, now: () => now);

      final result = await viewModel.createWallet(
        walletName: 'Hot Wallet',
        colorIndex: 0,
        iconIndex: 0,
        mnemonicWordCount: 12,
        passphrase: '',
        enterPassphraseWhenSigning: false,
      );

      expect(walletProvider.secureStorageKey, secretRepository.storageKey);
      expect(walletProvider.backupVerified, isFalse);
      expect(walletProvider.createdAt, now);
      expect(walletProvider.enterPassphraseWhenSigning, isFalse);
      result.clearSensitiveBytes();
      viewModel.dispose();
    });

    test('중복 이름이면 secret 생성 전에 거부한다', () async {
      const descriptor =
          "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";
      final existing = SinglesigWalletItem(
        id: 1,
        name: 'Duplicated',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: descriptor,
      );
      final secretRepository = _FakeSecretRepository();
      final walletProvider = _FakeWalletProvider(wallets: [existing]);
      final viewModel = HotWalletCreateViewModel(walletProvider, secretRepository: secretRepository);

      await expectLater(
        viewModel.createWallet(
          walletName: 'Duplicated',
          colorIndex: 0,
          iconIndex: 0,
          mnemonicWordCount: 12,
          passphrase: '',
          enterPassphraseWhenSigning: false,
        ),
        throwsA(isA<WalletNameConflictException>()),
      );
      expect(secretRepository.createCallCount, 0);
      expect(walletProvider.addCallCount, 0);
      viewModel.dispose();
    });

    test('빠른 중복 요청은 첫 생성만 수행한다', () async {
      final secretRepository = _FakeSecretRepository()..createGate = Completer<void>();
      final walletProvider = _FakeWalletProvider();
      final viewModel = HotWalletCreateViewModel(walletProvider, secretRepository: secretRepository);
      final first = viewModel.createWallet(
        walletName: 'Hot Wallet',
        colorIndex: 0,
        iconIndex: 0,
        mnemonicWordCount: 12,
        passphrase: '',
        enterPassphraseWhenSigning: false,
      );
      while (secretRepository.createCallCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      await expectLater(
        viewModel.createWallet(
          walletName: 'Hot Wallet',
          colorIndex: 0,
          iconIndex: 0,
          mnemonicWordCount: 12,
          passphrase: '',
          enterPassphraseWhenSigning: false,
        ),
        throwsStateError,
      );
      secretRepository.createGate!.complete();
      final result = await first;
      expect(secretRepository.createCallCount, 1);
      expect(walletProvider.addCallCount, 1);
      result.clearSensitiveBytes();
      viewModel.dispose();
    });

    test('생성 작업 중 dispose되어도 완료 시 notifyListeners를 호출하지 않는다', () async {
      final secretRepository = _FakeSecretRepository()..createGate = Completer<void>();
      final walletProvider = _FakeWalletProvider();
      final viewModel = HotWalletCreateViewModel(walletProvider, secretRepository: secretRepository);
      final creation = viewModel.createWallet(
        walletName: 'Hot Wallet',
        colorIndex: 0,
        iconIndex: 0,
        mnemonicWordCount: 12,
        passphrase: '',
        enterPassphraseWhenSigning: false,
      );
      while (secretRepository.createCallCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      viewModel.dispose();
      secretRepository.createGate!.complete();
      final result = await creation;

      expect(result.walletId, 7);
      expect(viewModel.isCreating, isFalse);
      result.clearSensitiveBytes();
    });

    test('키 재료 생성 실패 시 secret과 Realm에 아무것도 생성하지 않는다', () async {
      final secretRepository = _FakeSecretRepository();
      final walletProvider = _FakeWalletProvider();
      final viewModel = HotWalletCreateViewModel(
        walletProvider,
        secretRepository: secretRepository,
        materialGenerator: (_, _) async => throw StateError('key generation failed'),
      );

      await expectLater(
        viewModel.createWallet(
          walletName: 'Hot Wallet',
          colorIndex: 0,
          iconIndex: 0,
          mnemonicWordCount: 12,
          passphrase: '',
          enterPassphraseWhenSigning: false,
        ),
        throwsStateError,
      );
      expect(secretRepository.createCallCount, 0);
      expect(secretRepository.deleteCallCount, 1);
      expect(walletProvider.addCallCount, 0);
      expect(viewModel.isCreating, isFalse);
      viewModel.dispose();
    });

    test('secret 쓰기 실패 시 Realm을 생성하지 않고 secret 정리를 시도한다', () async {
      final secretRepository = _FakeSecretRepository(createError: StateError('secret write failed'));
      final walletProvider = _FakeWalletProvider();
      final viewModel = HotWalletCreateViewModel(walletProvider, secretRepository: secretRepository);

      await expectLater(
        viewModel.createWallet(
          walletName: 'Hot Wallet',
          colorIndex: 0,
          iconIndex: 0,
          mnemonicWordCount: 12,
          passphrase: '',
          enterPassphraseWhenSigning: false,
        ),
        throwsStateError,
      );
      expect(secretRepository.deleteCallCount, 1);
      expect(walletProvider.addCallCount, 0);
      expect(viewModel.isCreating, isFalse);
      viewModel.dispose();
    });

    test('Realm 생성 단계 실패 시 저장한 secret을 삭제한다', () async {
      final secretRepository = _FakeSecretRepository();
      final walletProvider = _FakeWalletProvider(addError: StateError('realm write failed'));
      final viewModel = HotWalletCreateViewModel(walletProvider, secretRepository: secretRepository);

      await expectLater(
        viewModel.createWallet(
          walletName: 'Hot Wallet',
          colorIndex: 0,
          iconIndex: 0,
          mnemonicWordCount: 12,
          passphrase: '',
          enterPassphraseWhenSigning: false,
        ),
        throwsStateError,
      );
      expect(secretRepository.createCallCount, 1);
      expect(secretRepository.deleteCallCount, 1);
      expect(secretRepository.mnemonic, isNull);
      expect(viewModel.isCreating, isFalse);
      viewModel.dispose();
    });

    test('Provider의 중복 핫월렛 거부 시 저장한 secret을 삭제한다', () async {
      final secretRepository = _FakeSecretRepository();
      final walletProvider = _FakeWalletProvider(addError: StateError('duplicated hot wallet'));
      final viewModel = HotWalletCreateViewModel(walletProvider, secretRepository: secretRepository);

      await expectLater(
        viewModel.createWallet(
          walletName: 'Hot Wallet',
          colorIndex: 0,
          iconIndex: 0,
          mnemonicWordCount: 12,
          passphrase: '',
          enterPassphraseWhenSigning: false,
        ),
        throwsStateError,
      );
      expect(secretRepository.deleteCallCount, 1);
      viewModel.dispose();
    });
  });
}
