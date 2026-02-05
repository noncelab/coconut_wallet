import 'package:coconut_wallet/model/node/electrum_server.dart';

enum DefaultElectrumServer {
  coconut(
    ElectrumServer('electrum.coconut.onl', 443, true),
    'COCONUT',
    1,
    false, // isRegtest
  ),
  fulrum(ElectrumServer('fulcrum2.not.fyi', 51002, true), 'FULRUM', 2, false),
  nunchuk(ElectrumServer('mainnet.nunchuk.io', 51001, false), 'NUNCHUK', 3, false),
  acinq(ElectrumServer('electrum.acinq.co', 50002, true), 'ACINQ', 4, false),
  foundationdevices(ElectrumServer('mainnet.foundationdevices.com', 50002, true), 'FOUNDATIONDEVICES', 5, false),
  bluewallet(ElectrumServer('electrum1.bluewallet.io', 443, true), 'BLUEWALLET', 6, false),
  lukechilds(ElectrumServer('bitcoin.lukechilds.co', 50002, true), 'LUKECHILDS', 7, false),
  bitaroo(ElectrumServer('electrum.bitaroo.net', 50002, true), 'BITAROO', 8, false),
  jochenhoenicke(ElectrumServer('electrum.jochen-hoenicke.de', 50006, true), 'JOCHENHOENICKE', 9, false),
  emzy(ElectrumServer('electrum.emzy.de', 50002, true), 'EMZY', 10, false),
  blockstream(ElectrumServer('blockstream.info', 700, true), 'BLOCKSTREAM', 11, false),

  // Regtest
  regtest(
    ElectrumServer('regtest-electrum.coconut.onl', 443, true),
    'REGTEST',
    99,
    true, // isRegtest
  );

  const DefaultElectrumServer(this.server, this.serverName, this.order, this.isRegtest);

  final ElectrumServer server;
  final String serverName;
  final int order;
  final bool isRegtest;

  static DefaultElectrumServer fromServerType(String serverType) {
    return DefaultElectrumServer.values.firstWhere(
      (e) => e.serverName == serverType,
      orElse: () => DefaultElectrumServer.coconut,
    );
  }

  /// Flavor에 따른 서버 리스트 반환
  static List<ElectrumServer> getServersByFlavor(bool isRegtestFlavor) {
    final filteredServers =
        DefaultElectrumServer.values.where((server) => server.isRegtest == isRegtestFlavor).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    return List<ElectrumServer>.unmodifiable(filteredServers.map((e) => e.server).toList());
  }

  /// Mainnet 서버만 반환
  static List<ElectrumServer> get mainnetServers => getServersByFlavor(false);

  /// Regtest 서버만 반환
  static List<ElectrumServer> get regtestServers => getServersByFlavor(true);
}
