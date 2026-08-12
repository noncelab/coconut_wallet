import 'package:coconut_wallet/providers/view_model/wallet_add/hot_wallet_restore_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
