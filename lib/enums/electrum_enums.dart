import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';

enum DefaultElectrumServer {
  coconut(
    ElectrumServer('electrum.coconut.onl', 443, true),
    'COCONUT',
    1,
    false, // isRegtest
  ),
  // self-signed 인증서를 쓰는 개인/커뮤니티 운영 서버들은 2026-09-02 기준 확인한 지문을 고정한다.
  // 서버 운영자가 인증서를 재발급하면 연결이 끊기므로, 그 경우 새 지문으로 갱신해야 한다.
  fulrum(
    ElectrumServer(
      'fulcrum2.not.fyi',
      51002,
      true,
      pinnedCertFingerprint:
          '16:0D:3E:0C:AD:F1:D1:D3:52:70:7E:9D:50:41:25:E1:8F:A2:E8:75:E1:11:AC:0D:56:FC:43:E9:26:2F:8D:3E',
    ),
    'FULRUM',
    2,
    false,
  ),
  nunchuk(ElectrumServer('mainnet.nunchuk.io', 51001, false), 'NUNCHUK', 3, false),
  acinq(ElectrumServer('electrum.acinq.co', 50002, true), 'ACINQ', 4, false),
  // 기존 mainnet.foundationdevices.com / electrum1.bluewallet.io 는 CA 인증서의 CN이 도메인과 달라 표준 검증에 실패
  // 실제 응답하는 인증서 도메인으로 접속 주소 업데이트
  foundationdevices(ElectrumServer('mainnet-0.foundation.xyz', 50002, true), 'FOUNDATIONDEVICES', 5, false),
  bluewallet(ElectrumServer('electrum2.bluewallet.io', 443, true), 'BLUEWALLET', 6, false),
  lukechilds(
    ElectrumServer(
      'bitcoin.lukechilds.co',
      50002,
      true,
      pinnedCertFingerprint:
          '4B:CD:74:8E:B9:34:A1:16:FD:6E:8D:08:D3:21:AC:2B:BE:03:50:E1:56:B6:21:92:9C:CA:55:18:BC:A7:36:4F',
    ),
    'LUKECHILDS',
    7,
    false,
  ),
  bitaroo(
    ElectrumServer(
      'electrum.bitaroo.net',
      50002,
      true,
      pinnedCertFingerprint:
          '4B:7E:A6:8D:5E:91:D8:7C:E0:DF:86:62:07:98:25:41:0A:58:59:C1:5E:AE:AB:3C:31:84:B5:E0:BE:B2:6B:D3',
    ),
    'BITAROO',
    8,
    false,
  ),
  // 인증서 만료: 2026-10-11. 만료/갱신 시 새 지문으로 교체 필요
  emzy(
    ElectrumServer(
      'electrum.emzy.de',
      50002,
      true,
      pinnedCertFingerprint:
          'B2:5D:A2:92:9C:0F:65:E0:16:CF:EC:2A:24:66:1F:FC:58:7F:DD:D8:32:F5:0A:ED:26:E0:5A:2E:DE:4C:DF:34',
    ),
    'EMZY',
    10,
    false,
  ),
  blockstream(ElectrumServer('blockstream.info', 700, true), 'BLOCKSTREAM', 11, false),

  // Testnet
  blockstreamTestnet(ElectrumServer('electrum.blockstream.info', 60002, true), 'BLOCKSTREAM_TESTNET', 95, false, true),
  qtornado(ElectrumServer('testnet.qtornado.com', 51002, true), 'QTORNADO_TESTNET', 96, false, true),

  // Regtest
  regtest(
    ElectrumServer('regtest-electrum.coconut.onl', 443, true),
    'REGTEST',
    99,
    true, // isRegtest
  );

  const DefaultElectrumServer(this.server, this.serverName, this.order, this.isRegtest, [this.isTestnet = false]);

  final ElectrumServer server;
  final String serverName;
  final int order;
  final bool isRegtest;
  final bool isTestnet;

  static DefaultElectrumServer fromServerType(String serverType) {
    return DefaultElectrumServer.values.firstWhere(
      (e) => e.serverName == serverType,
      orElse: () => DefaultElectrumServer.coconut,
    );
  }

  /// 현재 네트워크 타입(mainnet/testnet/regtest) 기준으로 host/port/ssl이 정확히 일치하는
  /// 기본 서버 항목을 찾는다. 없으면 null(=사용자가 지정한 진짜 커스텀 서버).
  static DefaultElectrumServer? findMatching(String host, int port, bool ssl) {
    final networkType = NetworkType.currentNetworkType;
    for (final e in DefaultElectrumServer.values) {
      final matchesFlavor =
          networkType == NetworkType.regtest
              ? e.isRegtest
              : networkType == NetworkType.testnet
              ? e.isTestnet
              : (!e.isRegtest && !e.isTestnet);
      if (matchesFlavor && e.server.host == host && e.server.port == port && e.server.ssl == ssl) {
        return e;
      }
    }
    return null;
  }

  /// Flavor에 따른 서버 리스트 반환
  static List<ElectrumServer> getServersByFlavor(bool isRegtestFlavor) {
    final filteredServers =
        DefaultElectrumServer.values
            .where((server) => server.isRegtest == isRegtestFlavor && !server.isTestnet)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    return List<ElectrumServer>.unmodifiable(filteredServers.map((e) => e.server).toList());
  }

  /// Mainnet 서버만 반환
  static List<ElectrumServer> get mainnetServers => getServersByFlavor(false);

  /// Regtest 서버만 반환
  static List<ElectrumServer> get regtestServers => getServersByFlavor(true);

  /// Testnet 서버만 반환
  static List<ElectrumServer> get testnetServers {
    final filteredServers =
        DefaultElectrumServer.values.where((server) => server.isTestnet).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return List<ElectrumServer>.unmodifiable(filteredServers.map((e) => e.server).toList());
  }
}
