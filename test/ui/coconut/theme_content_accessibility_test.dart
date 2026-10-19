import 'package:coconut_design_system/coconut_design_system.dart' show CoconutCheckbox;
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/screens/home/wallet_add/hot_wallet/hot_wallet_app_lock_guide_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/single_field_fixed_bottom_sheet_body.dart';
import 'package:flutter/rendering.dart';
import 'package:coconut_wallet/widgets/features/wallet/connect/wallet_connect_widgets.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

Widget _app(Widget child, CoconutThemeVariant variant, {bool reduced = false}) {
  return MaterialApp(
    theme: buildCoconutThemeData(variant: variant),
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: reduced),
          child: child!,
        ),
    home: Scaffold(body: child),
  );
}

void main() {
  for (final variant in CoconutThemeVariant.values) {
    testWidgets('${variant.name} popup scales, scrolls and keeps themed checkbox actionable', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var selected = false;
      final colors = resolveCoconutThemeExtension(variant: variant).colors;
      await tester.pumpWidget(
        _app(
          CoconutPopup(
            title: 'Confirm wallet',
            description: 'Compare the information on your device before continuing. ' * 8,
            languageCode: 'en',
            checkboxText: 'I checked the device',
            onCheckboxChanged: (value) => selected = value,
            onTapRight: () {},
          ),
          variant,
        ),
      );
      final description = find.text('Compare the information on your device before continuing. ' * 8);
      expect(MediaQuery.textScalerOf(tester.element(description)).scale(16), 32);
      final checkbox = tester.widget<CoconutCheckbox>(find.byType(CoconutCheckbox));
      expect(checkbox.color, colors.iconPrimary);
      expect(checkbox.unSelectedColor, colors.iconPrimary);
      await tester.ensureVisible(find.byType(CoconutCheckbox));
      await tester.tap(find.byType(CoconutCheckbox));
      expect(selected, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${variant.name} connected wallet labels retain large text in narrow rows', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(width: 280, child: WalletConnectInfoRow(label: 'Master fingerprint', value: 'AABBCCDD')),
          variant,
        ),
      );
      expect(MediaQuery.textScalerOf(tester.element(find.text('Master fingerprint'))).scale(12), 24);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selectable sheet retains system scaling and selection in its scrollable list', (tester) async {
    int? selected;
    await tester.pumpWidget(
      _app(
        SizedBox(
          height: 300,
          width: 280,
          child: SelectableBottomSheetBody<int>(
            items: const [1, 2, 3],
            getItemId: (item) => item,
            itemBuilder:
                (context, item, isSelected, onTap) =>
                    ListTile(title: Text('Wallet $item'), selected: isSelected, onTap: onTap),
            onSelectionChanged: (value) => selected = value,
            confirmText: 'Confirm',
            backgroundColor: Colors.white,
          ),
        ),
        CoconutThemeVariant.light,
      ),
    );
    expect(MediaQuery.textScalerOf(tester.element(find.text('Wallet 1'))).scale(14), 28);
    await tester.tap(find.text('Wallet 1'));
    await tester.pump();
    expect(selected, 1);
    expect(tester.getRect(find.text('Wallet 1')).bottom, lessThan(tester.getRect(find.text('Confirm')).top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('underlined button exposes enabled action and disables semantics and callback together', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    for (final active in [true, false]) {
      await tester.pumpWidget(
        _app(
          CoconutUnderlinedButton(text: 'Action', isActive: active, onTap: () => calls++),
          CoconutThemeVariant.light,
        ),
      );
      final data = tester.getSemantics(find.byType(CoconutUnderlinedButton)).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, active);
      expect(data.hasAction(SemanticsAction.tap), active);
      await tester.tap(find.text('Action'));
      await tester.pump();
      expect(calls, 1);
    }
    semantics.dispose();
  });

  testWidgets('single-field sheet scrolls long content above a wrapped 2x confirmation with keyboard', (tester) async {
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(280, 600),
            textScaler: TextScaler.linear(2),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: SizedBox(
            height: 280,
            width: 280,
            child: SingleFieldFixedBottomSheetBody(
              textField: Column(children: [for (var i = 0; i < 10; i++) Text('Field detail $i')]),
              isCompleteEnabled: true,
              onComplete: () {},
              completeLabel: 'Confirm this updated wallet name',
            ),
          ),
        ),
        CoconutThemeVariant.light,
      ),
    );
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    final buttonText = tester.getRect(find.text('Confirm this updated wallet name'));
    expect(viewport.bottom, lessThan(buttonText.top));
    await tester.scrollUntilVisible(find.text('Field detail 9'), 150, scrollable: find.byType(Scrollable));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Field detail 9')).bottom, lessThanOrEqualTo(viewport.bottom + 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet skeleton stops and resumes shimmer when reduced motion changes', (tester) async {
    for (final reduced in [false, true, false]) {
      await tester.pumpWidget(
        _app(const WalletConnectWalletInfoSkeleton(), CoconutThemeVariant.light, reduced: reduced),
      );
      await tester.pump();
      expect(tester.widgetList<Shimmer>(find.byType(Shimmer)).every((shimmer) => shimmer.enabled == !reduced), isTrue);
      if (reduced) {
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
    }
  });

  testWidgets('app lock guide retains readable scrolling content at 2x in short sheet', (tester) async {
    await tester.pumpWidget(
      _app(const SizedBox(height: 300, child: HotWalletAppLockGuideScreen()), CoconutThemeVariant.light),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
