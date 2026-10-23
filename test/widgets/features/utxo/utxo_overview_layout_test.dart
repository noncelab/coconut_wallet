import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_bucket.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_overview_filter_widgets.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_summary_chart.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  UtxoTierTheme get utxoTierTheme => UtxoTierThemes.pastelWallet;
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  testWidgets('overview cards keep a compact top gap across widths, text sizes and empty state', (tester) async {
    final preferences = _Preferences();
    addTearDown(preferences.dispose);
    final funded = [
      for (final amount in [100000000, 21000])
        UtxoState(
          transactionHash: amount.toRadixString(16).padLeft(64, '0'),
          index: 0,
          amount: amount,
          derivationPath: "m/84'/1'/0'/0/0",
          blockHeight: 1,
          to: 'qa',
          timestamp: DateTime(2026),
        ),
    ];
    for (final width in [344.0, 414.0]) {
      for (final scale in [1.0, 1.6]) {
        for (final utxos in [<UtxoState>[], funded]) {
          await tester.pumpWidget(
            ChangeNotifierProvider<PreferenceProvider>.value(
              value: preferences,
              child: MaterialApp(
                theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
                home: MediaQuery(
                  data: MediaQueryData(size: Size(width, 896), textScaler: TextScaler.linear(scale)),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: UtxoSummaryChart(
                              buckets: bucketize(utxos, dustThreshold: 546),
                              totalSats: utxos.fold(0, (sum, utxo) => sum + utxo.amount),
                              coinCount: utxos.length,
                              availableCount: utxos.length,
                              availableSats: utxos.fold(0, (sum, utxo) => sum + utxo.amount),
                              lockedCount: 0,
                              lockedSats: 0,
                              currentUnit: BitcoinUnit.btc,
                              dustThreshold: 546,
                              showBalanceHeader: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final chart = tester.getRect(find.byType(UtxoSummaryChart));
          final label = find.text('${t.utxo_detail_screen.utxo_unlocked} • ${utxos.length} coins');
          final card = tester.getRect(find.ancestor(of: label, matching: find.byType(Container)).first);
          expect(card.top - chart.top, 16);
          final contentBottom = utxos.isEmpty ? card.bottom : tester.getRect(find.text('small')).bottom + 16;
          expect(chart.bottom - contentBottom, 24);
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('wider grouping tabs respond at their edges and align the moving indicator', (tester) async {
    var isByAmount = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        home: StatefulBuilder(
          builder:
              (context, setState) => UtxoGroupingTabBar(
                isByAmount: isByAmount,
                onSelected: (index) => setState(() => isByAmount = index == 0),
              ),
        ),
      ),
    );
    for (final index in [1, 0]) {
      final tab = tester.getRect(find.byType(UtxoGroupingTab).at(index));
      expect(tab.width, 96);
      await tester.tapAt(Offset(tab.right - 4, tab.center.dy));
      await tester.pumpAndSettle();
      expect(isByAmount, index == 0);
      final indicator = tester.getRect(
        find.descendant(of: find.byType(AnimatedPositioned), matching: find.byType(Container)),
      );
      expect(indicator.left, tab.left);
      expect(indicator.width, tab.width);
      expect(tester.takeException(), isNull);
    }
  });
}
