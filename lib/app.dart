import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app/providers/app_providers.dart';
import 'package:coconut_wallet/app/router/app_routes.dart';
import 'package:coconut_wallet/app/theme/app_cupertino_theme.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/routes/route_observer.dart';
import 'package:coconut_wallet/screens/home/wallet_home_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/onboarding/start_screen.dart';
import 'package:coconut_wallet/widgets/deep_link_listener.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

enum AppEntryFlow { splash, main, pinCheck }

class CoconutWalletApp extends StatefulWidget {
  static late String kMempoolHost;
  static late String kFaucetHost;
  static late NetworkType kNetworkType;
  static late bool kIsFirebaseAnalyticsUsed;

  const CoconutWalletApp({super.key});

  @override
  State<CoconutWalletApp> createState() => _CoconutWalletAppState();
}

class _CoconutWalletAppState extends State<CoconutWalletApp> {
  /// 0 = splash, 1 = main, 2 = pin check
  AppEntryFlow _appEntryFlow = AppEntryFlow.splash;

  final RealmManager _realmManager = RealmManager();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// startSplash 완료 콜백
  void _completeSplash(AppEntryFlow appEntryFlow) {
    setState(() {
      _appEntryFlow = appEntryFlow;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(
        realmManager: _realmManager,
        isMainFlow: _appEntryFlow == AppEntryFlow.main,
        isFirebaseAnalyticsUsed: CoconutWalletApp.kIsFirebaseAnalyticsUsed,
        networkType: CoconutWalletApp.kNetworkType,
      ),
      child: TranslationProvider(
        child: ValueListenableBuilder<CoconutThemeVariant>(
          valueListenable: CoconutThemeController.variantNotifier,
          builder: (context, variant, _) {
            final materialTheme = buildCoconutThemeData(variant: variant);
            final cupertinoTheme = buildAppCupertinoTheme(variant: variant);

            return CupertinoApp(
              navigatorKey: _navigatorKey,
              builder: (context, child) {
                final currentChild = child ?? const SizedBox.shrink();
                if (_appEntryFlow != AppEntryFlow.main) {
                  return Theme(data: materialTheme, child: currentChild);
                }
                return Theme(
                  data: materialTheme,
                  child: AppGuard(child: DeepLinkListener(navigatorKey: _navigatorKey, child: currentChild)),
                );
              },
              navigatorObservers: [
                routeObserver,
                if (CoconutWalletApp.kIsFirebaseAnalyticsUsed)
                  FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
              ],
              localizationsDelegates: const [
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
                DefaultCupertinoLocalizations.delegate,
              ],
              debugShowCheckedModeBanner: false,
              theme: cupertinoTheme,
              home:
                  _appEntryFlow == AppEntryFlow.splash
                      ? StartScreen(onComplete: _completeSplash)
                      : _appEntryFlow == AppEntryFlow.main
                      ? const WalletHomeScreen()
                      : CustomLoadingOverlay(
                        child: PinCheckScreen(
                          appEntrance: true,
                          onComplete: () {
                            setState(() {
                              _appEntryFlow = AppEntryFlow.main;
                            });
                          },
                        ),
                      ),
              routes: buildAppRoutes(),
            );
          },
        ),
      ),
    );
  }
}
