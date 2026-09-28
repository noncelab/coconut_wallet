import 'dart:async';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('클립보드 복사 중 dispose되면 완료 콜백을 호출하지 않는다', (tester) async {
    final clipboardWrite = Completer<void>();
    var callbackCount = 0;
    _delayClipboardWrite(clipboardWrite);

    await _pumpCopyContainer(tester, onCopied: () => callbackCount++);
    await tester.tap(find.byType(CopyTextContainer));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    clipboardWrite.complete();
    await tester.pump();

    expect(callbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('클립보드 복사 중 위젯이 교체되어도 탭 시점 콜백만 호출한다', (tester) async {
    final clipboardWrite = Completer<void>();
    var originalCallbackCount = 0;
    var replacementCallbackCount = 0;
    _delayClipboardWrite(clipboardWrite);

    await _pumpCopyContainer(tester, onCopied: () => originalCallbackCount++);
    await tester.tap(find.byType(CopyTextContainer));
    await tester.pump();

    await _pumpCopyContainer(tester, onCopied: () => replacementCallbackCount++);
    clipboardWrite.complete();
    await tester.pump();

    expect(originalCallbackCount, 1);
    expect(replacementCallbackCount, 0);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}

void _delayClipboardWrite(Completer<void> clipboardWrite) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
    call,
  ) async {
    if (call.method == 'Clipboard.setData') {
      await clipboardWrite.future;
    }
    return null;
  });
}

Future<void> _pumpCopyContainer(WidgetTester tester, {required VoidCallback onCopied}) {
  return tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: CopyTextContainer(key: const ValueKey('copy-container'), text: 'bc1qcopytarget', onCopied: onCopied),
        ),
      ),
    ),
  );
}
