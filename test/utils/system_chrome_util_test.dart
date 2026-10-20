import 'package:coconut_wallet/app/theme/app_cupertino_theme.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/widgets/features/home/home_app_bar.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final useHome in [false, true]) {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final start in [CoconutThemeVariant.dark, CoconutThemeVariant.light]) {
        testWidgets(
          '${useHome ? 'actual HomeAppBar' : 'common AppBar'} $platform $start startup, live switch, sheet and route restore chrome',
          (tester) async {
            debugDefaultTargetPlatformOverride = platform;
            final variant = ValueNotifier(start);
            final navigator = GlobalKey<NavigatorState>();
            addTearDown(() {
              debugDefaultTargetPlatformOverride = null;
              variant.dispose();
              tester.view.resetPadding();
            });
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
            await tester.pumpWidget(
              ValueListenableBuilder<CoconutThemeVariant>(
                valueListenable: variant,
                builder: (context, value, _) {
                  final theme = buildCoconutThemeData(variant: value);
                  return CupertinoApp(
                    navigatorKey: navigator,
                    localizationsDelegates: const [DefaultMaterialLocalizations.delegate],
                    theme: buildAppCupertinoTheme(variant: value),
                    builder:
                        (context, child) => Theme(
                          data: theme,
                          child: AnnotatedRegion<SystemUiOverlayStyle>(
                            value: buildSystemBarStyle(
                              backgroundColor: theme.scaffoldBackgroundColor,
                              brightness: theme.brightness,
                            ),
                            child: child!,
                          ),
                        ),
                    home: Builder(
                      builder:
                          (context) => Scaffold(
                            appBar: useHome ? null : CoconutAppBar.build(context: context, title: 'Chrome'),
                            body:
                                useHome
                                    ? CustomScrollView(
                                      slivers: [
                                        HomeAppBar(
                                          networkStatus: NetworkStatus.online,
                                          showReconnected: false,
                                          isSyncing: false,
                                          isArranging: false,
                                          addWalletButtonLink: LayerLink(),
                                          onArrangeDone: () {},
                                          onAddWallet: () {},
                                          onSettings: () {},
                                        ),
                                        const SliverToBoxAdapter(child: SizedBox(height: 900)),
                                      ],
                                    )
                                    : const SizedBox.expand(),
                          ),
                    ),
                  );
                },
              ),
            );

            void expectChrome() {
              final brightness = CoconutThemeController.brightnessOf(variant.value);
              final renderedStyles = tester.layers.whereType<AnnotatedRegionLayer<SystemUiOverlayStyle>>();
              expect(renderedStyles, isNotEmpty);
              for (final layer in renderedStyles) {
                expect(layer.value.statusBarBrightness, brightness);
                expect(
                  layer.value.statusBarIconBrightness,
                  brightness == Brightness.dark ? Brightness.light : Brightness.dark,
                );
              }
              final style = SystemChrome.latestStyle!;
              expect(style.statusBarBrightness, brightness);
              expect(style.statusBarIconBrightness, brightness == Brightness.dark ? Brightness.light : Brightness.dark);
              expect(style.statusBarColor, Colors.transparent);
              if (platform == TargetPlatform.android) {
                expect(style.systemNavigationBarIconBrightness, style.statusBarIconBrightness);
                expect(
                  style.systemNavigationBarColor,
                  resolveCoconutThemeExtension(variant: variant.value).colors.background,
                );
              }
            }

            await tester.pumpAndSettle();
            expectChrome();
            for (final next in [
              CoconutThemeVariant.coconutTheme,
              CoconutThemeVariant.dark,
              CoconutThemeVariant.light,
              CoconutThemeVariant.dark,
            ]) {
              final context = tester.element(find.byType(Scaffold).first);
              showModalBottomSheet<void>(
                context: context,
                builder:
                    (context) => SizedBox(
                      height: 200,
                      child: Scaffold(
                        appBar: CoconutAppBar.buildWithNext(
                          title: 'Sheet',
                          context: context,
                          onNextPressed: () {},
                          isBottom: true,
                        ),
                      ),
                    ),
              );
              await tester.pumpAndSettle();
              variant.value = next;
              await tester.pumpAndSettle();
              expectChrome();
              navigator.currentState!.pop();
              await tester.pumpAndSettle();
              expectChrome();
              navigator.currentState!.push(
                CupertinoPageRoute<void>(builder: (context) => const Scaffold(body: SizedBox.expand())),
              );
              await tester.pumpAndSettle();
              expectChrome();
              navigator.currentState!.pop();
              await tester.pumpAndSettle();
              expectChrome();
              expect(tester.takeException(), isNull);
              final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
              expect(appBar.backgroundColor, Colors.transparent);
              expect(find.byType(BackdropFilter), findsOneWidget);
            }
            debugDefaultTargetPlatformOverride = null;
          },
        );
      }
    }
  }
}
