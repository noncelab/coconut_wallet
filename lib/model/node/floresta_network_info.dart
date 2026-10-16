/// Floresta 노드의 네트워크 요약.
///
/// JSON-RPC `getnetworkinfo` 결과를 감싼다. 노드 버전/연결 수/중계 상태를
/// 상태 요약 카드에 표시하는 데 쓴다.
class FlorestaNetworkInfo {
  final int version;
  final String subversion;
  final int protocolVersion;
  final String localServices;
  final bool localRelay;
  final int connections;
  final int? connectionsIn;
  final int? connectionsOut;
  final bool networkActive;

  /// 최소 중계 수수료(fee rate, BTC/kvB). 파싱 실패 시 null.
  final double? relayFee;

  final List<String> warnings;

  const FlorestaNetworkInfo({
    required this.version,
    required this.subversion,
    required this.protocolVersion,
    required this.localServices,
    required this.localRelay,
    required this.connections,
    this.connectionsIn,
    this.connectionsOut,
    required this.networkActive,
    this.relayFee,
    required this.warnings,
  });

  /// RPC `getnetworkinfo` 결과를 파싱한다.
  factory FlorestaNetworkInfo.fromRpc(Map<String, dynamic> json) {
    int intOf(String key, [int fallback = 0]) => (json[key] as num?)?.toInt() ?? fallback;
    final relayFee = json['relayfee'];
    return FlorestaNetworkInfo(
      version: intOf('version'),
      subversion: json['subversion'] as String? ?? '',
      protocolVersion: intOf('protocolversion'),
      localServices: json['localservices'] as String? ?? '',
      localRelay: json['localrelay'] as bool? ?? false,
      connections: intOf('connections'),
      connectionsIn: (json['connections_in'] as num?)?.toInt(),
      connectionsOut: (json['connections_out'] as num?)?.toInt(),
      networkActive: json['networkactive'] as bool? ?? false,
      relayFee: relayFee is num ? relayFee.toDouble() : null,
      warnings: (json['warnings'] as List?)?.cast<String>() ?? const [],
    );
  }
}
