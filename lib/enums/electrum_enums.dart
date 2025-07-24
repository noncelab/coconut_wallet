import 'package:coconut_wallet/model/node/electrum_server.dart';

enum DefaultElectrumServer {
  coconut(
    ElectrumServer(
      'electrum.coconut.onl',
      50001,
      true,
    ),
    'COCONUT',
    1,
  ),
  blockstream(
    ElectrumServer(
      'blockstream.info',
      700,
      true,
    ),
    'BLOCKSTREAM',
    2,
  ),
  acinq(
    ElectrumServer(
      'electrum.acinq.co',
      50002,
      true,
    ),
    'ACINQ',
    3,
  ),
  foundationdevices(
    ElectrumServer(
      'mainnet.foundationdevices.com',
      50002,
      true,
    ),
    'FOUNDATIONDEVICES',
    4,
  ),
  bluewallet(
    ElectrumServer(
      'electrum1.bluewallet.io',
      443,
      true,
    ),
    'BLUEWALLET',
    5,
  ),
  lukechilds(
    ElectrumServer(
      'bitcoin.lukechilds.co',
      50002,
      true,
    ),
    'LUKECHILDS',
    6,
  ),
  bitaroo(
    ElectrumServer(
      'electrum.bitaroo.net',
      50002,
      true,
    ),
    'BITAROO',
    7,
  ),
  jochenhoenicke(
    ElectrumServer(
      'electrum.jochen-hoenicke.de',
      50006,
      true,
    ),
    'JOCHENHOENICKE',
    8,
  ),
  emzy(
    ElectrumServer(
      'electrum.emzy.de',
      50002,
      true,
    ),
    'EMZY',
    9,
  ),
  ecdsa(
    ElectrumServer(
      'ecdsa.net',
      110,
      true,
    ),
    'ECDSA',
    10,
  ),

  // Regtest
  regtest(
    ElectrumServer(
      'regtest-electrum.coconut.onl',
      60401,
      true,
    ),
    'REGTEST',
    99,
  );

  const DefaultElectrumServer(
    this.server,
    this.serverName,
    this.order,
  );

  final ElectrumServer server;
  final String serverName;
  final int order;

  static DefaultElectrumServer fromServerType(String serverType) {
    return DefaultElectrumServer.values.firstWhere(
      (e) => e.serverName == serverType,
      orElse: () => DefaultElectrumServer.coconut,
    );
  }

  static final List<ElectrumServer> all = (() {
    final servers = DefaultElectrumServer.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return List<ElectrumServer>.unmodifiable(servers.map((e) => e.server).toList());
  })();
}
