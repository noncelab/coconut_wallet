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
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

Future<_Preferences> _pump(
  WidgetTester tester,
  double width,
  double scale,
  AppLocale locale, {
  bool bold = false,
}) async {
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
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), boldText: bold),
              child: child!,
            ),
        home: const WalletHomeEditScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return preferences;
}

List<String> get _labels => [
  t.wallet_home_screen.edit.category.total_balance,
  t.wallet_home_screen.edit.category.wallet_list,
  t.wallet_home_screen.edit.category.recent_transactions,
  t.wallet_home_screen.edit.category.analysis,
];

bool _verifyLayout(WidgetTester tester) {
  final heights = <double>{};
  final modes = <bool>{};
  for (final label in _labels) {
    final title = find.text(label);
    final tile = find.ancestor(of: title, matching: find.byType(ShrinkAnimationButton)).first;
    final check = find.descendant(
      of: tile,
      matching: find.byWidgetPredicate(
        (widget) => widget is AnimatedContainer && (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      ),
    );
    final checkIcons = find.descendant(of: check, matching: find.byType(SvgPicture)).evaluate().toSet();
    final icon =
        find
            .descendant(of: tile, matching: find.byType(SvgPicture))
            .evaluate()
            .where((element) => !checkIcons.contains(element))
            .single;
    final textRect = tester.getRect(title);
    final checkRect = tester.getRect(check);
    final tileRect = tester.getRect(tile);
    final iconRect = tester.getRect(find.byWidget(icon.widget));
    final below = textRect.top > checkRect.bottom;
    modes.add(below);
    heights.add(tileRect.height);
    expect(checkRect.top - tileRect.top, closeTo(15, 0.01));
    expect(tileRect.right - checkRect.right, closeTo(15, 0.01));
    if (below) {
      expect(textRect.top - checkRect.bottom, greaterThanOrEqualTo(3.99));
    } else {
      expect(textRect.top, closeTo(checkRect.top, 0.01));
      expect(checkRect.left - textRect.right, greaterThanOrEqualTo(7.99));
    }
    expect(iconRect.top - textRect.bottom, greaterThanOrEqualTo(11.99));
    expect(iconRect.bottom, lessThanOrEqualTo(tileRect.bottom));
    expect(textRect.left, greaterThanOrEqualTo(tileRect.left));
    expect(textRect.right, lessThanOrEqualTo(tileRect.right));
    final text = tester.widget<Text>(title);
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expect(find.ancestor(of: title, matching: find.byType(FittedBox)), findsNothing);
  }
  for (final height in heights) {
    expect(height, closeTo(heights.first, 0.001));
  }
  expect(modes, hasLength(1));
  expect(tester.takeException(), isNull);
  return modes.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font =
        FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
    await font.load();
  });
  for (final width in [320.0, 344.0, 414.0, 720.0]) {
    for (final locale in [AppLocale.ko, AppLocale.en, AppLocale.de, AppLocale.ja, AppLocale.es]) {
      testWidgets('responsive tiles $width ${locale.name}', (tester) async {
        await _pump(tester, width, 1, locale);
        final below = _verifyLayout(tester);
        if (locale == AppLocale.ko) {
          expect(below, width < 414);
          if (width >= 344) {
            for (final label in _labels) {
              final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
              final lines =
                  paragraph
                      .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: label.length))
                      .map((box) => box.top)
                      .toSet();
              expect(lines.length, label == t.wallet_home_screen.edit.category.recent_transactions ? 2 : 1);
            }
          }
        }
      });
    }
  }
  testWidgets('bold text and external scale retain fixed tile policy', (tester) async {
    await _pump(tester, 344, 2, AppLocale.de, bold: true);
    _verifyLayout(tester);
    final paragraph = tester.renderObject<RenderParagraph>(find.text(_labels.first));
    expect(paragraph.textScaler.scale(14), 14);
  });
  testWidgets('resize keeps pending toggle and saves original order only on completion', (tester) async {
    final preferences = await _pump(tester, 344, 1, AppLocale.ko);
    expect(_verifyLayout(tester), isTrue);
    final title = find.text(t.wallet_home_screen.edit.category.recent_transactions);
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(preferences.saved, isNull);
    tester.view.physicalSize = const Size(414, 1000);
    await tester.pumpAndSettle();
    expect(_verifyLayout(tester), isFalse);
    final button = tester.widget<FixedBottomButton>(find.byType(FixedBottomButton));
    expect(button.isActive, isTrue);
    await button.onButtonClicked();
    await tester.pumpAndSettle();
    expect(preferences.saved!.map((e) => e.homeFeatureTypeString), ['recentTransaction', 'analysis']);
    expect(preferences.saved!.map((e) => e.isEnabled), [false, true]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('fixed tile shows guidance without enabling save', (tester) async {
    final preferences = await _pump(tester, 344, 1, AppLocale.ko);
    final title = find.text(t.wallet_home_screen.edit.category.total_balance);
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(t.wallet_home_screen.cannot_modify_fixed_widget), findsOneWidget);
    expect(tester.widget<FixedBottomButton>(find.byType(FixedBottomButton)).isActive, isFalse);
    expect(preferences.saved, isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
