import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/services/feature/feature_launcher.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/app/router/feature_entry_routes.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _icon(String asset) => find.byWidgetPredicate(
  (widget) => widget is SvgPicture && (widget.bytesLoader as SvgAssetLoader).assetName == asset,
);

Widget _page(String title, {VoidCallback? onNext}) => Builder(
  builder:
      (context) => Scaffold(
        appBar: CoconutAppBar.build(context: context, title: title),
        body: Center(child: TextButton(onPressed: onNext, child: const Text('next'))),
      ),
);

void main() {
  testWidgets('the first page opened from a feature shows a close button and pages after it show back', (tester) async {
    late BuildContext home;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        navigatorObservers: [FeatureEntryRoutes.instance],
        home: Builder(
          builder: (context) {
            home = context;
            return const Scaffold();
          },
        ),
      ),
    );

    final navigator = Navigator.of(home);
    FeatureEntryRoutes.instance.launching(
      () => navigator.push(
        MaterialPageRoute(
          builder:
              (_) => _page('entry', onNext: () => navigator.push(MaterialPageRoute(builder: (_) => _page('inner')))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_icon(CommonActionIconPath.close), findsWidgets);
    expect(_icon(CommonNavigationIconPath.arrowBack), findsNothing);

    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    expect(find.text('inner'), findsOneWidget);
    expect(_icon(CommonNavigationIconPath.arrowBack), findsWidgets);
    expect(_icon(CommonActionIconPath.close), findsNothing);

    navigator.pop();
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.push(MaterialPageRoute(builder: (_) => _page('plain')));
    await tester.pumpAndSettle();
    expect(_icon(CommonNavigationIconPath.arrowBack), findsWidgets);
    expect(_icon(CommonActionIconPath.close), findsNothing);
  });

  testWidgets('a named route launched through the feature launcher in a CupertinoApp shows a close button', (
    tester,
  ) async {
    late BuildContext home;
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(),
        navigatorObservers: [FeatureEntryRoutes.instance],
        localizationsDelegates: const [DefaultMaterialLocalizations.delegate, DefaultWidgetsLocalizations.delegate],
        routes: {'/memo': (_) => Theme(data: buildCoconutThemeData(), child: _page('memo'))},
        home: Builder(
          builder: (context) {
            home = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final feature = FeatureItem(
      id: 'memo',
      label: () => 'memo',
      launch: (context, _) => Navigator.pushNamed(context, '/memo'),
    );
    FeatureLauncher(wallets: () => const [], pickWallet: (_, __) async => null).launch(home, feature);
    await tester.pumpAndSettle();

    expect(find.text('memo'), findsOneWidget);
    expect(_icon(CommonActionIconPath.close), findsWidgets);
    expect(_icon(CommonNavigationIconPath.arrowBack), findsNothing);
  });
}
