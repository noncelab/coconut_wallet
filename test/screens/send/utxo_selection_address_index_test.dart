import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/utxo_selection_screen.dart';
import 'package:coconut_wallet/widgets/features/utxo/card/utxo_selection_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const int _walletId = 7;
const _addressIndexKey = ValueKey('utxo_selection_card_address_index');

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  _Wallets(this.utxos);

  final List<UtxoState> utxos;

  @override
  List<UtxoState> getUtxoList(int walletId) => utxos;
}

class _Tags extends Fake with ChangeNotifier implements UtxoTagProvider {
  @override
  List<UtxoTag> getUtxoTagList(int walletId) => [];

  @override
  List<UtxoTag> getUtxoTagsByUtxoId(int walletId, String utxoId) => [];
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => null;
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  UtxoOrder order = UtxoOrder.byAmountDesc;

  @override
  UtxoOrder get utxoSortOrder => order;

  @override
  String get language => 'ko';

  @override
  Future<void> setLastUtxoOrder(UtxoOrder utxoOrder) async {
    order = utxoOrder;
  }
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

UtxoState _utxo(int addressIndex, int amount, {bool isChange = false, UtxoStatus status = UtxoStatus.unspent}) =>
    UtxoState(
      transactionHash: amount.toRadixString(16).padLeft(64, '0'),
      index: 0,
      amount: amount,
      derivationPath: "m/84'/1'/0'/${isChange ? 1 : 0}/$addressIndex",
      blockHeight: 1,
      to: 'public-fixture',
      timestamp: DateTime(2026, 1, 1).add(Duration(minutes: amount)),
      status: status,
    );

void main() {
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final filename in ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf']) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$filename').readAsBytesSync())));
    }
    await loader.load();
  });
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<_Preferences> pump(WidgetTester tester, List<UtxoState> utxos) async {
    final preferences = _Preferences();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets(utxos)),
          ChangeNotifierProvider<UtxoTagProvider>(create: (_) => _Tags()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: const UtxoSelectionScreen(walletId: _walletId, currentUnit: BitcoinUnit.btc, selectedUtxoList: []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return preferences;
  }

  String shownAddressIndexOf(WidgetTester tester, UtxoState utxo) {
    final card = find.byWidgetPredicate((widget) => widget is UtxoSelectionCard && widget.utxo.utxoId == utxo.utxoId);
    return tester.widget<Text>(find.descendant(of: card, matching: find.byKey(_addressIndexKey))).data!;
  }

  testWidgets('UTXO 카드마다 그 UTXO가 들어 있는 주소의 순번이 보인다', (tester) async {
    final receive = _utxo(12, 50000);
    final change = _utxo(3, 20000, isChange: true);
    final locked = _utxo(40, 30000, status: UtxoStatus.locked);
    await pump(tester, [receive, change, locked]);

    expect(shownAddressIndexOf(tester, receive), '12');
    expect(shownAddressIndexOf(tester, change), '3');
    expect(shownAddressIndexOf(tester, locked), '40');
    expect(tester.takeException(), isNull);
  });
}
