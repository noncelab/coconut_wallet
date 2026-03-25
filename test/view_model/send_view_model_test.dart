import 'dart:ui';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/send_view_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWalletListItemBase extends Fake implements WalletListItemBase {
  @override
  final int id;
  FakeWalletListItemBase(this.id);
}

class FakeWalletProvider extends Fake implements WalletProvider {
  final List<WalletListItemBase> _walletItems;
  final Map<int, Set<String>> _addressesByWalletId;

  FakeWalletProvider({List<WalletListItemBase>? walletItems, Map<int, Set<String>>? addressesByWalletId})
    : _walletItems = walletItems ?? [],
      _addressesByWalletId = addressesByWalletId ?? {};

  @override
  List<WalletListItemBase> get walletItemList => _walletItems;

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) {
    return _addressesByWalletId[walletId]?.contains(address) ?? false;
  }

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class FakeSendInfoProvider extends Fake implements SendInfoProvider {
  @override
  void clear() {}

  @override
  void setSendEntryPoint(SendEntryPoint sendEntryPoint) {}
}

class FakePreferenceProvider extends Fake implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class FakeTransactionDraftRepository extends Fake implements TransactionDraftRepository {}

class FakeUtxoRepository extends Fake implements UtxoRepository {}

class FakeWalletPreferencesRepository extends Fake implements WalletPreferencesRepository {}

void main() {
  SendViewModel createViewModel({required FakeWalletProvider walletProvider}) {
    return SendViewModel(
      walletProvider,
      FakeSendInfoProvider(),
      FakePreferenceProvider(),
      FakeTransactionDraftRepository(),
      FakeUtxoRepository(),
      true,
      (_) {},
      (_) {},
      (_) {},
      null,
      SendEntryPoint.home,
      null,
      [],
    );
  }

  group('isOwnAddress', () {
    test('지갑이 없으면 false 반환', () {
      final viewModel = createViewModel(walletProvider: FakeWalletProvider());
      expect(viewModel.isOwnAddress('bc1qtest123'), false);
    });

    test('지갑에 포함된 주소면 true 반환', () {
      const address = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';
      final viewModel = createViewModel(
        walletProvider: FakeWalletProvider(
          walletItems: [FakeWalletListItemBase(1)],
          addressesByWalletId: {
            1: {address},
          },
        ),
      );
      expect(viewModel.isOwnAddress(address), true);
    });

    test('지갑에 포함되지 않은 주소면 false 반환', () {
      final viewModel = createViewModel(
        walletProvider: FakeWalletProvider(
          walletItems: [FakeWalletListItemBase(1)],
          addressesByWalletId: {
            1: {'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'},
          },
        ),
      );
      expect(viewModel.isOwnAddress('bc1qdifferentaddress'), false);
    });

    test('여러 지갑 중 두 번째 지갑에 포함된 주소면 true 반환', () {
      const address = 'bc1qsecondwalletaddress';
      final viewModel = createViewModel(
        walletProvider: FakeWalletProvider(
          walletItems: [FakeWalletListItemBase(1), FakeWalletListItemBase(2)],
          addressesByWalletId: {
            1: {'bc1qfirstwalletaddress'},
            2: {address},
          },
        ),
      );
      expect(viewModel.isOwnAddress(address), true);
    });

    test('빈 문자열은 false 반환', () {
      final viewModel = createViewModel(
        walletProvider: FakeWalletProvider(
          walletItems: [FakeWalletListItemBase(1)],
          addressesByWalletId: {
            1: {'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'},
          },
        ),
      );
      expect(viewModel.isOwnAddress(''), false);
    });

    test('유사하지만 다른 주소면 false 반환', () {
      final viewModel = createViewModel(
        walletProvider: FakeWalletProvider(
          walletItems: [FakeWalletListItemBase(1)],
          addressesByWalletId: {
            1: {'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'},
          },
        ),
      );
      expect(viewModel.isOwnAddress('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5'), false);
    });

    test('여러 지갑 모두에 포함되지 않은 주소면 false 반환', () {
      final viewModel = createViewModel(
        walletProvider: FakeWalletProvider(
          walletItems: [FakeWalletListItemBase(1), FakeWalletListItemBase(2), FakeWalletListItemBase(3)],
          addressesByWalletId: {
            1: {'addr_wallet1_a', 'addr_wallet1_b'},
            2: {'addr_wallet2_a'},
            3: {'addr_wallet3_a', 'addr_wallet3_b', 'addr_wallet3_c'},
          },
        ),
      );
      expect(viewModel.isOwnAddress('addr_not_owned'), false);
    });

    test('첫 번째 지갑에서 바로 발견되면 나머지 지갑은 확인하지 않아도 true 반환', () {
      const address = 'bc1qfirstwalletaddress';
      final viewModel = createViewModel(
        walletProvider: FakeWalletProvider(
          walletItems: [FakeWalletListItemBase(1), FakeWalletListItemBase(2)],
          addressesByWalletId: {
            1: {address},
            2: {},
          },
        ),
      );
      expect(viewModel.isOwnAddress(address), true);
    });
  });
}
