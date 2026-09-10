import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/hot_wallet_restore_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
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

  @override
  Future<SinglesigWalletItem> addHotWallet(
    WatchOnlyWallet wallet, {
    required String secureStorageKey,
    required bool backupVerified,
    required bool enterPassphraseWhenSigning,
    required DateTime createdAt,
    int? watchOnlyWalletIdToPromote,
  }) async {
    addStarted = true;
    await gate.future;
    return SinglesigWalletItem(
      id: 1,
      name: wallet.name,
      colorIndex: wallet.colorIndex,
      iconIndex: wallet.iconIndex,
      descriptor: wallet.descriptor,
    );
  }
}

void main() {
  group('HotWalletRestoreViewModel', () {
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
      expect(viewModel.isRestoring, isFalse);
    });
  });
}
