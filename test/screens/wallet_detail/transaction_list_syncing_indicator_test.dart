import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required bool syncing}) => tester.pumpWidget(
  MaterialApp(
    theme: buildCoconutThemeData(),
    home: Scaffold(body: Center(child: TransactionListSyncingIndicator(isSyncing: syncing))),
  ),
);

/// 0 once the label is gone from the tree.
double _opacity(WidgetTester tester) {
  final opacity = find.ancestor(of: find.text(t.status_updating), matching: find.byType(Opacity));
  return opacity.evaluate().isEmpty ? 0 : tester.widget<Opacity>(opacity.first).opacity;
}

double _width(WidgetTester tester) => tester.getSize(find.byType(TransactionListSyncingIndicator)).width;

/// Draws a frame every 10 ms for [ms] and checks the label stays fully visible in each one.
Future<void> _expectOpaqueFor(WidgetTester tester, int ms, String phase) async {
  for (var elapsed = 10; elapsed <= ms; elapsed += 10) {
    await tester.pump(const Duration(milliseconds: 10));
    expect(_opacity(tester), 1, reason: '$phase, $elapsed ms');
  }
}

// Same timing as WalletRefreshIndicator: a 350 ms easeInOut fade, and a 300 ms hold before hiding.
void main() {
  testWidgets('fades in and widens when syncing starts', (tester) async {
    await _pump(tester, syncing: false);
    expect(find.text(t.status_updating), findsNothing);

    await _pump(tester, syncing: true);
    await tester.pump(const Duration(milliseconds: 175));
    final (midOpacity, midWidth) = (_opacity(tester), _width(tester));
    await tester.pump(const Duration(milliseconds: 175));

    expect(midOpacity, inExclusiveRange(0, 1));
    expect(midWidth, inExclusiveRange(0, _width(tester)), reason: 'the width grows with the fade, no jump');
    expect(_opacity(tester), 1);
  });

  testWidgets('stays 300 ms after syncing stops, then fades out', (tester) async {
    await _pump(tester, syncing: true);
    await tester.pump(const Duration(milliseconds: 350));

    await _pump(tester, syncing: false);
    await _expectOpaqueFor(tester, 290, 'holding after the stop');

    await tester.pump(const Duration(milliseconds: 10)); // the hold ends
    await tester.pump(const Duration(milliseconds: 175));
    expect(_opacity(tester), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 175));
    expect(find.text(t.status_updating), findsNothing);
    expect(_width(tester), 0);
  });

  testWidgets('a stop and restart within 300 ms does not flicker', (tester) async {
    await _pump(tester, syncing: true);
    await tester.pump(const Duration(milliseconds: 350));

    await _pump(tester, syncing: false);
    await _expectOpaqueFor(tester, 150, 'stopped');
    await _pump(tester, syncing: true);
    await _expectOpaqueFor(tester, 1000, 'restarted'); // past the cancelled hold and a whole fade
  });
}
