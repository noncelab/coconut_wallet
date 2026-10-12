import 'dart:ui';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_view_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWalletListItemBase extends Fake implements WalletItemBase {
  @override
  final int id;
  FakeWalletListItemBase(this.id);
}

class FakeWalletProvider extends Fake implements WalletProvider {
  final List<WalletItemBase> _walletItems;
  final Map<int, Set<String>> _addressesByWalletId;

  FakeWalletProvider({List<WalletItemBase>? walletItems, Map<int, Set<String>>? addressesByWalletId})
    : _walletItems = walletItems ?? [],
      _addressesByWalletId = addressesByWalletId ?? {};

  @override
  List<WalletItemBase> get walletItemList => _walletItems;

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
  final BitcoinUnit unit;

  FakePreferenceProvider({this.unit = BitcoinUnit.sats});

  @override
  BitcoinUnit get currentUnit => unit;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class FakeTransactionDraftRepository extends Fake implements TransactionDraftRepository {}

class FakeUtxoRepository extends Fake implements UtxoRepository {}

class FakeWalletPreferencesRepository extends Fake implements WalletPreferencesRepository {}

void main() {
  SendViewModel createViewModel({required FakeWalletProvider walletProvider, BitcoinUnit unit = BitcoinUnit.sats}) {
    return SendViewModel(
      walletProvider,
      FakeSendInfoProvider(),
      FakePreferenceProvider(unit: unit),
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

  group('onKeyTap', () {
    // recipientList[0].amount는 항상 canonical 포맷('.' 소수점, 구분자 없음)으로 유지된다.
    String amount(SendViewModel vm) => vm.recipientList[0].amount;

    group('sats 단위', () {
      test('숫자 입력이 이어지고 소수점은 무시된다', () {
        final viewModel = createViewModel(walletProvider: FakeWalletProvider());
        viewModel.onKeyTap('1');
        viewModel.onKeyTap('2');
        viewModel.onKeyTap('3');
        expect(amount(viewModel), '123');
        viewModel.onKeyTap('.');
        expect(amount(viewModel), '123');
      });

      test("첫 입력이 '0'이고 그 후 숫자가 오면 0을 대체한다", () {
        final viewModel = createViewModel(walletProvider: FakeWalletProvider());
        viewModel.onKeyTap('0');
        viewModel.onKeyTap('5');
        expect(amount(viewModel), '5');
      });

      test("'<' 입력 시 마지막 문자를 삭제한다", () {
        final viewModel = createViewModel(walletProvider: FakeWalletProvider());
        viewModel.onKeyTap('1');
        viewModel.onKeyTap('2');
        viewModel.onKeyTap('<');
        expect(amount(viewModel), '1');
      });
    });

    group('btc 단위', () {
      test("빈 상태에서 '.' 입력 시 '0.'이 된다", () {
        final viewModel = createViewModel(walletProvider: FakeWalletProvider(), unit: BitcoinUnit.btc);
        viewModel.onKeyTap('.');
        expect(amount(viewModel), '0.');
      });

      test("',' 입력은 '.'으로 변환된다 (comma-decimal preset의 소수점)", () {
        final viewModel = createViewModel(walletProvider: FakeWalletProvider(), unit: BitcoinUnit.btc);
        viewModel.onKeyTap('1');
        viewModel.onKeyTap(',');
        viewModel.onKeyTap('5');
        expect(amount(viewModel), '1.5');
      });

      test('소수부는 8자리까지만 허용된다', () {
        final viewModel = createViewModel(walletProvider: FakeWalletProvider(), unit: BitcoinUnit.btc);
        for (final c in ['0', '.', '1', '2', '3', '4', '5', '6', '7', '8']) {
          viewModel.onKeyTap(c);
        }
        viewModel.onKeyTap('9');
        expect(amount(viewModel), '0.12345678');
      });

      test('소수점은 하나만 입력할 수 있다', () {
        final viewModel = createViewModel(walletProvider: FakeWalletProvider(), unit: BitcoinUnit.btc);
        for (final c in ['1', '.', '5', '.', '2']) {
          viewModel.onKeyTap(c);
        }
        expect(amount(viewModel), '1.52');
      });
    });
  });
}
