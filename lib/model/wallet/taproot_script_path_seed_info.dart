class TaprootScriptPathSeedInfo {
  final String miniscript;
  final List<String> extendedPublicKeys;

  TaprootScriptPathSeedInfo({required this.miniscript, required this.extendedPublicKeys});

  factory TaprootScriptPathSeedInfo.fromJson(Map<String, dynamic> json) {
    return TaprootScriptPathSeedInfo(
      miniscript: json['miniscript'] as String,
      extendedPublicKeys: (json['extendedPublicKeys'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'miniscript': miniscript, 'extendedPublicKeys': extendedPublicKeys};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaprootScriptPathSeedInfo &&
          runtimeType == other.runtimeType &&
          miniscript == other.miniscript &&
          _listEquals(extendedPublicKeys, other.extendedPublicKeys);

  @override
  int get hashCode => Object.hash(miniscript, Object.hashAll(extendedPublicKeys));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
