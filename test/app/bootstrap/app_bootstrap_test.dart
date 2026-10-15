import 'dart:io';

import 'package:coconut_wallet/app/bootstrap/app_bootstrap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp('app_bootstrap_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (call) async => call.method == 'getApplicationDocumentsDirectory' ? documentsDirectory.path : null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      null,
    );
    await documentsDirectory.delete(recursive: true);
  });

  test('deletes the debug log left by builds that had the log viewer', () async {
    final leftover = File('${documentsDirectory.path}/debug_log.txt')..writeAsStringSync('old log');

    await AppBootstrap.deleteLegacyDebugLog();

    expect(leftover.existsSync(), isFalse);
  });

  test('keeps other documents and does not fail when no debug log exists', () async {
    final other = File('${documentsDirectory.path}/keep.txt')..writeAsStringSync('keep');

    await AppBootstrap.deleteLegacyDebugLog();

    expect(other.existsSync(), isTrue);
  });
}
