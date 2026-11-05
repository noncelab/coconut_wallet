import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    font.addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    font.addFont(rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
    await font.load();
  });

  final sheet = find.byWidgetPredicate((widget) => widget is Material && widget.elevation == 4);

  Future<BuildContext> pumpHome(
    WidgetTester tester, {
    required Size size,
    required double top,
    required double bottom,
    CoconutThemeVariant variant = CoconutThemeVariant.dark,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
    tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
    addTearDown(tester.view.reset);
    late BuildContext home;
    await tester.pumpWidget(
      Provider<AnalyticsService>.value(
        value: AnalyticsService(null, true),
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: variant),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
          routes: {AppRouteNames.walletAddScanner: (_) => const Scaffold(body: Text('manual import opened'))},
          home: Builder(
            builder: (context) {
              home = context;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    return home;
  }

  for (final variant in [CoconutThemeVariant.dark, CoconutThemeVariant.coconutTheme]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('fold source sheet keeps manual import above gestures ${variant.name} $scale', (tester) async {
        LocaleSettings.setLocaleSync(AppLocale.de);
        addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
        final home = await pumpHome(
          tester,
          size: const Size(852, 883),
          top: 55.8,
          bottom: 32,
          variant: variant,
          scale: scale,
        );
        WalletAddDialog.showTopSheet(home, WalletAddDialogMode.watchOnlySource);
        await tester.pumpAndSettle();
        final description = find.text(t.wallet_add_scanner_screen.self_description);
        final manual = find.text(WalletImportSource.extendedPublicKey.displayName);
        for (final size in [const Size(852, 883), const Size(443, 994), const Size(852, 883)]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(tester.getBottomLeft(sheet).dy, lessThanOrEqualTo(size.height - 32));
          for (final vendor in topSheetWalletOptions) {
            final label = find.text(vendor.displayName);
            final tile = find.ancestor(of: label, matching: find.byType(ShrinkAnimationButton)).first;
            expect(tester.getBottomLeft(label).dy, lessThanOrEqualTo(tester.getBottomLeft(tile).dy - 8));
            // 상자 안에서 줄이 반쯤 잘려 그려지지 않는다.
            expect(
              tester.renderObject<RenderParagraph>(label).textSize.height,
              lessThanOrEqualTo(tester.getSize(label).height),
            );
          }
          await tester.ensureVisible(description);
          await tester.pumpAndSettle();
          expect(tester.getBottomLeft(description).dy, lessThanOrEqualTo(size.height - 32));
          expect(description.hitTestable(), findsOneWidget);
          expect(manual.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.tap(manual);
        await tester.pumpAndSettle();
        expect(find.text('manual import opened'), findsOneWidget);
      });
    }
  }

  testWidgets('phone top sheets keep their natural height', (tester) async {
    final home = await pumpHome(tester, size: const Size(393, 852), top: 59, bottom: 34);
    for (final mode in WalletAddDialogMode.values) {
      WalletAddDialog.showTopSheet(home, mode);
      await tester.pumpAndSettle();
      final content = find.descendant(of: sheet, matching: find.byType(Column)).first;
      expect(tester.getTopLeft(sheet).dy, kToolbarHeight + 59 - 15);
      expect(tester.getSize(sheet).height, tester.getSize(content).height + 32);
      Navigator.pop(home);
      await tester.pumpAndSettle();
    }
  });
}
