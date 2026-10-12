import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/home_settings/wallet_home_edit_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class _Wallets extends Fake implements WalletProvider {
  @override
  List<WalletItemBase> get walletItemList => [];
}

class _Preferences extends Fake implements PreferenceProvider {
  List<HomeFeature>? saved;
  @override
  String get language => 'ko';
  @override
  bool get isBalanceHidden => false;
  @override
  bool get isFiatBalanceHidden => false;
  @override
  bool get isFakeBalanceActive => false;
  @override
  int? get fakeBalanceTotalAmount => null;
  @override
  HomeAddWalletOption get homeAddWalletOption => HomeAddWalletOption.all;
  @override
  Map<int, dynamic> getFakeBalanceMap() => {};
  @override
  List<HomeFeature> get homeFeatures => [
    HomeFeature(homeFeatureTypeString: HomeFeatureType.recentTransaction.name, isEnabled: true),
    HomeFeature(homeFeatureTypeString: HomeFeatureType.analysis.name, isEnabled: true),
  ];
  @override
  Future<void> changeIsBalanceHidden(bool value) async {}
  @override
  Future<void> changeIsFiatBalanceHidden(bool value) async {}
  @override
  Future<void> changeHomeAddWalletOption(HomeAddWalletOption value) async {}
  @override
  Future<void> clearFakeBalanceTotalAmount() async {}
  @override
  Future<void> toggleFakeBalanceActivation(bool value) async {}
  @override
  Future<void> setHomeFeautres(List<HomeFeature> value) async => saved = value;
}

Future<_Preferences> _pump(WidgetTester tester, double width, double scale, AppLocale locale) async {
  LocaleSettings.setLocaleSync(locale);
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final preferences = _Preferences();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        InheritedProvider<WalletProvider>.value(value: _Wallets()),
        InheritedProvider<PreferenceProvider>.value(value: preferences),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        builder:
            (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: const WalletHomeEditScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return preferences;
}

void main() {
  for (final width in [320.0, 344.0, 414.0]) {
    for (final scale in [1.0, 1.6]) {
      for (final locale in [AppLocale.ko, AppLocale.en, AppLocale.de]) {
        testWidgets('tiles reserve label/check/icon space at $width, scale $scale, ${locale.name}', (tester) async {
          await _pump(tester, width, scale, locale);
          expect(tester.takeException(), isNull);
          for (final label in [
            t.wallet_home_screen.edit.category.total_balance,
            t.wallet_home_screen.edit.category.wallet_list,
            t.wallet_home_screen.edit.category.recent_transactions,
            t.wallet_home_screen.edit.category.analysis,
          ]) {
            final title = find.text(label);
            final tile = find.ancestor(of: title, matching: find.byType(ShrinkAnimationButton)).first;
            final check = find.descendant(
              of: tile,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is AnimatedContainer && (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
              ),
            );
            final icon = find
                .descendant(of: tile, matching: find.byType(SvgPicture))
                .evaluate()
                .where(
                  (element) =>
                      !find.descendant(of: check, matching: find.byType(SvgPicture)).evaluate().contains(element),
                );
            expect(icon, hasLength(1));
            final iconRect = tester.getRect(find.byWidget(icon.single.widget));
            final textRect = tester.getRect(title);
            final checkRect = tester.getRect(check);
            final tileRect = tester.getRect(tile);
            expect(textRect.right, lessThanOrEqualTo(checkRect.left - 7.9));
            expect(textRect.top, greaterThanOrEqualTo(tileRect.top));
            expect(textRect.bottom, lessThan(iconRect.top));
            expect(checkRect.bottom, lessThan(iconRect.top));
            expect(iconRect.left, greaterThanOrEqualTo(tileRect.left));
            expect(iconRect.top, greaterThanOrEqualTo(tileRect.top));
            expect(iconRect.right, lessThanOrEqualTo(tileRect.right));
            expect(iconRect.bottom, lessThanOrEqualTo(tileRect.bottom));
            expect(checkRect.right, lessThanOrEqualTo(tileRect.right));
          }
        });
      }
    }
  }

  testWidgets('optional tile toggle preserves order and is persisted only on completion', (tester) async {
    final preferences = await _pump(tester, 344, 1, AppLocale.ko);
    final title = find.text(t.wallet_home_screen.edit.category.recent_transactions);
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(preferences.saved, isNull);
    final button = tester.widget<FixedBottomButton>(find.byType(FixedBottomButton));
    expect(button.isActive, isTrue);
    await button.onButtonClicked();
    await tester.pumpAndSettle();
    expect(preferences.saved!.map((e) => e.homeFeatureTypeString), ['recentTransaction', 'analysis']);
    expect(preferences.saved!.map((e) => e.isEnabled), [false, true]);
    expect(tester.takeException(), isNull);
  });
}
