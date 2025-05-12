/// 스크립트 상태 업데이트 정보를 담는 모델
class ScriptStatus extends UnaddressedScriptStatus {
  final String derivationPath;
  final String address;
  final int index;
  final bool isChange;

  ScriptStatus({
    required this.derivationPath,
    required this.address,
    required this.index,
    required this.isChange,
    required super.scriptPubKey,
    required super.status,
    required super.timestamp,
  });

  @override
  set status(String? status) {
    super.status = status;
  }

  @override
  set timestamp(DateTime timestamp) {
    super.timestamp = timestamp;
  }

  UnaddressedScriptStatus toUnaddressedScriptStatus() {
    return UnaddressedScriptStatus(
      scriptPubKey: scriptPubKey,
      status: status,
      timestamp: timestamp,
    );
  }
}

class UnaddressedScriptStatus {
  final String scriptPubKey;

  /// script status (sha256 hash)
  String? status;
  DateTime timestamp;

  UnaddressedScriptStatus({
    required this.scriptPubKey,
    required this.status,
    required this.timestamp,
  });
}
