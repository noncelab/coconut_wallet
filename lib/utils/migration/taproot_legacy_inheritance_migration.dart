import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';

class TaprootLegacyInheritanceMigrationResult {
  final String descriptor;
  final List<TaprootScriptPathSeedInfo> scriptPathSeedInfos;
  final bool hasChanges;
  final bool hasOlder;

  const TaprootLegacyInheritanceMigrationResult({
    required this.descriptor,
    required this.scriptPathSeedInfos,
    required this.hasChanges,
    required this.hasOlder,
  });
}

/// 볼트 3.3.0 이하 상속 leaf 표기의 after_drop 변환
class TaprootLegacyInheritanceMigration {
  static final RegExp _legacyLeaf = RegExp(r'and_v\(v:pk\(([^()]+)\),(older|after)\((\d+)\)\)');

  static String migrateMiniscript(String miniscript) {
    final match = _legacyLeaf.firstMatch(miniscript);
    if (match == null || match.start != 0 || match.end != miniscript.length) return miniscript;
    return _toAfterDrop(match);
  }

  static String migrateDescriptor(String descriptor) {
    final body = descriptor.split('#').first;
    final migratedBody = body.replaceAllMapped(_legacyLeaf, _toAfterDrop);
    return Descriptor.parse('$migratedBody#${Checksum.getChecksum(migratedBody)}').serialize();
  }

  static TaprootLegacyInheritanceMigrationResult migrate({
    required String descriptor,
    required List<TaprootScriptPathSeedInfo> scriptPathSeedInfos,
  }) {
    final migratedDescriptor = migrateDescriptor(descriptor);
    var hasChanges = migratedDescriptor != descriptor;
    var hasOlder = _hasOlder(descriptor);

    final migratedScriptPathSeedInfos =
        scriptPathSeedInfos.map((seedInfo) {
          final migratedMiniscript = migrateMiniscript(seedInfo.miniscript);
          if (migratedMiniscript != seedInfo.miniscript) hasChanges = true;
          if (_hasOlder(seedInfo.miniscript)) hasOlder = true;
          return TaprootScriptPathSeedInfo(
            miniscript: migratedMiniscript,
            extendedPublicKeys: List<String>.from(seedInfo.extendedPublicKeys),
          );
        }).toList();

    return TaprootLegacyInheritanceMigrationResult(
      descriptor: migratedDescriptor,
      scriptPathSeedInfos: migratedScriptPathSeedInfos,
      hasChanges: hasChanges,
      hasOlder: hasOlder,
    );
  }

  static bool _hasOlder(String text) => _legacyLeaf.allMatches(text).any((match) => match.group(2) == 'older');

  static String _toAfterDrop(Match match) => 'and_v(after_drop(${match.group(3)}),pk(${match.group(1)}))';
}
