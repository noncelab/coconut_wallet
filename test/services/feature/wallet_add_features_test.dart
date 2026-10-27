import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Analytics extends AnalyticsService {
  _Analytics() : super(null, true);

  final List<({String name, Map<String, Object> parameters})> events = [];

  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {
    events.add((name: eventName, parameters: AnalyticsService.normalizeParameters(parameters)));
  }
}

Future<_Analytics> _launch(WidgetTester tester, String featureId) async {
  final analytics = _Analytics();
  final feature = FeatureRegistry.builtin().byId(featureId)!;
  await tester.pumpWidget(
    Provider<AnalyticsService>.value(
      value: analytics,
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        home: Builder(
          builder:
              (context) =>
                  Scaffold(body: TextButton(onPressed: () => feature.launch!(context, null), child: const Text('go'))),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return analytics;
}

void main() {
  testWidgets('add hot wallet skips the wallet type step and opens create or restore', (tester) async {
    final analytics = await _launch(tester, FeatureIds.walletAddHot);

    expect(tester.widget<WalletAddDialog>(find.byType(WalletAddDialog)).mode, WalletAddDialogMode.hotWalletAction);
    expect(
      tester.widget<Text>(find.byKey(const Key('wallet-add-dialog-title'))).data,
      t.feature_registry.wallet_add_hot,
    );
    final clicked = analytics.events.firstWhere((event) => event.name == AnalyticsEventNames.walletAddButtonClicked);
    expect(clicked.parameters.values, contains(WalletAddEntrySource.feature.name));
  });

  testWidgets('add watch-only wallet skips the wallet type step and opens the device list', (tester) async {
    await _launch(tester, FeatureIds.walletAddWatchOnly);

    expect(tester.widget<WalletAddDialog>(find.byType(WalletAddDialog)).mode, WalletAddDialogMode.watchOnlySource);
    expect(
      tester.widget<Text>(find.byKey(const Key('wallet-add-dialog-title'))).data,
      t.feature_registry.wallet_add_watch_only,
    );
  });
}
