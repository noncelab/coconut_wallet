import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/constants/wallet_skins.dart';
import 'package:coconut_wallet/utils/custom_wallet_icons.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_appearance_view_model.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/wallet_appearance_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_appearance_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_photo_crop_screen.dart';
import 'package:coconut_wallet/services/wallet/wallet_background_photo_store.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mock/wallet_mock.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4z8AARAAI/gH/xp559wAAAABJRU5ErkJggg==',
);

class _WalletProvider extends ChangeNotifier implements WalletProvider {
  _WalletProvider([WalletItemBase? wallet]) : wallet = wallet ?? WalletMock.createSingleSigWalletItem();

  final WalletItemBase wallet;
  String? savedName;
  (int, int)? savedPalette;
  Completer<void>? nameUpdate;
  Balance balance = Balance(0, 0);

  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  String? resolveWalletNameConflict({
    required String desiredName,
    required String descriptor,
    required bool isSingleSig,
    int? excludeWalletId,
  }) => desiredName == 'taken' ? 'taken (2)' : desiredName;
  @override
  Future<void> updateWalletName(int id, String name) async {
    savedName = name;
    final gate = nameUpdate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> updateWalletPalette(int id, int iconIndex, int colorIndex) async =>
      savedPalette = (iconIndex, colorIndex);
  @override
  Balance getWalletBalance(int walletId) => balance;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SinglesigWalletItem _hotWallet() {
  final base = WalletMock.createSingleSigWalletItem();
  return SinglesigWalletItem(
    id: base.id,
    name: base.name,
    colorIndex: 0,
    iconIndex: 0,
    descriptor: base.descriptor,
    hotWalletMetadata: HotWalletMetadata(
      walletId: base.id,
      secureStorageKey: 'key',
      masterFingerprint: 'D45AA182',
      derivationPath: "m/84'/1'/0'",
      accountIndex: 0,
      backupVerified: true,
      enterPassphraseWhenSigning: false,
      createdAt: DateTime(2026),
    ),
  );
}

class _PreferenceProvider extends Fake implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
}

class _PopObserver extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

void main() {
  late Directory tempDir;
  late WalletAppearanceProvider appearances;
  late _WalletProvider walletProvider;

  setUpAll(() async {
    final font = FontLoader('Pretendard');
    font.addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    font.addFont(rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
    await font.load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    tempDir = await Directory.systemTemp.createTemp('wallet_appearance_screen_test');
    appearances = WalletAppearanceProvider(
      repository: WalletAppearanceRepository(prefs),
      photoStore: WalletBackgroundPhotoStore(baseDirectory: () async => tempDir),
    );
    await appearances.init();
    walletProvider = _WalletProvider();
  });

  tearDown(() async {
    appearances.dispose();
    await tempDir.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    PhotoPicker? pickPhoto,
    CoconutThemeVariant variant = CoconutThemeVariant.dark,
    TextScaler textScaler = TextScaler.noScaling,
    Size logicalSize = const Size(390, 1400),
    bool settle = true,
    NavigatorObserver? observer,
  }) async {
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => buildCoconutThemeData(variant: CoconutThemeVariant.dark));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
          InheritedProvider<PreferenceProvider>.value(value: _PreferenceProvider()),
          ChangeNotifierProvider<WalletAppearanceProvider>.value(value: appearances),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: variant),
          navigatorObservers: [if (observer != null) observer],
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child ?? const SizedBox.shrink(),
              ),
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WalletAppearanceScreen(id: walletProvider.wallet.id, pickPhoto: pickPhoto),
                        ),
                      ),
                  child: const Text('open'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  for (final variant in [CoconutThemeVariant.dark, CoconutThemeVariant.coconutTheme]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('fold keyboard keeps editing and completion reachable ${variant.name} $scale', (tester) async {
        walletProvider = _WalletProvider(_hotWallet());
        await open(tester, variant: variant, textScaler: TextScaler.linear(scale), logicalSize: const Size(841, 874));
        final field = find.byType(EditableText);
        await tester.ensureVisible(field);
        await tester.enterText(field, 'Fold savings');
        await tester.pumpAndSettle();
        final editable = tester.widget<EditableText>(field);

        for (final size in [const Size(841, 874), const Size(412, 915), const Size(841, 874)]) {
          tester.view.physicalSize = size;
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
          tester.view.padding = const FakeViewPadding(top: 24);
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          final inputRect = tester.getRect(field);
          final completeRect = tester.getRect(find.text(t.complete));
          expect(inputRect.top, greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy));
          expect(inputRect.bottom, lessThanOrEqualTo(completeRect.top));
          expect(completeRect.bottom, lessThanOrEqualTo(size.height - 300));
          expect(find.text(t.complete).hitTestable(), findsOneWidget);
          expect(field.hitTestable(), findsOneWidget);
          expect(tester.widget<EditableText>(field).controller, same(editable.controller));
          expect(editable.controller.text, 'Fold savings');
          expect(editable.focusNode.hasFocus, isTrue);
        }

        tester.view.viewInsets = const FakeViewPadding();
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        await tester.pumpAndSettle();
        final lastIcon = find.byKey(const Key('wallet-appearance-icon-${CustomWalletIcons.totalCount - 1}'));
        await Scrollable.ensureVisible(tester.element(lastIcon), alignment: 0.5);
        await tester.pumpAndSettle();
        expect(tester.getBottomLeft(lastIcon).dy, lessThan(tester.getTopLeft(find.text(t.complete)).dy));
        expect(lastIcon.hitTestable(), findsOneWidget);
        await tester.tap(lastIcon);
        await tester.tap(find.text(t.complete));
        await tester.pumpAndSettle();
        expect(walletProvider.savedName, 'Fold savings');
        expect(walletProvider.savedPalette?.$1, CustomWalletIcons.totalCount - 1);
        expect(find.byType(WalletAppearanceScreen), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('starts on the presets tab with a 2x2 preview and switches tabs', (tester) async {
    await open(tester);

    expect(tester.getTopLeft(find.byKey(const Key('wallet-appearance-tab-skins'))).dx, closeTo(20, 0.01));
    expect(find.byKey(const Key('wallet-appearance-option-skin-mint')), findsOneWidget);
    expect(find.byKey(const Key('wallet-appearance-option-color-6')), findsNothing);
    expect(tester.widget<WalletCard>(find.byType(WalletCard)).size, WalletCardSize.small);

    await tester.tap(find.byKey(const Key('wallet-appearance-tab-colors')));
    await tester.pump();
    expect(find.byKey(const Key('wallet-appearance-option-color-6')), findsOneWidget);

    await tester.tap(find.byKey(const Key('wallet-appearance-tab-photos')));
    await tester.pump();
    expect(find.byKey(const Key('wallet-appearance-option-choose-photo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('size options switch the preview between 2x2 and 4x2', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('wallet-appearance-size-wide')));
    await tester.pumpAndSettle();
    expect(tester.widget<WalletCard>(find.byType(WalletCard)).size, WalletCardSize.wide);
    final previewWidth = tester.getSize(find.byKey(const Key('wallet-appearance-preview'))).width;

    await tester.tap(find.byKey(const Key('wallet-appearance-size-small')));
    await tester.pumpAndSettle();
    expect(tester.widget<WalletCard>(find.byType(WalletCard)).size, WalletCardSize.small);
    expect(tester.getSize(find.byKey(const Key('wallet-appearance-preview'))).width, lessThan(previewWidth));
  });

  testWidgets('a saved solid color opens on the colors tab', (tester) async {
    await appearances.setBackground(walletProvider.wallet.id, WalletColorBackground.of(walletPaletteColors[8]));
    await open(tester);

    expect(find.byKey(const Key('wallet-appearance-option-color-8')), findsOneWidget);
  });

  testWidgets('choosing a solid color and completing saves it', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('wallet-appearance-tab-colors')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('wallet-appearance-option-color-6')));
    await tester.pump();
    await tester.tap(find.text(t.complete));
    await tester.pumpAndSettle();

    expect(appearances.backgroundOf(walletProvider.wallet.id), WalletColorBackground.of(walletPaletteColors[6]));
    expect(find.byType(WalletAppearanceScreen), findsNothing);
  });

  Future<void> pickPhotoIntoCrop(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('wallet-appearance-tab-photos')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('wallet-appearance-option-choose-photo')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  Directory photoDirectory() => Directory('${tempDir.path}/${WalletBackgroundPhotoStore.directoryName}');

  testWidgets('a picked photo goes through the crop step before it is applied', (tester) async {
    await open(tester, pickPhoto: () async => PickedPhoto(_png, 'png'));
    await pickPhotoIntoCrop(tester);

    expect(find.byType(WalletPhotoCropScreen), findsOneWidget);
    await tester.drag(find.byKey(const Key('wallet-photo-crop-area')), const Offset(-40, 0));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('wallet-photo-crop-done')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.byType(WalletPhotoCropScreen), findsNothing);
    expect(find.byKey(const Key('wallet-appearance-option-photo')), findsOneWidget);
    expect(find.text(t.wallet_appearance_screen.adjust_hint), findsOneWidget);
    final preview = tester.widget<WalletCard>(find.byType(WalletCard));
    final photo = preview.appearance.background! as WalletPhotoBackground;
    expect(photo.focusX, greaterThan(0));
  });

  testWidgets('cancelling the crop step drops the new photo', (tester) async {
    await open(tester, pickPhoto: () async => PickedPhoto(_png, 'png'));
    await pickPhotoIntoCrop(tester);
    expect(photoDirectory().listSync(), hasLength(1));

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('wallet-photo-crop-cancel')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-appearance-option-photo')), findsNothing);
    expect(tester.widget<WalletCard>(find.byType(WalletCard)).appearance.background, isNull);
    expect(photoDirectory().listSync(), isEmpty);
  });

  testWidgets('leaving without completing keeps the old background and drops the picked photo', (tester) async {
    await open(tester, pickPhoto: () async => PickedPhoto(_png, 'png'));
    await pickPhotoIntoCrop(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('wallet-photo-crop-done')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(photoDirectory().listSync(), hasLength(1));

    await tester.runAsync(() async {
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(appearances.backgroundOf(walletProvider.wallet.id), isNull);
    expect(photoDirectory().listSync(), isEmpty);
  });

  testWidgets('a photo that cannot be loaded shows a toast and keeps the old background', (tester) async {
    await open(tester, pickPhoto: () async => throw Exception('broken'));
    await tester.tap(find.byKey(const Key('wallet-appearance-tab-photos')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('wallet-appearance-option-choose-photo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(t.wallet_appearance_screen.photo_pick_failed), findsOneWidget);
    expect(find.byKey(const Key('wallet-appearance-option-photo')), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('vault wallets have no wallet tab', (tester) async {
    await open(tester);

    expect(find.byKey(const Key('wallet-appearance-tab-wallet')), findsNothing);
  });

  testWidgets('hot wallet edits name, color and icon on the wallet tab', (tester) async {
    walletProvider = _WalletProvider(_hotWallet());
    await open(tester);

    expect(find.byKey(const Key('wallet-appearance-name-field')), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'taken');
    await tester.pump();
    expect(find.text(t.wallet_info_screen.duplicated_name), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Savings');
    await tester.tap(find.byKey(const Key('wallet-appearance-color-3')));
    await tester.tap(find.byKey(const Key('wallet-appearance-icon-5')));
    await tester.pump();
    expect(find.text('Savings'), findsWidgets);

    await tester.tap(find.text(t.complete));
    await tester.pumpAndSettle();

    expect(walletProvider.savedName, 'Savings');
    expect(walletProvider.savedPalette, (5, 3));
  });

  testWidgets('the hue and brightness sliders pick a custom solid color', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('wallet-appearance-tab-colors')));
    await tester.pump();

    await tester.dragFrom(
      tester.getTopLeft(find.byKey(const Key('wallet-appearance-hue-slider'))) + const Offset(40, 14),
      const Offset(80, 0),
    );
    await tester.tapAt(
      tester.getTopRight(find.byKey(const Key('wallet-appearance-tone-slider'))) + const Offset(-20, 14),
    );
    await tester.pump();

    await tester.tap(find.text(t.complete));
    await tester.pumpAndSettle();
    final saved = appearances.backgroundOf(walletProvider.wallet.id);
    expect(saved, isA<WalletColorBackground>());
    expect(walletPaletteColors, isNot(contains((saved! as WalletColorBackground).color)));
  });

  testWidgets('back before complete drops an uncommitted skin', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('wallet-appearance-option-skin-mint')));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(WalletAppearanceScreen), findsNothing);
    expect(appearances.backgroundOf(walletProvider.wallet.id), isNull);
  });

  testWidgets('preview size is not saved with the background', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('wallet-appearance-size-wide')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wallet-appearance-tab-colors')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('wallet-appearance-option-color-6')));
    await tester.pump();
    await tester.tap(find.text(t.complete));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.widget<WalletCard>(find.byType(WalletCard)).size, WalletCardSize.small);
    expect(appearances.backgroundOf(walletProvider.wallet.id), WalletColorBackground.of(walletPaletteColors[6]));
  });

  testWidgets('a missing photo file still opens the editor', (tester) async {
    await appearances.setBackground(
      walletProvider.wallet.id,
      const WalletPhotoBackground(fileName: 'missing.jpg', aspectRatio: 1),
    );
    await open(tester);

    expect(find.byKey(const Key('wallet-appearance-option-photo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark and light themes both render the editor', (tester) async {
    for (final variant in CoconutThemeVariant.values) {
      await open(tester, variant: variant);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, buildCoconutThemeData(variant: variant).scaffoldBackgroundColor);
      expect(find.byKey(const Key('wallet-appearance-preview')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('enlarged text does not overflow the wallpaper tabs', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.es);
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

    await open(tester, textScaler: const TextScaler.linear(2), logicalSize: const Size(360, 800));

    expect(find.text('Predefinidos'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('wallet-appearance-tab-skins'))).dx, closeTo(20, 0.01));
    expect(tester.takeException(), isNull);

    final photosTab = find.byKey(const Key('wallet-appearance-tab-photos'));
    await tester.drag(find.byKey(const Key('wallet-appearance-tabs-scroll')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(photosTab.hitTestable(), findsOneWidget);
    await tester.tap(photosTab);
    await tester.pumpAndSettle();
    expect(find.byKey(const PageStorageKey('wallet-appearance-tab-body-photos')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long balance fits the compact and wide previews', (tester) async {
    walletProvider.balance = Balance(123456789012345, 0);
    await open(tester, textScaler: const TextScaler.linear(1.6), logicalSize: const Size(360, 800));

    expect(find.byKey(const Key('wallet-card-balance')), findsOneWidget);
    await tester.tap(find.byKey(const Key('wallet-appearance-size-wide')));
    await tester.pumpAndSettle();
    expect(tester.widget<WalletCard>(find.byType(WalletCard)).size, WalletCardSize.wide);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a directly added wallet can rename but not recolor its icon', (tester) async {
    walletProvider.wallet.walletImportSource = WalletImportSource.keystone;
    await open(tester);

    expect(find.byKey(const Key('wallet-appearance-tab-wallet')), findsOneWidget);
    expect(find.byKey(const Key('wallet-appearance-name-field')), findsOneWidget);
    expect(find.byKey(const Key('wallet-appearance-color-0')), findsNothing);
  });

  testWidgets('an empty or duplicate name does not complete', (tester) async {
    walletProvider = _WalletProvider(_hotWallet());
    await open(tester);

    await tester.enterText(find.byType(EditableText), '');
    await tester.pump();
    await tester.tap(find.text(t.complete));
    await tester.pumpAndSettle();
    expect(find.byType(WalletAppearanceScreen), findsOneWidget);
    expect(walletProvider.savedName, isNull);

    await tester.enterText(find.byType(EditableText), 'taken');
    await tester.pump();
    await tester.tap(find.text(t.complete));
    await tester.pumpAndSettle();
    expect(find.byType(WalletAppearanceScreen), findsOneWidget);
    expect(walletProvider.savedName, isNull);
  });

  testWidgets('back during save does not delete the photo being applied', (tester) async {
    walletProvider = _WalletProvider(_hotWallet());
    final gate = Completer<void>();
    walletProvider.nameUpdate = gate;
    await open(tester, pickPhoto: () async => PickedPhoto(_png, 'png'));
    await tester.enterText(find.byType(EditableText), 'Savings');
    await tester.pump();
    await pickPhotoIntoCrop(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('wallet-photo-crop-done')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(photoDirectory().listSync(), hasLength(1));

    await tester.tap(find.text(t.complete));
    await tester.pump();
    await tester.pump();
    expect(find.byType(WalletAppearanceScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(WalletAppearanceScreen), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(WalletAppearanceScreen), findsNothing);
    expect(photoDirectory().listSync(), hasLength(1));
    expect(appearances.backgroundOf(walletProvider.wallet.id), isA<WalletPhotoBackground>());
    expect(walletProvider.savedName, 'Savings');
  });

  for (final completionDelay in [Duration.zero, const Duration(milliseconds: 400)]) {
    testWidgets('appbar back during save returns once after success at $completionDelay', (tester) async {
      walletProvider = _WalletProvider(_hotWallet());
      final gate = Completer<void>();
      walletProvider.nameUpdate = gate;
      final observer = _PopObserver();
      await open(tester, observer: observer);
      await tester.enterText(find.byType(EditableText), 'Savings');
      await tester.pump();
      await tester.tap(find.text(t.complete));
      await tester.pump();

      await tester.tap(
        find.descendant(of: find.byType(AppBar), matching: find.byType(CoconutAppBarActionButton)).hitTestable(),
      );
      await tester.pump(completionDelay);
      final popsWhileSaving = observer.pops;
      gate.complete();
      await tester.pumpAndSettle();
      final error = tester.takeException();

      expect(popsWhileSaving, 0);
      expect(error, isNull);
      expect(observer.pops, 1);
      expect(find.byType(WalletAppearanceScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  }

  testWidgets('appbar back during save keeps the editor after a save error', (tester) async {
    walletProvider = _WalletProvider(_hotWallet());
    final gate = Completer<void>();
    walletProvider.nameUpdate = gate;
    final observer = _PopObserver();
    await open(tester, observer: observer);
    await tester.enterText(find.byType(EditableText), 'Savings');
    await tester.pump();
    final failure = StateError('synthetic save failure');
    final save = tester.widget<FixedBottomButton>(find.byType(FixedBottomButton)).onButtonClicked();
    final failedSave = expectLater(save, throwsA(same(failure)));
    await tester.pump();

    await tester.tap(
      find.descendant(of: find.byType(AppBar), matching: find.byType(CoconutAppBarActionButton)).hitTestable(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    gate.completeError(failure);
    await failedSave;
    await tester.pumpAndSettle();
    final error = tester.takeException();

    expect(observer.pops, 0);
    expect(error, isNull);
    expect(find.byType(WalletAppearanceScreen), findsOneWidget);
    final context = tester.element(find.byKey(const Key('wallet-appearance-preview')));
    expect(context.read<WalletAppearanceViewModel>().isSaving, isFalse);
    await tester.tap(
      find.descendant(of: find.byType(AppBar), matching: find.byType(CoconutAppBarActionButton)).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(observer.pops, 1);
    expect(find.text('open'), findsOneWidget);
  });
}
