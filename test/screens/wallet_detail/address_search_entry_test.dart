import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../mock/wallet_mock.dart';

class _Preferences extends ChangeNotifier implements PreferenceProvider {
  bool unused = false;
  int writes = 0;
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  bool get showOnlyUnusedAddresses => unused;
  @override
  bool hasSeenReceivingTooltipToday() => true;
  @override
  bool hasSeenChangeTooltipToday() => true;
  @override
  Future<void> changeShowOnlyUnusedAddresses(bool value) async {
    unused = value;
    writes++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wallets extends ChangeNotifier implements WalletProvider {
  final wallet = WalletMock.createSingleSigWalletItem(id: 1);
  final requests = <({bool change, bool unused, int cursor})>[];
  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  (int, int) getUsedIndexes(int id) => (-1, -1);
  @override
  Future<List<WalletAddress>> getWalletAddressList(
    WalletItemBase wallet,
    int cursor,
    int count,
    bool change,
    bool unused,
  ) async {
    requests.add((change: change, unused: unused, cursor: cursor));
    return List.generate(count, (offset) {
      final index = (cursor < 0 ? 100 : cursor + 1) + offset;
      return WalletAddress(
        'bcrt1qexampleaddressforpublicuitest$index',
        "m/84'/1'/0'/${change ? 1 : 0}/$index",
        index,
        change,
        !unused && offset.isEven,
        0,
        0,
        0,
      );
    });
  }

  @override
  Future<void> addAddressesWithGapLimit({
    required WalletItemBase walletItemBase,
    required List<WalletAddress> newAddresses,
    required bool isChange,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Node extends Fake implements NodeProvider {
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int id) => const Stream.empty();
  @override
  Future<Result<List<WalletAddress>>> syncViewedAddresses(WalletItemBase wallet, List<WalletAddress> addresses) async =>
      Result.success([]);
}

void main() {
  late _Preferences preferences;
  late _Wallets wallets;
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    preferences = _Preferences();
    wallets = _Wallets();
  });

  Future<void> pump(WidgetTester tester, {bool? initial}) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
          InheritedProvider<NodeProvider>(create: (_) => _Node()),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: AddressListScreen(id: 1, initialShowOnlyUnusedAddresses: initial),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
  }

  testWidgets('unused search uses a local filter for initial load, pagination and explicit toggles', (tester) async {
    await pump(tester, initial: true);
    expect(wallets.requests.map((request) => request.unused), everyElement(true));
    expect(preferences.unused, false);
    expect(preferences.writes, 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(wallets.requests.any((request) => request.cursor >= 0), true);
    expect(wallets.requests.last.unused, true);

    await tester.tap(find.text(t.address_list_screen.show_only_unused_address));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(wallets.requests.last.unused, false);
    expect(preferences.unused, false);
    expect(preferences.writes, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    wallets.requests.clear();
    await pump(tester);
    expect(wallets.requests.map((request) => request.unused), everyElement(false));
  });

  testWidgets('ordinary address entry retains its existing persisted filter policy', (tester) async {
    await pump(tester);
    expect(wallets.requests.last.unused, false);
    await tester.tap(find.text(t.address_list_screen.show_only_unused_address));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(preferences.unused, true);
    expect(preferences.writes, 1);
    expect(wallets.requests.last.unused, true);
  });
}
