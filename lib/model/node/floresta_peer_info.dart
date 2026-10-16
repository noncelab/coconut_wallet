/// Floresta 노드의 피어 정보.
///
/// JSON-RPC `getpeerinfo` 항목 하나를 감싼다. full validation 노드가 실제로
/// 어떤 피어와 연결돼 있는지(=검증 근거)를 UI에 보여주는 데 쓴다.
class FlorestaPeerInfo {
  final int id;
  final String address;

  /// 서비스 플래그 hex bitfield.
  final String services;

  /// 인식된 서비스 이름 목록(예: NETWORK, WITNESS).
  final List<String> servicesNames;

  /// 이 피어가 mempool 트랜잭션 중계를 요청했는지.
  final bool relayTxs;

  /// 피어 클라이언트 문자열(예: /Satoshi:26.0/).
  final String userAgent;

  /// 인바운드 연결 여부.
  final bool inbound;

  /// 연결 시점의 피어 블록 높이.
  final int initialHeight;

  /// 피어 시계 오프셋(초).
  final int timeOffset;

  /// 연결 종류(Feeler/Regular/Extra).
  final String kind;

  /// 연결 상태(Ready/Connecting/Banned).
  final String state;

  /// 사용된 전송 프로토콜.
  final String transportProtocol;

  const FlorestaPeerInfo({
    required this.id,
    required this.address,
    required this.services,
    required this.servicesNames,
    required this.relayTxs,
    required this.userAgent,
    required this.inbound,
    required this.initialHeight,
    required this.timeOffset,
    required this.kind,
    required this.state,
    required this.transportProtocol,
  });

  /// RPC `getpeerinfo` 항목을 파싱한다.
  factory FlorestaPeerInfo.fromRpc(Map<String, dynamic> json) {
    int intOf(String key) => (json[key] as num?)?.toInt() ?? 0;
    return FlorestaPeerInfo(
      id: intOf('id'),
      address: json['address'] as String? ?? '',
      services: json['services'] as String? ?? '',
      servicesNames: (json['servicesnames'] as List?)?.cast<String>() ?? const [],
      relayTxs: json['relaytxes'] as bool? ?? false,
      userAgent: json['user_agent'] as String? ?? '',
      inbound: json['inbound'] as bool? ?? false,
      initialHeight: intOf('initial_height'),
      timeOffset: intOf('timeoffset'),
      kind: json['kind'] as String? ?? '',
      state: json['state'] as String? ?? '',
      transportProtocol: json['transport_protocol'] as String? ?? '',
    );
  }

  /// 연결돼 있고 핸드셰이크까지 끝난 피어인지. full validation 근거로 쓰기 좋다.
  bool get isReady => state.toLowerCase() == 'ready';
}
