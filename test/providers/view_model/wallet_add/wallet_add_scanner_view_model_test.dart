import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/air-gapped/wallet_add_scanner_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _WalletProvider extends Fake implements WalletProvider {
  WatchOnlyWallet? addedWallet;

  @override
  List<WalletItemBase> get walletItemList => const [];

  @override
  Future<ResultOfSyncFromVault> syncFromThirdParty(
    WatchOnlyWallet wallet, {
    bool allowExistingHotWallet = false,
  }) async {
    addedWallet = wallet;
    return ResultOfSyncFromVault(result: WalletSyncResult.newWalletAdded, walletId: 77);
  }
}

class _PreferenceProvider extends Fake implements PreferenceProvider {}

void main() {
  const xpub =
      'tpubDDMbU29QrSafD2Ui4yGv31Xp3PPSMvudreoohYjR8xLTng7hbsjYwUTeRhiKULFqX16M5M8zZh9siw5i6RRyisc6LtWjr1FwBYTiZUGGYJN';
  const descriptor = "wpkh([9b1441e4/84'/1'/0']$xpub/<0;1>/*)";
  late _WalletProvider wallets;

  WalletAddScannerViewModel createViewModel(WalletImportSource source) {
    final viewModel = WalletAddScannerViewModel(source, wallets, _PreferenceProvider());
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  setUp(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    wallets = _WalletProvider();
  });

  for (final source in [WalletImportSource.extendedPublicKey, WalletImportSource.descriptor]) {
    group(source.name, () {
      test('스캔 전에는 xpub으로 판별하지 않는다', () {
        expect(createViewModel(source).isExtendedPublicKeyScanned, isFalse);
      });

      test('xpub을 스캔하면 진입 메뉴와 무관하게 MFP를 포함한 xpub 지갑을 추가한다', () async {
        final viewModel = createViewModel(source);
        final handler = viewModel.qrDataHandler;
        expect(handler.validateFormat(xpub), isTrue);
        expect(handler.joinData(xpub), isTrue);
        expect(handler.isCompleted(), isTrue);
        expect(viewModel.isExtendedPublicKeyScanned, isTrue);

        final result = await viewModel.addWallet(
          handler.result,
          isExtendedPublicKey: viewModel.isExtendedPublicKeyScanned,
          masterFingerPrint: '1234abcd',
        );

        expect(result.result, WalletSyncResult.newWalletAdded);
        expect(wallets.addedWallet, isNotNull);
        expect(wallets.addedWallet!.descriptor, contains('1234abcd'));
        expect(wallets.addedWallet!.walletImportSource, WalletImportSource.extendedPublicKey);
      });

      test('descriptor는 xpub으로 판별하지 않고 출처가 descriptor로 저장된다', () async {
        final viewModel = createViewModel(source);
        final handler = viewModel.qrDataHandler;
        expect(handler.validateFormat(descriptor), isTrue);
        expect(handler.joinData(descriptor), isTrue);
        expect(viewModel.isExtendedPublicKeyScanned, isFalse);

        final result = await viewModel.addWallet(
          handler.result,
          isExtendedPublicKey: viewModel.isExtendedPublicKeyScanned,
        );

        expect(result.result, WalletSyncResult.newWalletAdded);
        expect(wallets.addedWallet!.descriptor, contains('9b1441e4'));
        expect(wallets.addedWallet!.walletImportSource, WalletImportSource.descriptor);
      });

      test('reset 후에는 이전 xpub 판별을 유지하지 않는다', () {
        final viewModel = createViewModel(source);
        final handler = viewModel.qrDataHandler;
        expect(handler.validateFormat(xpub), isTrue);
        expect(handler.joinData(xpub), isTrue);

        handler.reset();

        expect(viewModel.isExtendedPublicKeyScanned, isFalse);
        expect(handler.validateFormat(descriptor), isTrue);
        expect(handler.joinData(descriptor), isTrue);
        expect(viewModel.isExtendedPublicKeyScanned, isFalse);
      });
    });
  }

  test('다른 handler를 사용하는 메뉴에서도 타입 변환 오류 없이 false를 반환한다', () {
    for (final source in [
      WalletImportSource.coconutVault,
      WalletImportSource.keystone,
      WalletImportSource.jade,
      WalletImportSource.seedSigner,
      WalletImportSource.krux,
      WalletImportSource.passport,
      WalletImportSource.coldCard,
    ]) {
      expect(createViewModel(source).isExtendedPublicKeyScanned, isFalse, reason: source.name);
    }
  });
}
