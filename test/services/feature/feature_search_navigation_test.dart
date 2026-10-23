import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/model/feature/feature_navigation_target.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/all_features_screen.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/screens/settings/number_format_bottom_sheet.dart';
import 'package:coconut_wallet/screens/settings/unit_bottom_sheet.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/feature/feature_launcher.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/widgets/common/buttons/button_group.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mock/wallet_mock.dart';

class _Preferences extends ChangeNotifier implements PreferenceProvider {
  int writes = 0;
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  FiatCode get selectedFiat => FiatCode.USD;
  @override
  String get language => 'ko';
  @override
  NumberFormatPreset get numberFormatPreset => NumberFormatPreset.dotDecimal;
  @override
  bool get isManualUtxoSelectionMode => false;
  @override
  Future<void> setManualUtxoSelectionMode(bool value) async {
    writes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyWalletPreferences implements WalletPreferencesRepository {
  @override
  bool hasWalletPreferences() => false;
  @override
  List<int> getWalletOrder() => [];
  @override
  List<int> getFavoriteWalletIds() => [];
  @override
  List<int> getExcludedWalletIds() => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthProvider {
  bool pin = false;
  bool biometrics = false;
  bool devicePasscode = true;
  int passcodeChecks = 0;
  @override
  bool get isSetPin => pin;
  @override
  bool get canCheckBiometrics => biometrics;
  @override
  bool get isSetBiometrics => false;
  @override
  Future<bool> isDevicePasscodeSet() async {
    passcodeChecks++;
    return devicePasscode;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Preferences preferences;
  late _Auth auth;
  late List<WalletItemBase> wallets;
  late List<RouteSettings> routes;
  late List<List<int>> choices;
  late List<String> recents;
  final navigator = GlobalKey<NavigatorState>();
  const captureKey = ValueKey('search-destination-capture');

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    NetworkType.setNetworkType(NetworkType.regtest);
    preferences = _Preferences();
    auth = _Auth();
    wallets = [WalletMock.createSingleSigWalletItem(id: 1), WalletMock.createSingleSigWalletItem(id: 2)];
    routes = [];
    choices = [];
    recents = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    int? selectedWallet = 2,
    CoconutThemeVariant variant = CoconutThemeVariant.dark,
    bool capture = false,
    PreferenceProvider? preferenceProvider,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: preferenceProvider ?? preferences),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          Provider<AnalyticsService>(create: (_) => AnalyticsService(null, true)),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: buildCoconutThemeData(variant: variant),
          builder: capture ? (_, child) => RepaintBoundary(key: captureKey, child: child!) : null,
          onGenerateRoute: (settings) {
            routes.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Destination')),
            );
          },
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: AllFeaturesScreen(
                    registry: FeatureRegistry.builtin(),
                    isAvailable: (item) => item.isAvailable?.call(context) ?? true,
                    saveRecentIds: (ids) => recents = ids,
                    onLaunch:
                        (context, item) => unawaited(
                          FeatureLauncher(
                            wallets: () => wallets,
                            pickWallet: (_, candidates) async {
                              choices.add(candidates);
                              return selectedWallet;
                            },
                          ).launch(context, item),
                        ),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> searchTap(WidgetTester tester, String query, String parentId) async {
    await tester.enterText(find.byKey(const Key('all-features-search')), query);
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('all-features-item-$parentId')));
    await tester.pumpAndSettle();
  }

  Future<PreferenceProvider> numberFormatPreferences(AppLocale locale) async {
    SharedPreferences.setMockInitialValues({
      SharedPrefKeys.kLanguage: locale.languageCode,
      SharedPrefKeys.kNumberFormatPreset: 'dotDecimal',
    });
    await SharedPrefsRepository().init();
    final electrum = ElectrumServerProvider();
    final explorer = BlockExplorerProvider();
    final provider = PreferenceProvider(_EmptyWalletPreferences(), electrum, explorer);
    addTearDown(() {
      provider.dispose();
      electrum.dispose();
      explorer.dispose();
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
      LocaleSettings.setLocaleSync(AppLocale.ko);
      NetworkType.setNetworkType(NetworkType.regtest);
    });
    return provider;
  }

  Future<ByteData> pixels(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    return (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        image.dispose();
      }
    }))!;
  }

  for (final variant in CoconutThemeVariant.values) {
    for (final pinEnabled in [false, true]) {
      testWidgets('PIN search highlight stays inside its settings card ($variant, PIN=$pinEnabled)', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(414, 896);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        auth.pin = pinEnabled;
        auth.biometrics = true;
        await pump(tester, variant: variant, capture: true);
        await searchTap(tester, 'PIN', FeatureIds.appSettings);

        final target = find.byKey(const ValueKey('app-settings-focus-pin'));
        final opacity = find.descendant(of: target, matching: find.byType(AnimatedOpacity));
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
        final card = find.ancestor(of: target, matching: find.byType(ButtonGroup));
        final cardContainer = find.descendant(of: card, matching: find.byType(Container)).first;
        final decoration = tester.widget<Container>(cardContainer).decoration! as BoxDecoration;
        final cardRect = tester.getRect(cardContainer);
        final cardShape = (decoration.borderRadius! as BorderRadius).toRRect(cardRect);
        final targetRect = tester.getRect(target);
        final highlighted = await pixels(tester);

        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
        expect(tester.getRect(target), targetRect);
        final normal = await pixels(tester);
        var outsideSamples = 0;
        var changedOutside = 0;
        var changedInside = 0;
        for (var y = targetRect.top.ceil(); y < targetRect.bottom.floor(); y++) {
          for (var x = targetRect.left.ceil(); x < targetRect.right.floor(); x++) {
            final point = Offset(x + 0.5, y + 0.5);
            final changed = highlighted.getUint32((y * 414 + x) * 4) != normal.getUint32((y * 414 + x) * 4);
            // Exclude the actual card's antialiased edge, not the highlight's own shape.
            if (!cardShape.inflate(1).contains(point)) {
              outsideSamples++;
              if (changed) changedOutside++;
            } else if (cardShape.deflate(2).contains(point) && changed) {
              changedInside++;
            }
          }
        }
        expect(outsideSamples, greaterThan(20));
        expect(changedOutside, 0, reason: 'Highlight must not paint into the background outside the card.');
        expect(changedInside, greaterThan(100), reason: 'The target must actually be highlighted.');
        expect(auth.pin, pinEnabled);
        expect(preferences.writes, 0);
      });
    }
  }

  testWidgets('unit search opens the actual sheet directly without changing the setting', (tester) async {
    await pump(tester);
    await searchTap(tester, 'sats', FeatureIds.appSettings);
    expect(find.byType(UnitBottomSheet), findsOneWidget);
    expect(find.byType(AppSettingsScreen), findsNothing);
    expect(preferences.currentUnit, BitcoinUnit.btc);
    expect(preferences.writes, 0);
    expect(recents.first, FeatureIds.appSettings);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('all-features-search')), findsOneWidget);
  });

  for (final network in [NetworkType.mainnet, NetworkType.testnet, NetworkType.regtest]) {
    for (final locale in AppLocale.values) {
      testWidgets('number format search persists a selection without a wallet ($network, ${locale.languageCode})', (
        tester,
      ) async {
        NetworkType.setNetworkType(network);
        wallets = [];
        final provider = await numberFormatPreferences(locale);
        await pump(tester, preferenceProvider: provider);
        await searchTap(tester, t.settings_screen.number_format, FeatureIds.appSettings);

        expect(find.byType(NumberFormatBottomSheet), findsOneWidget);
        expect(find.byType(AppSettingsScreen), findsNothing);
        expect(choices, isEmpty);
        expect(routes, isEmpty);
        expect(recents.first, FeatureIds.appSettings);
        expect(provider.numberFormatPreset, NumberFormatPreset.dotDecimal);
        expect(SharedPrefsRepository().getString(SharedPrefKeys.kNumberFormatPreset), 'dotDecimal');

        await tester.tap(find.text('1.234,5678 9012'));
        await tester.pumpAndSettle();
        expect(provider.numberFormatPreset, NumberFormatPreset.commaDecimal);
        expect(SharedPrefsRepository().getString(SharedPrefKeys.kNumberFormatPreset), 'commaDecimal');
        expect(NumberFormatConfig.instance.decimalSeparator, ',');
        expect(NumberFormatConfig.instance.groupingSeparator, '.');
        final selectedRow = find.ancestor(
          of: find.text('1.234,5678 9012'),
          matching: find.byType(SelectableSettingsRow),
        );
        expect(tester.widget<SelectableSettingsRow>(selectedRow).isSelected, isTrue);

        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(NumberFormatBottomSheet), findsNothing);
        expect(find.byKey(const Key('all-features-search')), findsOneWidget);
        expect(navigator.currentState!.canPop(), isFalse);

        await searchTap(tester, t.settings_screen.number_format, FeatureIds.appSettings);
        expect(tester.widget<SelectableSettingsRow>(selectedRow).isSelected, isTrue);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(navigator.currentState!.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('number format search waits for the keyboard and ignores duplicate taps', (tester) async {
    final provider = await numberFormatPreferences(AppLocale.ko);
    wallets = [];
    await pump(tester, preferenceProvider: provider);
    await tester.enterText(find.byKey(const Key('all-features-search')), '숫자 구분');
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    final result = find.byKey(const ValueKey('all-features-item-app_settings'));
    await tester.tap(result);
    await tester.pump();
    await tester.tap(result);
    await tester.pump();
    expect(find.byType(NumberFormatBottomSheet), findsNothing);
    tester.view.viewInsets = const FakeViewPadding(bottom: 80);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(NumberFormatBottomSheet), findsNothing);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byType(NumberFormatBottomSheet), findsOneWidget);
    expect(provider.numberFormatPreset, NumberFormatPreset.dotDecimal);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(NumberFormatBottomSheet), findsNothing);
    expect(navigator.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual UTXO search reveals the row without toggling it', (tester) async {
    await pump(tester);
    await searchTap(tester, t.feature_sub_labels.app_settings_utxo_selection, FeatureIds.appSettings);
    final target = find.byKey(const ValueKey('app-settings-focus-utxoSelection'));
    expect(target, findsOneWidget);
    expect(tester.getRect(target).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(target).bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
    expect(preferences.writes, 0);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
  });

  for (final signed in [true, false]) {
    testWidgets('saved transaction search opens the requested tab ($signed)', (tester) async {
      await pump(tester);
      await searchTap(
        tester,
        signed ? t.feature_sub_labels.transaction_draft_signed : t.feature_sub_labels.transaction_draft_unsigned,
        FeatureIds.transactionDraft,
      );
      expect(routes.single.name, AppRouteNames.transactionDraft);
      expect((routes.single.arguments as TransactionDraftRouteArgs).isSignedTabActive, signed);
    });
  }

  testWidgets('address search preserves explicit wallet choice and child route', (tester) async {
    await pump(tester);
    await searchTap(tester, t.feature_sub_labels.addresses_search, FeatureIds.addresses);
    expect(choices, [
      [1, 2],
    ]);
    expect(routes.single.name, AppRouteNames.addressSearch);
    expect((routes.single.arguments as AddressSearchRouteArgs).id, 2);
    expect(recents.first, FeatureIds.addresses);
  });

  testWidgets('cancelled wallet choice never enters the target', (tester) async {
    await pump(tester, selectedWallet: null);
    await searchTap(tester, t.feature_sub_labels.addresses_search, FeatureIds.addresses);
    expect(choices, [
      [1, 2],
    ]);
    expect(routes, isEmpty);
  });

  for (final isImport in [true, false]) {
    testWidgets('label search opens the requested existing task (import=$isImport)', (tester) async {
      await pump(tester);
      await searchTap(
        tester,
        isImport ? t.label_management_screen.import_title : t.label_management_screen.export_title,
        FeatureIds.labelManagement,
      );
      expect(routes.single.name, isImport ? AppRouteNames.labelImport : AppRouteNames.labelExport);
      if (isImport) {
        final args = routes.single.arguments as LabelImportRouteArgs;
        expect(args.id, isNull);
        expect(args.showImportMemosFromOtherWalletsOption, false);
      } else {
        expect((routes.single.arguments as LabelExportRouteArgs).id, isNull);
      }
    });
  }

  for (final (target, route) in [
    ('electrum', AppRouteNames.electrumServer),
    ('app_info', AppRouteNames.appInfo),
    ('explorer', AppRouteNames.blockExplorer),
  ]) {
    testWidgets('settings search skips the settings list for $target', (tester) async {
      NetworkType.setNetworkType(NetworkType.mainnet);
      await pump(tester);
      final query = FeatureRegistry.builtin().byId('app_settings.$target')!.label();
      await searchTap(tester, query, FeatureIds.appSettings);
      expect(routes.single.name, route);
      expect(find.byType(AppSettingsScreen), findsNothing);
    });
  }

  testWidgets('manual wallet import search reuses the existing public-key import entry', (tester) async {
    await pump(tester);
    await searchTap(tester, t.feature_sub_labels.wallet_add_watch_only_manual, FeatureIds.walletAddWatchOnly);
    expect(routes.single.name, AppRouteNames.walletAddScanner);
    expect(routes.single.arguments, isA<WalletAddScannerRouteArgs>());
    expect(choices, isEmpty);
  });

  for (final watched in [false, true]) {
    testWidgets('address filter destination is scoped to its screen (watched=$watched)', (tester) async {
      await pump(tester);
      await searchTap(
        tester,
        watched ? t.feature_sub_labels.addresses_watched : t.feature_sub_labels.addresses_unused,
        FeatureIds.addresses,
      );
      final arguments = routes.single.arguments as AddressListRouteArgs;
      expect(arguments.id, 2);
      expect(arguments.initialShowOnlyWatchedAddresses, watched ? true : null);
      expect(arguments.initialShowOnlyUnusedAddresses, watched ? null : true);
      expect(preferences.writes, 0);
    });
  }

  for (final target in [WalletInfoTarget.extendedPublicKey, WalletInfoTarget.delete]) {
    testWidgets('sensitive search opens a highlighted row only ($target)', (tester) async {
      await pump(tester);
      await searchTap(
        tester,
        target == WalletInfoTarget.delete
            ? t.feature_sub_labels.wallet_detail_delete
            : t.feature_sub_labels.wallet_detail_xpub,
        FeatureIds.walletDetail,
      );
      expect(routes.single.name, AppRouteNames.walletInfo);
      final arguments = routes.single.arguments as WalletInfoRouteArgs;
      expect(arguments.id, 2);
      expect(arguments.initialTarget, target);
      expect(arguments.showMfpInput, false);
      expect(arguments.highlightMnemonicBackup, false);
    });
  }

  for (final restore in [false, true]) {
    testWidgets('hot wallet search checks the device passcode before direct entry ($restore)', (tester) async {
      await pump(tester);
      await searchTap(
        tester,
        restore ? t.feature_sub_labels.wallet_add_hot_restore : t.feature_sub_labels.wallet_add_hot_create,
        FeatureIds.walletAddHot,
      );
      expect(auth.passcodeChecks, 1);
      expect(routes.single.name, restore ? AppRouteNames.hotWalletRestore : AppRouteNames.hotWalletCreate);
    });
  }

  testWidgets('hot wallet search with no device passcode preserves the setup gate', (tester) async {
    auth.devicePasscode = false;
    await pump(tester);
    await searchTap(tester, t.feature_sub_labels.wallet_add_hot_restore, FeatureIds.walletAddHot);
    expect(auth.passcodeChecks, 1);
    expect(routes, isEmpty);
    expect(find.text(t.wallet_home_screen.hot_wallet_add.device_passcode_required.title), findsOneWidget);
  });

  testWidgets('state-incompatible settings are filtered before selecting the match', (tester) async {
    await pump(tester);
    for (final query in [
      'Face ID',
      t.feature_sub_labels.app_settings_pin_change,
      t.feature_sub_labels.app_settings_explorer,
    ]) {
      await tester.enterText(find.byKey(const Key('all-features-search')), query);
      await tester.pump();
      expect(find.byKey(const ValueKey('all-features-item-app_settings')), findsNothing, reason: query);
    }
    auth.pin = true;
    auth.biometrics = true;
    await tester.enterText(find.byKey(const Key('all-features-search')), 'Face ID');
    await tester.pump();
    expect(find.byKey(const ValueKey('all-features-item-app_settings')), findsOneWidget);
  });

  testWidgets('wallet removed during selection cannot be launched from a stale snapshot', (tester) async {
    FeatureLaunchResult? result;
    var launches = 0;
    final selection = Completer<int?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () async {
                  result = await FeatureLauncher(
                    wallets: () => wallets,
                    pickWallet: (_, __) => selection.future,
                  ).launch(
                    context,
                    FeatureItem(
                      id: 'child',
                      label: () => 'Child',
                      context: FeatureContext.wallet,
                      launch: (_, __) async {
                        launches++;
                      },
                    ),
                  );
                },
                child: const Text('Launch'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Launch'));
    wallets.removeWhere((wallet) => wallet.id == 2);
    selection.complete(2);
    await tester.pump();
    expect(result, FeatureLaunchResult.unavailable);
    expect(launches, 0);
  });
}
