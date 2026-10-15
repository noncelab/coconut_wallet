import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';

/// coconut_lib의 inheritance miniscript 직렬화 오류에 대한 임시 호환성 처리입니다.
///
/// 구버전 coconut_lib는 absolute locktime 기반 inheritance policy를
/// `older(...)`로 저장했지만, 올바른 표현은 `after(...)`입니다.
/// coconut_lib가 이 legacy 데이터를 계속 읽을 수 있도록 지원하는 동안에만
/// 지갑 백업 데이터의 저장/가져오기 경로에서 사용합니다.
///
/// 관련 coconut_lib 수정:
/// https://github.com/noncelab/coconut_lib/commit/28fe3ddb9b653941bab08f809680e7c892edd26c
class TaprootOlderToAfterMigrationResult {
  final String descriptor;
  final List<TaprootScriptPathSeedInfo> scriptPathSeedInfos;
  final bool hasChanges;

  const TaprootOlderToAfterMigrationResult({
    required this.descriptor,
    required this.scriptPathSeedInfos,
    required this.hasChanges,
  });
}

class TaprootOlderToAfterMigration {
  static String _migrateMiniscript(String miniscript) {
    final match = RegExp(r'^and_v\(v:pk\((.+)\),(?:older|after)\((\d+)\)\)$').firstMatch(miniscript);
    if (match == null) return miniscript;

    final migratedMiniscript = 'and_v(v:pk(${match.group(1)}),after(${match.group(2)}))';
    InheritancePolicy.fromMiniscript(migratedMiniscript);
    return migratedMiniscript;
  }

  static TaprootOlderToAfterMigrationResult migrate({
    required String descriptor,
    required List<TaprootScriptPathSeedInfo> scriptPathSeedInfos,
  }) {
    final descriptorObject = Descriptor.parse(descriptor, ignoreChecksum: true);
    var hasChanges = false;

    for (var index = 0; index < descriptorObject.miniscriptList.length; index++) {
      final miniscript = descriptorObject.miniscriptList[index];
      final migratedMiniscript = _migrateMiniscript(miniscript);
      if (migratedMiniscript != miniscript) {
        descriptorObject.miniscriptList[index] = migratedMiniscript;
        hasChanges = true;
      }
    }

    // serialize()는 descriptor body에 대한 checksum을 항상 다시 계산합니다.
    final migratedDescriptor = descriptorObject.serialize();
    hasChanges = hasChanges || descriptor != migratedDescriptor;

    final migratedScriptPathSeedInfos =
        scriptPathSeedInfos.map((seedInfo) {
          final migratedMiniscript = _migrateMiniscript(seedInfo.miniscript);
          if (migratedMiniscript != seedInfo.miniscript) {
            hasChanges = true;
          }
          return TaprootScriptPathSeedInfo(
            miniscript: migratedMiniscript,
            extendedPublicKeys: List<String>.from(seedInfo.extendedPublicKeys),
          );
        }).toList();

    return TaprootOlderToAfterMigrationResult(
      descriptor: migratedDescriptor,
      scriptPathSeedInfos: migratedScriptPathSeedInfos,
      hasChanges: hasChanges,
    );
  }
}
