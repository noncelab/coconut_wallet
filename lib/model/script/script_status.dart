/// 스크립트 상태 업데이트 정보를 담는 모델
class ScriptStatus {
  final String scriptPubKey;
  final String? status;
  final DateTime timestamp;
  final String derivationPath;
  final String address;
  final int index;
  final bool isChange;

  ScriptStatus({
    required this.scriptPubKey,
    required this.status,
    required this.timestamp,
    required this.derivationPath,
    required this.address,
    required this.index,
    required this.isChange,
  });
}
