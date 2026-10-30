import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/screens/settings/tools/bip39_word_list_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Bold']) {
        loader.addFont(rootBundle.load('assets/fonts/$family-$weight.ttf'));
      }
      await loader.load();
    }
  });
  for (final variant in CoconutThemeVariant.values) {
    testWidgets('$variant BIP39 search allocates a complete clear target', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: buildCoconutThemeData(variant: variant), home: const Bip39ListScreen()),
      );
      final field = find.byType(CoconutTextField);
      await tester.enterText(field, 'abandon');
      await tester.pump();
      final clear = find.descendant(of: field, matching: find.byType(CupertinoButton));
      final clearRect = tester.getRect(clear);
      expect(clearRect.size, const Size(44, 44));
      expect(tester.getRect(field).contains(clearRect.topLeft), isTrue);
      expect(tester.getRect(field).contains(clearRect.bottomRight - const Offset(0.1, 0.1)), isTrue);
      await tester.tapAt(clearRect.topLeft + const Offset(1, 1));
      await tester.pump();
      expect(tester.widget<CoconutTextField>(field).controller.text, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
