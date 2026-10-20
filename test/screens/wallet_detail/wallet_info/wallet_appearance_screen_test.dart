import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/constants/wallet_skins.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
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
import 'package:flutter/material.dart';
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
  Future<void> updateWalletName(int id, String name) async => savedName = name;
  @override
  Future<void> updateWalletPalette(int id, int iconIndex, int colorIndex) async =>
      savedPalette = (iconIndex, colorIndex);
  @override
  Balance getWalletBalance(int walletId) => Balance(0, 0);
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

void main() {
  late Directory tempDir;
  late WalletAppearanceProvider appearances;
  late _WalletProvider walletProvider;

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

  Future<void> open(WidgetTester tester, {PhotoPicker? pickPhoto}) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
          InheritedProvider<PreferenceProvider>.value(value: _PreferenceProvider()),
          ChangeNotifierProvider<WalletAppearanceProvider>.value(value: appearances),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
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
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the presets tab with a 2x2 preview and switches tabs', (tester) async {
    await open(tester);

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
}
