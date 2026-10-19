import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app/router/feature_entry_routes.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/analytics/analytics_screen_observer.dart';
import 'package:coconut_wallet/app/providers/app_providers.dart';
import 'package:coconut_wallet/app/router/app_routes.dart';
import 'package:coconut_wallet/app/theme/app_cupertino_theme.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/constants/new_home_flag.dart';
import 'package:coconut_wallet/screens/home/home_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_connectivity_service.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/routes/route_observer.dart';
import 'package:coconut_wallet/screens/home/wallet_home_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/onboarding/start_screen.dart';
import 'package:coconut_wallet/app/deep_link/deep_link_listener.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
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
  int _homePage = 0;

  final RealmManager _realmManager = RealmManager();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AnalyticsScreenObserver _analyticsScreenObserver = AnalyticsScreenObserver(
    logScreenView: _logScreenView,
    nameExtractor: _extractAnalyticsScreenName,
  );

  @override
  void initState() {
    super.initState();
    _saveMigratedWalletIds();
    BitBox02ConnectivityService.startMonitoring();
    TrezorConnectivityService.startMonitoring();
  }

  @override
  void dispose() {
    BitBox02ConnectivityService.stopMonitoring();
    TrezorConnectivityService.stopMonitoring();
    super.dispose();
  }

  void _logScreenView(String screenName) {
    if (!CoconutWalletApp.kIsFirebaseAnalyticsUsed) return;
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) return;
    navigatorContext.read<AnalyticsService>().logScreenView(screenName: screenName);
  }

  String? _extractAnalyticsScreenName(RouteSettings settings) {
    if (settings.name == Navigator.defaultRouteName) {
      return switch (_appEntryFlow) {
        AppEntryFlow.splash => AnalyticsScreenNames.splash,
        AppEntryFlow.pinCheck => AnalyticsScreenNames.pinCheck,
        AppEntryFlow.main =>
          kUseNewHome && _homePage == 1 ? AnalyticsScreenNames.allFeatures : AnalyticsScreenNames.walletHome,
      };
    }
    return analyticsRouteScreenName(settings);
  }

  Future<void> _saveMigratedWalletIds() async {
    // RealmManager는 State 필드 초기화 시 Realm을 동기적으로 open하며,
    // Realm이 반환되는 시점에는 migration callback도 완료된 상태입니다.
    final walletIds = _realmManager.migratedWalletIds;
    if (walletIds.isEmpty) return;
    await SharedPrefsRepository().addWalletIdsWithUnacknowledgedOlderToAfterBackupUpdate(walletIds);
  }

  void _onHomePageChanged(int page) {
    if (_homePage == page) return;
    _homePage = page;
    _analyticsScreenObserver.refreshScreenName();
  }

  /// startSplash 완료 콜백
  void _completeSplash(AppEntryFlow appEntryFlow) {
    setState(() {
      _appEntryFlow = appEntryFlow;
      _homePage = 0;
    });
    _analyticsScreenObserver.refreshScreenName();
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
                return CoconutAppTheme(
                  variant: variant,
                  materialTheme: materialTheme,
                  cupertinoTheme: cupertinoTheme,
                  child:
                      _appEntryFlow != AppEntryFlow.main
                          ? currentChild
                          : AppGuard(child: DeepLinkListener(navigatorKey: _navigatorKey, child: currentChild)),
                );
              },
              navigatorObservers: [
                routeObserver,
                FeatureEntryRoutes.instance,
                if (CoconutWalletApp.kIsFirebaseAnalyticsUsed) _analyticsScreenObserver,
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
                      ? (kUseNewHome ? HomeScreen(onPageChanged: _onHomePageChanged) : const WalletHomeScreen())
                      : CustomLoadingOverlay(
                        child: PinCheckScreen(
                          appEntrance: true,
                          onComplete: () {
                            setState(() {
                              _appEntryFlow = AppEntryFlow.main;
                              _homePage = 0;
                            });
                            _analyticsScreenObserver.refreshScreenName();
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

/// Interpolates colors on one route tree, preserving navigation and input state.
class CoconutAppTheme extends StatefulWidget {
  final CoconutThemeVariant variant;
  final ThemeData materialTheme;
  final CupertinoThemeData cupertinoTheme;
  final Widget child;

  const CoconutAppTheme({
    super.key,
    required this.variant,
    required this.materialTheme,
    required this.cupertinoTheme,
    required this.child,
  });

  @override
  State<CoconutAppTheme> createState() => _CoconutAppThemeState();
}

class _CoconutAppThemeState extends State<CoconutAppTheme> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late ThemeDataTween _theme;
  bool _reduceMotion = false;

  ThemeData get _current => _theme.transform(Curves.easeInOut.transform(_controller.value));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);
    _theme = ThemeDataTween(begin: widget.materialTheme, end: widget.materialTheme);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) _controller.value = 1;
  }

  @override
  void didUpdateWidget(CoconutAppTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (widget.variant != oldWidget.variant) {
      _theme = ThemeDataTween(begin: _current, end: widget.materialTheme);
      if (_reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final material = _current;
      final colors = material.extension<CoconutThemeExtension>()!.colors;
      final text = widget.cupertinoTheme.textTheme;
      final cupertino = widget.cupertinoTheme.copyWith(
        brightness: material.brightness,
        primaryColor: colors.primary,
        scaffoldBackgroundColor: colors.background,
        barBackgroundColor: colors.background,
        textTheme: text.copyWith(
          primaryColor: colors.primaryText,
          textStyle: text.textStyle.copyWith(color: colors.primaryText),
          navTitleTextStyle: text.navTitleTextStyle.copyWith(color: colors.primaryText),
          actionTextStyle: text.actionTextStyle.copyWith(color: colors.primaryText),
        ),
      );
      return Theme(
        data: material,
        child: CupertinoTheme(
          data: cupertino,
          child: DefaultTextStyle(
            style: cupertino.textTheme.textStyle,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: buildSystemBarStyle(backgroundColor: colors.background, brightness: material.brightness),
              child: child!,
            ),
          ),
        ),
      );
    },
  );
}
