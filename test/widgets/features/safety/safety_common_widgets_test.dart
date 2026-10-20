import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(CoconutThemeVariant variant, Widget child) => MaterialApp(
  theme: buildCoconutThemeData(variant: variant),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

double _contrast(Color a, Color b) {
  final x = a.computeLuminance() + .05;
  final y = b.computeLuminance() + .05;
  return x > y ? x / y : y / x;
}

Color _textColor(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style!.color!;

BoxDecoration _decoration(WidgetTester tester, Type widget) =>
    tester
            .widget<Container>(find.descendant(of: find.byType(widget), matching: find.byType(Container)).first)
            .decoration!
        as BoxDecoration;

void main() {
  for (final variant in CoconutThemeVariant.values) {
    final colors = resolveCoconutThemeExtension(variant: variant).colors;

    group(variant.name, () {
      testWidgets('SafetyListCard draws homeSurface r20 with a divider between rows', (tester) async {
        await tester.pumpWidget(_app(variant, const SafetyListCard(rows: [Text('a'), Text('b'), Text('c')])));
        expect(find.byType(Divider), findsNWidgets(2));
        final box = _decoration(tester, SafetyListCard);
        expect(box.color, colors.homeSurface);
        expect(box.borderRadius, BorderRadius.circular(20));
      });

      testWidgets('SafetyChoiceRow wraps a long title instead of shrinking it and fires onTap', (tester) async {
        var taps = 0;
        const title = 'Create a new wallet on your signing device with a fresh mnemonic';
        await tester.pumpWidget(
          _app(
            variant,
            SizedBox(width: 320, child: SafetyChoiceRow(title: title, subtitle: 'sub', onTap: () => taps++)),
          ),
        );
        expect(find.ancestor(of: find.text(title), matching: find.byType(FittedBox)), findsNothing);
        expect(tester.getSize(find.text(title)).height, greaterThan(20)); // 두 줄
        expect(_textColor(tester, title), colors.primaryText);
        expect(_textColor(tester, 'sub'), colors.secondaryText);
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });

      testWidgets('SafetyActionPill uses warningText on warningSurface with readable contrast', (tester) async {
        await tester.pumpWidget(_app(variant, const SafetyActionPill(text: 'Review')));
        final bg = _decoration(tester, SafetyActionPill).color!;
        expect(bg, colors.warningSurface);
        expect(_textColor(tester, 'Review'), colors.warningText);
        expect(_contrast(colors.warningText, bg), greaterThanOrEqualTo(4.5));
      });

      testWidgets('SafetyIconCircle is a circle of the given size', (tester) async {
        await tester.pumpWidget(
          _app(
            variant,
            Center(child: SafetyIconCircle(size: 36, background: colors.dangerSurface, icon: const SizedBox())),
          ),
        );
        expect(tester.getSize(find.byType(SafetyIconCircle)), const Size(36, 36));
      });

      testWidgets('SafetyNumberedRow is bold only when it has a description', (tester) async {
        await tester.pumpWidget(
          _app(
            variant,
            const Column(
              children: [
                SafetyNumberedRow(number: 1, title: 'Plain'),
                SafetyNumberedRow(number: 2, title: 'Titled', description: 'More'),
              ],
            ),
          ),
        );
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(tester.widget<Text>(find.text('Plain')).style!.fontWeight, isNot(FontWeight.w700));
        expect(tester.widget<Text>(find.text('Titled')).style!.fontWeight, FontWeight.w700);
        expect(_textColor(tester, 'More'), colors.secondaryText);
        expect(_textColor(tester, '1'), colors.background);
      });

      testWidgets('SafetyStatusBanner shows its link only with a handler', (tester) async {
        var links = 0;
        await tester.pumpWidget(
          _app(
            variant,
            Column(
              children: [
                SafetyStatusBanner(
                  background: colors.dangerSurface,
                  iconPath: 'assets/svg/common/state/triangle-warning.svg',
                  iconColor: colors.danger,
                  title: 'Title',
                  body: 'Body',
                  linkText: 'Review',
                  onLink: () => links++,
                ),
                SafetyStatusBanner(
                  background: colors.successSurface,
                  iconPath: 'assets/svg/brand/motifs/shield-check.svg',
                  iconColor: colors.success,
                  title: 'Done',
                  body: 'Body 2',
                ),
              ],
            ),
          ),
        );
        expect(find.byType(CoconutUnderlinedButton), findsOneWidget);
        expect(_textColor(tester, 'Body'), colors.primaryText);
        expect(_contrast(colors.primaryText, colors.dangerSurface), greaterThanOrEqualTo(4.5));
        await tester.tap(find.text('Review'));
        expect(links, 1);
      });

      testWidgets('SafetySectionTitle is a header', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(variant, const SafetySectionTitle('Section')));
        expect(tester.getSemantics(find.text('Section')), matchesSemantics(label: 'Section', isHeader: true));
        expect(_textColor(tester, 'Section'), colors.primaryText);
        handle.dispose();
      });
    });
  }
}
