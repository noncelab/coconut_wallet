import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 코드가 쓰는 assets/ 경로는 모두 pubspec의 assets에 들어 있어야 한다.
/// 빠지면 위젯 테스트는 통과해도 실기기에서 "Unable to load asset"으로 아이콘이 사라진다
/// (assets/svg/bold-bell.svg가 루트에 있어 홈 알림 버튼이 비었던 실기기 QA 발견).
void main() {
  test('every assets/ path used in lib/ is bundled by pubspec', () {
    final declared = <String>[];
    var inAssets = false;
    for (final line in File('pubspec.yaml').readAsLinesSync()) {
      if (line.trim() == 'assets:') {
        inAssets = true;
        continue;
      }
      if (inAssets) {
        final match = RegExp(r'^\s+-\s+(assets/\S+)').firstMatch(line);
        if (match != null) {
          declared.add(match.group(1)!);
        } else if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#')) {
          inAssets = false;
        }
      }
    }
    expect(declared, isNotEmpty);

    // A directory entry bundles only the files directly inside it, not subfolders.
    bool bundled(String path) => declared.any(
      (entry) => entry.endsWith('/') ? path.substring(0, path.lastIndexOf('/') + 1) == entry : path == entry,
    );

    final literal = RegExp(r'''['"](assets/[^'"$]+\.(?:svg|png|jpg|json|riv|ttf))['"]''');
    final missing = <String>{};
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.contains('/localization/')) continue;
      for (final match in literal.allMatches(file.readAsStringSync())) {
        final path = match.group(1)!;
        if (!File(path).existsSync() || !bundled(path)) missing.add('${file.path}: $path');
      }
    }
    expect(missing, isEmpty, reason: 'asset paths that are missing or not bundled');
  });
}
