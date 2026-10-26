import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/hot_wallet_passphrase_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

const _passphrase = 'public-animation-fixture';
const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

class _ControlledCheckBundle extends CachingAssetBundle {
  final check = Completer<ByteData>();

  @override
  Future<ByteData> load(String key) => key == StateLottiePath.checkComplete ? check.future : rootBundle.load(key);
}

void main() {
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    NetworkType.setNetworkType(NetworkType.testnet);
    Lottie.cache.clear();
  });

  Future<({Future<bool?> result, Uint8List mnemonic, GlobalKey boundary})> showSuccess(
    WidgetTester tester, {
    CoconutThemeVariant variant = CoconutThemeVariant.dark,
    bool disableAnimations = false,
    AssetBundle? bundle,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mnemonic = Uint8List.fromList(utf8.encode(_mnemonic));
    final seed = Seed.fromMnemonic(
      Uint8List.fromList(mnemonic),
      passphrase: Uint8List.fromList(utf8.encode(_passphrase)),
    );
    final descriptor = SingleSignatureVault.fromSeed(seed).descriptor;
    seed.wipe();
    final navigator = GlobalKey<NavigatorState>();
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: DefaultAssetBundle(
          bundle: bundle ?? rootBundle,
          child: MaterialApp(
            navigatorKey: navigator,
            theme: buildCoconutThemeData(variant: variant),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
                  child: child!,
                ),
            home: const SizedBox(),
          ),
        ),
      ),
    );
    final result = navigator.currentState!.push<bool>(
      MaterialPageRoute(builder: (_) => HotWalletPassphraseCheckScreen(mnemonic: mnemonic, descriptor: descriptor)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), _passphrase);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var attempt = 0; attempt < 80 && find.byKey(const ValueKey('correct')).evaluate().isEmpty; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('correct')), findsOneWidget);
    return (result: result, mnemonic: mnemonic, boundary: boundary);
  }

  Future<void> loadAnimation(WidgetTester tester) async {
    for (var attempt = 0; attempt < 40 && find.byType(Lottie).evaluate().isEmpty; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(find.byType(Lottie), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  for (final variant in CoconutThemeVariant.values) {
    testWidgets('success draws the existing creation check before returning in ${variant.name}', (tester) async {
      final session = await showSuccess(tester, variant: variant);
      expect(find.byType(LottieBuilder), findsOneWidget);
      final builder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      expect((builder.lottie as AssetLottie).assetName, StateLottiePath.checkComplete);
      await loadAnimation(tester);
      final colors = resolveCoconutThemeExtension(variant: variant).colors;
      final delegates = tester.widget<Lottie>(find.byType(Lottie)).delegates!.values!;
      expect(
        delegates.map((delegate) => delegate.value),
        containsAll([colors.checkIconBackground, colors.checkIconForeground]),
      );
      final controller = builder.controller! as AnimationController;
      expect(controller.duration, const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.value, greaterThanOrEqualTo(0.63));
      expect(find.text(t.wallet_home_screen.hot_wallet_setup.passphrase_correct), findsOneWidget);
      final iconRect = tester.getRect(find.byType(LottieBuilder));
      final checkRect = Rect.fromCenter(center: iconRect.center, width: 26, height: 26);
      await tester.runAsync(() async {
        final boundary = session.boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          int count(Color color) {
            var matches = 0;
            for (var y = checkRect.top.ceil(); y < checkRect.bottom.floor(); y++) {
              for (var x = checkRect.left.ceil(); x < checkRect.right.floor(); x++) {
                final offset = (y * image.width + x) * 4;
                final rgba = pixels.getUint32(offset);
                if (rgba == ((color.toARGB32() << 8) | 0xff) & 0xffffffff) matches++;
              }
            }
            return matches;
          }

          expect(count(colors.checkIconBackground), greaterThan(100), reason: 'The circle must actually be painted');
          expect(count(colors.checkIconForeground), greaterThan(10), reason: 'The contrasting tick must be visible');
        } finally {
          image.dispose();
        }
      });
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.isCompleted, isTrue);
      await tester.pump(const Duration(milliseconds: 249));
      expect(find.byKey(const ValueKey('correct')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(await session.result, isTrue);
      await tester.pumpAndSettle();
      expect(session.mnemonic, everyElement(0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion displays the final check immediately', (tester) async {
    final session = await showSuccess(tester, disableAnimations: true);
    await loadAnimation(tester);
    final controller = tester.widget<LottieBuilder>(find.byType(LottieBuilder)).controller! as AnimationController;
    expect(controller.value, 1);
    expect(controller.isAnimating, isFalse);
    await tester.pump(const Duration(milliseconds: 900));
    expect(await session.result, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving during success safely disposes the animation and mnemonic', (tester) async {
    final session = await showSuccess(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(session.mnemonic, everyElement(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('slow loading shows a check and completing after return is safe', (tester) async {
    final bundle = _ControlledCheckBundle();
    final session = await showSuccess(tester, bundle: bundle);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(await session.result, isTrue);
    await tester.pumpAndSettle();
    final bytes = await tester.runAsync(() => rootBundle.load(StateLottiePath.checkComplete));
    bundle.check.complete(bytes!);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an asset load failure keeps the success check and original return behavior', (tester) async {
    final bundle = _ControlledCheckBundle();
    final session = await showSuccess(tester, bundle: bundle);
    bundle.check.completeError(StateError('Synthetic asset failure'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 600));
    expect(await session.result, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
