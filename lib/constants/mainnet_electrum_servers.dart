import 'package:coconut_wallet/services/model/response/electrum_domains_response.dart';

/// 기본 Electrum 서버 목록
/// API 서버에 문제가 있을 때 사용됩니다.
const mainnetElectrumServers = [
  ElectrumDomain(
    domain: 'blockstream.info',
    port: 700,
    ssl: true,
  ),
  ElectrumDomain(
    domain: 'electrum.acinq.co',
    port: 50002,
    ssl: true,
  ),
  ElectrumDomain(
    domain: 'ecdsa.net',
    port: 110,
    ssl: true,
  ),
  ElectrumDomain(
    domain: 'electrum1.bluewallet.io',
    port: 443,
    ssl: true,
  ),
  ElectrumDomain(
    domain: 'bitcoin.lukechilds.co',
    port: 50002,
    ssl: true,
  ),
  ElectrumDomain(
    domain: 'electrum.jochen-hoenicke.de',
    port: 50006,
    ssl: true,
  ),
  ElectrumDomain(
    domain: 'mainnet.foundationdevices.com',
    port: 50002,
    ssl: true,
  ),
  ElectrumDomain(
    domain: 'electrum.emzy.de',
    port: 50002,
    ssl: true,
  ),
];
