import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_stack_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final List<WalletItemBase> wallets;

  _Wallets(this.wallets);

  @override
  List<WalletItemBase> get walletItemList => wallets;
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  List<int> walletOrder;

  _Preferences(this.walletOrder);

  @override
  Future<void> setWalletOrder(List<int> walletOrder) async {
    this.walletOrder = walletOrder;
    notifyListeners();
  }
}

WalletItemBase _watchOnly(int id) => WalletMock.createSingleSigWalletItem(id: id);

WalletItemBase _hot(int id) {
  final base = WalletMock.createSingleSigWalletItem(id: id);
  return SinglesigWalletItem(
    id: id,
    name: base.name,
    colorIndex: 0,
    iconIndex: 0,
    descriptor: base.descriptor,
    hotWalletMetadata: HotWalletMetadata(
      walletId: id,
      secureStorageKey: 'key',
      masterFingerprint: 'D45AA182',
      derivationPath: "m/84'/1'/0'",
      accountIndex: 0,
      backupVerified: true,
      enterPassphraseWhenSigning: false,
      createdAt: DateTime(2026),
    ),
  );
}

void main() {
  final wallets = [_watchOnly(1), _hot(2), _watchOnly(3), _hot(4)];

  test('moving a wallet in the all-wallets list saves the whole order', () {
    final preferences = _Preferences([1, 2, 3, 4]);
    final viewModel = WalletStackListViewModel(WalletStackKind.all, _Wallets(wallets), preferences);

    viewModel.reorder(0, 2);

    expect(preferences.walletOrder, [2, 3, 1, 4]);
    expect(viewModel.wallets.map((wallet) => wallet.id), [2, 3, 1, 4]);
  });

  test('moving a hot wallet swaps only hot wallet slots and keeps the others in place', () {
    final preferences = _Preferences([1, 2, 3, 4]);
    final viewModel = WalletStackListViewModel(WalletStackKind.hot, _Wallets(wallets), preferences);

    viewModel.reorder(1, 0);

    expect(preferences.walletOrder, [1, 4, 3, 2]);
    expect(viewModel.wallets.map((wallet) => wallet.id), [4, 2]);
  });

  test('wallets missing from the saved order are kept after the ordered ones', () {
    final preferences = _Preferences([3, 1]);
    final viewModel = WalletStackListViewModel(WalletStackKind.all, _Wallets(wallets), preferences);

    viewModel.reorder(3, 0);

    expect(preferences.walletOrder, [4, 3, 1, 2]);
  });

  test('dropping a wallet where it already is saves nothing', () {
    final preferences = _Preferences([1, 2, 3, 4]);
    final viewModel = WalletStackListViewModel(WalletStackKind.all, _Wallets(wallets), preferences);

    viewModel.reorder(1, 1);

    expect(preferences.walletOrder, [1, 2, 3, 4]);
  });
}
