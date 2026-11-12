import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/historical_bitcoin_price_service.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show formatHomeRelativeTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import '../../mock/wallet_mock.dart';

final _lastTx = DateTime.now().subtract(const Duration(days: 3, hours: 2));

SinglesigWalletItem _wallet(int id, {required bool hot}) {
  final base = WalletMock.createSingleSigWalletItem(id: id);
  return SinglesigWalletItem(
    id: id,
    name: base.name,
    colorIndex: 0,
    iconIndex: 0,
    descriptor: base.descriptor,
    hotWalletMetadata:
        hot
            ? HotWalletMetadata(
              walletId: id,
              secureStorageKey: 'key',
              masterFingerprint: 'D45AA182',
              derivationPath: "m/84'/1'/0'",
              accountIndex: 0,
              backupVerified: true,
              enterPassphraseWhenSigning: false,
              createdAt: DateTime(2026),
            )
            : null,
  );
}

TransactionRecord _received(String txid) => TransactionRecord(
  txid,
  _lastTx,
  100,
  TransactionType.received,
  null,
  50000000,
  0,
  const [],
  const [],
  141.0,
  _lastTx,
);

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final wallets = [_wallet(1, hot: true), _wallet(2, hot: false)];

  @override
  WalletLoadState get walletLoadState => WalletLoadState.loadCompleted;
  @override
  late final ValueNotifier<WalletLoadState> walletLoadStateNotifier = ValueNotifier(walletLoadState);
  @override
  late final ValueNotifier<List<WalletItemBase>> walletItemListNotifier = ValueNotifier(wallets);
  @override
  List<WalletItemBase> get walletItemList => wallets;
  @override
  Balance getWalletBalance(int walletId) => Balance(50000000, 0);
  @override
  List<TransactionRecord> getTransactionRecordList(int walletId) => [_received('tx-$walletId')];
  @override
  List<TransactionRecord> getConfirmedTransactionRecordListWithinDateRange(
    List<int> walletIds,
    Tuple2<DateTime, DateTime> dateRange,
  ) => [for (final id in walletIds) ...getTransactionRecordList(id)];
  @override
  List<UtxoState> getUtxoList(int walletId) => const [];
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences({required this.fake});

  final bool fake;

  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  FiatCode get selectedFiat => FiatCode.KRW;
  @override
  bool get isFakeBalanceActive => fake;
  @override
  int? get fakeBalanceTotalAmount => fake ? 123456789 : null;
  @override
  double getFakeBalance(int walletId) => fake ? 123456789 : 0;
  @override
  List<int> get walletOrder => const [];
  @override
  UtxoTierTheme get utxoTierTheme => UtxoTierThemes.pastelWallet;
  @override
  bool get isBalanceHidden => false;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => 150000000;
}

class _History extends Fake implements HistoricalBitcoinPriceService {
  @override
  Future<List<double>?> fetchDailyCloses(FiatCode fiatCode) async => null;
}

Widget _smallStack(HomeWidgetsViewModel viewModel, String stackId) {
  final definition = walletStackDefinitions().firstWhere((definition) => definition.id == stackId);
  final item = HomeItem(
    id: 'test-$stackId',
    definitionId: stackId,
    kind: HomeItemKind.widget,
    order: 0,
    span: HomeSpan.small,
    configuration: const {},
  );
  return ChangeNotifierProvider<HomeWidgetsViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      theme: buildCoconutThemeData(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 173, height: 173, child: Builder(builder: (_) => definition.buildTile(item))),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  for (final stackId in [HomeItemIds.hotWalletStack, HomeItemIds.watchOnlyWalletStack, HomeItemIds.allWalletStack]) {
    for (final fake in [false, true]) {
      testWidgets('$stackId small card ${fake ? 'hides' : 'shows'} the last transaction time with fake balance '
          '${fake ? 'on' : 'off'}', (tester) async {
        final semantics = tester.ensureSemantics();
        final viewModel = HomeWidgetsViewModel(
          walletProvider: _Wallets(),
          preferenceProvider: _Preferences(fake: fake),
          priceProvider: _Prices(),
          targetSatsOf: (_) => null,
          historicalPriceService: _History(),
          usesFakeBalance: true,
        );
        await tester.pumpWidget(_smallStack(viewModel, stackId));
        await tester.pumpAndSettle();

        final realTime = formatHomeRelativeTime(_lastTx, DateTime.now());
        expect(find.text(realTime), fake ? findsNothing : findsWidgets);
        expect(find.bySemanticsLabel(RegExp(RegExp.escape(realTime))), fake ? findsNothing : findsWidgets);

        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(HomeWidgetsViewModel.priceWaitLimit);
        viewModel.dispose();
      });
    }
  }
}
