import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/services/feature/feature_launcher.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';

SinglesigWalletItem _hotWallet(int id) {
  return SinglesigWalletItem(
    id: id,
    name: 'hot$id',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: WalletMock.createSingleSigWalletItem().descriptor,
    hotWalletMetadata: HotWalletMetadata(
      walletId: id,
      secureStorageKey: 'key$id',
      masterFingerprint: 'D45AA182',
      derivationPath: "m/84'/1'/0'",
      accountIndex: 0,
      backupVerified: true,
      enterPassphraseWhenSigning: false,
      createdAt: DateTime(2026),
    ),
  );
}

FeatureItem _item({bool Function(WalletItemBase)? supports}) {
  return FeatureItem(
    id: 'test',
    label: () => 'test',
    context: FeatureContext.wallet,
    isWalletSupported: supports,
    launch: (_, __) async {},
  );
}

bool _hotOnly(WalletItemBase wallet) => wallet.hasLocalKey;

void main() {
  final watchOnly1 = WalletMock.createSingleSigWalletItem(id: 1);
  final watchOnly2 = WalletMock.createSingleSigWalletItem(id: 2);
  final hot3 = _hotWallet(3);

  test('no wallets → unavailable', () {
    expect(resolveWallet(_item(), const [], null), const WalletChoice.unavailable());
  });

  test('one wallet and no shortcut wallet → that wallet directly', () {
    expect(resolveWallet(_item(), [watchOnly1], null), const WalletChoice.direct(1));
  });

  test('several wallets and ask-every-time → ask with all wallets', () {
    expect(
      resolveWallet(_item(), [watchOnly1, watchOnly2], const ShortcutWalletContext.askEveryTime()),
      const WalletChoice.ask([1, 2]),
    );
  });

  test('shortcut wallet that supports the feature → that wallet directly', () {
    expect(
      resolveWallet(_item(), [watchOnly1, watchOnly2], const ShortcutWalletContext.wallet(2)),
      const WalletChoice.direct(2),
    );
  });

  test('shortcut wallet of the wrong type → only supported wallets, single one opens directly', () {
    expect(
      resolveWallet(_item(supports: _hotOnly), [watchOnly1, hot3], const ShortcutWalletContext.wallet(1)),
      const WalletChoice.direct(3),
    );
  });

  test('shortcut wallet of the wrong type and several supported wallets → ask among them', () {
    final hot4 = _hotWallet(4);
    expect(
      resolveWallet(_item(supports: _hotOnly), [watchOnly1, hot3, hot4], const ShortcutWalletContext.wallet(1)),
      const WalletChoice.ask([3, 4]),
    );
  });

  test('no wallet supports the feature → unavailable', () {
    expect(
      resolveWallet(_item(supports: _hotOnly), [watchOnly1, watchOnly2], const ShortcutWalletContext.wallet(1)),
      const WalletChoice.unavailable(),
    );
  });

  test('shortcut wallet was deleted → ask among remaining wallets', () {
    expect(
      resolveWallet(_item(), [watchOnly1, watchOnly2], const ShortcutWalletContext.wallet(99)),
      const WalletChoice.ask([1, 2]),
    );
  });
}
