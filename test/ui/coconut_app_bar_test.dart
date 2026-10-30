import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final variant in [CoconutThemeVariant.dark, CoconutThemeVariant.light]) {
    for (final withNext in [false, true]) {
      testWidgets('${variant.name} ${withNext ? 'buildWithNext' : 'build'} sheet close layout and hit area', (
        tester,
      ) async {
        var presses = 0;
        await _openAppBar(tester, variant: variant, withNext: withNext, isBottom: true, onBackPressed: () => presses++);

        final action = find.byType(CoconutAppBarActionButton).hitTestable().first;
        final icon = find.descendant(of: action, matching: find.byType(SvgPicture));
        final sheetRect = tester.getRect(find.byKey(const ValueKey('sheet')));
        final actionRect = tester.getRect(action);
        final iconRect = tester.getRect(icon);
        expect(actionRect.size, const Size(48, 48));
        expect(iconRect.size, const Size(24, 24));
        expect(actionRect.center - sheetRect.topLeft, const Offset(24, 50));
        expect(iconRect.center, actionRect.center);
        expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 60);
        expect(
          tester.widget<SvgPicture>(icon).colorFilter,
          ColorFilter.mode(resolveCoconutThemeExtension(variant: variant).colors.primaryText, BlendMode.srcIn),
        );

        // Exercise the touch target outside the visible 24dp glyph.
        await tester.tapAt(actionRect.topLeft + const Offset(2, 20));
        await tester.pump();
        expect(presses, 1);
        expect(tester.takeException(), isNull);
      });
    }

    for (final isBottom in [false, true]) {
      testWidgets('${variant.name} ${isBottom ? 'sheet' : 'page'} back arrow keeps its original position', (
        tester,
      ) async {
        var presses = 0;
        await _openAppBar(
          tester,
          variant: variant,
          isBottom: isBottom,
          isBackButton: true,
          onBackPressed: () => presses++,
        );
        final action = find.byType(CoconutAppBarActionButton).hitTestable().first;
        final actionRect = tester.getRect(action);
        final toolbarRect = tester.getRect(find.byType(AppBar));
        expect(actionRect.size, const Size(48, 48));
        expect(actionRect.center.dx - toolbarRect.left, 24);
        expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, isBottom ? 60 : 56);
        await tester.tap(action);
        await tester.pump();
        expect(presses, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<void> _openAppBar(
  WidgetTester tester, {
  required CoconutThemeVariant variant,
  required bool isBottom,
  required VoidCallback onBackPressed,
  bool withNext = false,
  bool isBackButton = false,
}) async {
  AppBar appBar(BuildContext context) =>
      withNext
          ? CoconutAppBar.buildWithNext(
            context: context,
            title: 'Title',
            isBottom: isBottom,
            nextButtonTitle: 'Next',
            onNextPressed: () {},
            onBackPressed: onBackPressed,
          )
          : CoconutAppBar.build(
            context: context,
            title: 'Title',
            isBottom: isBottom,
            isBackButton: isBackButton,
            onBackPressed: onBackPressed,
          );

  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: variant),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  if (isBottom) {
                    showModalBottomSheet<void>(
                      context: context,
                      builder:
                          (sheetContext) => SizedBox(
                            key: const ValueKey('sheet'),
                            height: 240,
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                appBar(sheetContext),
                                const Expanded(child: SizedBox.shrink()),
                              ],
                            ),
                          ),
                    );
                  } else {
                    Navigator.of(
                      context,
                    ).push<void>(MaterialPageRoute(builder: (pageContext) => Scaffold(appBar: appBar(pageContext))));
                  }
                },
                child: const Text('Open'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
