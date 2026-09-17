import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  final String documentsPath;

  FakePathProviderPlatform(this.documentsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class FakeWalletProvider extends Fake implements WalletProvider {
  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

void main() {
  late PathProviderPlatform originalPathProvider;
  late Directory documentsDirectory;

  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    originalPathProvider = PathProviderPlatform.instance;
    documentsDirectory = await Directory.systemTemp.createTemp('label_import_screen_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(documentsDirectory.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  testWidgets('shows and selects a very large memo file on the import screen', (tester) async {
    const fileName = 'large-screen-memos.jsonl';
    final file = File('${documentsDirectory.path}/$fileName');

    await tester.runAsync(() async {
      final sink = file.openWrite();

      for (var i = 0; i < 200; i++) {
        final label = i == 199 ? '화면에서 고르는 아주 큰 메모 파일\n'.padRight(1024 * 1024, '나') : 'screen-memo-$i';
        sink.writeln(
          '{"type":"tx","ref":"${i.toRadixString(16).padLeft(64, '0')}","label":"$label","origin":"wpkh([d45aa182/84\'/1\'/0\'])"}',
        );
      }
      await sink.close();
    });

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: ListenableProvider<WalletProvider>.value(
            value: FakeWalletProvider(),
            child: const LabelImportScreen(walletId: 1),
          ),
        ),
      ),
    );

    await pumpUntilFound(tester, find.text(fileName));

    expect(find.text(fileName), findsOneWidget);

    await tester.tap(find.text(fileName));
    await tester.pump();
    await tester.tap(find.text(t.label_management_screen.file.select_button));
    await pumpUntilFound(tester, find.text(t.label_import_screen.option_selection.title));

    expect(find.text(t.label_import_screen.option_selection.title), findsOneWidget);
    expect(find.text(fileName), findsOneWidget);
  });
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  int maxPumps = 40,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Expected $finder to appear within ${step * maxPumps}.');
}
