import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpButton(WidgetTester tester, void Function(BuildContext context) onPressed) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Builder(
        builder: (context) => Scaffold(body: TextButton(onPressed: () => onPressed(context), child: const Text('go'))),
      ),
    ),
  );
}

void main() {
  testWidgets('a toast with an action runs it and closes', (tester) async {
    var undone = 0;
    await _pumpButton(
      tester,
      (context) => CoconutToast.showToast(
        context: context,
        text: 'Applied to Home',
        actionText: 'Undo',
        onAction: () => undone++,
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Applied to Home'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coconut-toast-action')));
    await tester.pumpAndSettle();

    expect(undone, 1);
    expect(find.text('Applied to Home'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a toast without an action has no action button', (tester) async {
    await _pumpButton(tester, (context) => CoconutToast.showToast(context: context, text: 'Copied', seconds: 1));

    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.text('Copied'), findsOneWidget);
    expect(find.byKey(const Key('coconut-toast-action')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });
}
