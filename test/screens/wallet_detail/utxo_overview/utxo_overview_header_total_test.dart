import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_overview_header.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_overview_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_summary_chart.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/utxo_amount_format_util.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../repository/realm/test_realm_manager.dart';

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  _Wallets(this.wallet, this.utxos, this.balance);
  final WalletItemBase wallet;
  final List<UtxoState> utxos;
  final Balance balance;

  @override
  List<WalletItemBase> get walletItemList => [wallet];
  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  Balance getWalletBalance(int walletId) => balance;
  @override
  List<UtxoState> getUtxoList(int walletId) => [...utxos]; // the view model sorts it in place
  @override
  bool isUtxoSuspicious(UtxoState utxo, TransactionRecord? txRecord) => false;
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  @override
  TransactionRecord? getTransaction(int walletId, String txHash, {String? utxoTo}) => null;
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {}

/// 법정화폐 줄이 어떤 sats로 계산됐는지 그대로 보이게 한다
class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? get bitcoinPriceKrw => null;
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) =>
      'fiat of $satoshiAmount sats';
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  String get language => 'ko';
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
  @override
  UtxoTierTheme get utxoTierTheme => UtxoTierThemes.pastelWallet;
}

class _Nodes extends Fake with ChangeNotifier implements NodeProvider {
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) => const Stream.empty();
}

var _index = 0;
UtxoState _utxo(int amount, {UtxoStatus status = UtxoStatus.unspent}) => UtxoState(
  transactionHash: (status == UtxoStatus.incoming ? 'b' : 'a') * 64,
  index: _index++,
  amount: amount,
  derivationPath: "m/84'/1'/0'/0/$_index",
  blockHeight: status == UtxoStatus.unspent ? 100 : 0,
  to: 'bcrt1qtest$_index',
  timestamp: DateTime(2026, 11, 11),
  status: status,
);

void main() {
  late TestRealmManager manager;

  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });
  setUp(() => manager = TestRealmManager());
  tearDown(() => manager.dispose());

  // 보내는 중인 거래가 있으면 UTXO 목록 머리글의 BTC 합계가 바로 아래 법정화폐 줄(지갑 잔액)과 달랐다.
  // 머리글 BTC와 법정화폐 줄은 같은 지갑 잔액(confirmed + unconfirmed)을 보여 준다. 보내는 중인 UTXO는 목록에 그대로 남는다.
  // 동기화 중에는 잔액이 먼저 저장되고 UTXO 목록은 나중에 바뀌므로, 목록 합계가 아니라 잔액을 써야 두 줄이 늘 같다
  for (final (name, utxos, balance) in [
    ('normal', [_utxo(300000), _utxo(200000)], Balance(500000, 0)),
    ('pending receive', [_utxo(300000), _utxo(50000, status: UtxoStatus.incoming)], Balance(300000, 50000)),
    (
      'pending send-max to self',
      [
        _utxo(300000, status: UtxoStatus.outgoing),
        _utxo(200000, status: UtxoStatus.outgoing),
        _utxo(499000, status: UtxoStatus.incoming),
      ],
      Balance(500000, -1000),
    ),
    // 잔액은 새로 받는 70,000을 이미 세지만 UTXO 목록은 아직 동기화 전(합계 500,000)
    ('stale UTXO list, balance already updated', [_utxo(300000), _utxo(200000)], Balance(500000, 70000)),
  ]) {
    testWidgets('$name: the header total equals the wallet balance that its fiat line shows', (tester) async {
      final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
      final wallet = SinglesigWalletItem(id: 1, name: 'QA', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor);
      final tags = UtxoTagProvider(UtxoRepository(manager));
      addTearDown(tags.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AnalyticsService>.value(value: AnalyticsService(null, false)),
            Provider<SendInfoProvider>.value(value: SendInfoProvider()),
            ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets(wallet, utxos, balance)),
            ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
            ChangeNotifierProvider<UtxoTagProvider>.value(value: tags),
            ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
            ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
            ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
            ChangeNotifierProvider<NodeProvider>(create: (_) => _Nodes()),
          ],
          child: MaterialApp(
            theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
            home: const UtxoOverviewScreen(id: 1),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final header = find.byWidgetPredicate((w) => w is SliverPersistentHeader && w.delegate is UtxoHeaderDelegate);
      final delegate = tester.widget<SliverPersistentHeader>(header).delegate as UtxoHeaderDelegate;
      final expected = formatUtxoAmountForDisplay(balance.total, BitcoinUnit.btc, dustThreshold: 0);
      expect(delegate.totalBalance, expected);
      expect(delegate.fiatPrice, 'fiat of ${balance.total} sats');
      // 보이는 숫자도 같다(머리글은 숫자와 단위를 한 글자씩 그린다)
      final shown =
          tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SuctionAmountText'),
                  matching: find.byType(Text),
                ),
              )
              .map((text) => text.data)
              .join();
      final space = expected.lastIndexOf(' ');
      expect(shown, expected.substring(0, space) + expected.substring(space + 1));
      // 요약 차트에 넘기는 합계도 같은 잔액이다(이 화면에서는 차트 머리를 그리지 않는다)
      final chart = find.byType(UtxoSummaryChart);
      expect(chart, findsOneWidget);
      expect(tester.widget<UtxoSummaryChart>(chart).totalSats, balance.total);
    });
  }
}
