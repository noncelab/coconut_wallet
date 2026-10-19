import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_export_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

class _Documents extends PathProviderPlatform {
  final String path;
  _Documents(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  @override
  List<WalletItemBase> get walletItemList => [];
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  List<int> get walletOrder => [];
  @override
  String get language => 'ko';
}

Future<void> _capture(GlobalKey key, String name) async {
  const directory = String.fromEnvironment('EMPTY_STATE_RENDER_DIR');
  if (directory.isEmpty) return;
  await Directory(directory).create(recursive: true);
  final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}

Future<void> _pumpVisibleFrame(WidgetTester tester) async {
  // CoconutSegmentedControl 0.11.2 schedules frames while idle, so global settling never completes.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  late PathProviderPlatform original;
  late Directory directory;
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final filename in ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf']) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$filename').readAsBytesSync())));
    }
    await loader.load();
  });
  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    original = PathProviderPlatform.instance;
    directory = await Directory.systemTemp.createTemp('label-export-empty-test-');
    PathProviderPlatform.instance = _Documents(directory.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = original;
    await directory.delete(recursive: true);
  });

  for (final variant in CoconutThemeVariant.values) {
    testWidgets('${variant.name}: zero wallets opens existing add flow and cancel preserves export screen', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets()),
            ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ],
          child: MaterialApp(
            theme: buildCoconutThemeData(variant: variant),
            home: RepaintBoundary(key: boundary, child: const LabelExportScreen()),
          ),
        ),
      );
      await _pumpVisibleFrame(tester);
      expect(find.text(t.label_export_screen.empty_wallet_title, findRichText: true), findsOneWidget);
      expect(find.text(t.label_export_screen.empty_wallet_description), findsOneWidget);
      expect(find.byType(FullscreenLoadingIndicator), findsNothing);
      expect(tester.widget<FixedBottomButton>(find.byType(FixedBottomButton)).isActive, isFalse);
      await tester.runAsync(() => _capture(boundary, 'label-empty-${variant.name}'));
      await tester.tap(find.text(t.home_widgets.add_wallet));
      await _pumpVisibleFrame(tester);
      expect(find.byType(WalletAddScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(WalletAddScreen))).pop();
      await _pumpVisibleFrame(tester);
      expect(find.text(t.label_export_screen.empty_wallet_title, findRichText: true), findsOneWidget);
      expect(tester.widget<FixedBottomButton>(find.byType(FixedBottomButton)).isActive, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
