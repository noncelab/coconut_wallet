import 'dart:io';

import 'package:coconut_wallet/app/bootstrap/app_bootstrap.dart';
import 'package:coconut_wallet/constants/dotenv_keys.dart';
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

  // 플랫폼 분기(iOS 시뮬레이터 경로 포함)를 .env 파일 없이 인라인 맵으로 검증한다.
  // 키 이름은 DotenvKeys 실제 정의와 일치시켜 .env 키 드리프트를 잡는다.
  test('Android는 10.0.2.2(에뮬레이터→호스트 루프백) 피어', () {
    expect(
      AppBootstrap.parseFlorestaFixedPeers(
        const {DotenvKeys.florestaFixedPeersAndroid: '10.0.2.2:18333,10.0.2.2:18444'},
        isAndroid: true,
      ),
      const ['10.0.2.2:18333', '10.0.2.2:18444'],
    );
  });

  test('iOS는 127.0.0.1(시뮬레이터→호스트 루프백) 피어', () {
    expect(
      AppBootstrap.parseFlorestaFixedPeers(
        const {DotenvKeys.florestaFixedPeersIos: '127.0.0.1:18333,127.0.0.1:18444'},
        isAndroid: false,
      ),
      const ['127.0.0.1:18333', '127.0.0.1:18444'],
    );
  });

  test('키가 없으면 고정 피어 없음(florestad 기본 DNS 시드)', () {
    expect(AppBootstrap.parseFlorestaFixedPeers(const {}, isAndroid: true), isEmpty);
    expect(AppBootstrap.parseFlorestaFixedPeers(const {'UNRELATED': 'x'}, isAndroid: false), isEmpty);
  });
}
