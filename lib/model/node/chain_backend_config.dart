/// 체인 데이터 접근 백엔드의 종류.
///
/// 외부 Floresta는 Electrum 포트(`isFloresta=false`)로 붙고 RPC 포트만 별도로 쓰므로
/// `electrum`과 구분되는 별도 모드다.
enum ChainBackendType { electrum, embeddedFloresta, externalFloresta }

/// [NodeProvider]가 현재 사용 중인 백엔드 설정(인메모리, 비영속).
class ChainBackendConfig {
  final ChainBackendType type;
  final int rpcPort; // electrum=0

  const ChainBackendConfig.electrum() : type = ChainBackendType.electrum, rpcPort = 0;

  const ChainBackendConfig.embeddedFloresta({this.rpcPort = 8332})
    : assert(rpcPort > 0),
      type = ChainBackendType.embeddedFloresta;

  const ChainBackendConfig.externalFloresta({required this.rpcPort})
    : assert(rpcPort > 0),
      type = ChainBackendType.externalFloresta;

  bool get isEmbedded => type == ChainBackendType.embeddedFloresta;

  bool get isFloresta => type != ChainBackendType.electrum;
}
