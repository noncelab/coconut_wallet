import 'package:coconut_wallet/model/node/floresta_peer_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlorestaPeerInfo.fromRpc', () {
    test('getpeerinfo 항목을 파싱한다', () {
      final peer = FlorestaPeerInfo.fromRpc(const {
        'id': 3,
        'address': '10.0.0.1:18444',
        'services': '0000000000000409',
        'servicesnames': ['NETWORK', 'WITNESS'],
        'relaytxes': true,
        'user_agent': '/Satoshi:26.0/',
        'inbound': false,
        'initial_height': 120,
        'timeoffset': -2,
        'kind': 'Regular',
        'state': 'Ready',
        'transport_protocol': 'V1',
      });

      expect(peer.id, 3);
      expect(peer.address, '10.0.0.1:18444');
      expect(peer.services, '0000000000000409');
      expect(peer.servicesNames, ['NETWORK', 'WITNESS']);
      expect(peer.relayTxs, isTrue);
      expect(peer.userAgent, '/Satoshi:26.0/');
      expect(peer.inbound, isFalse);
      expect(peer.initialHeight, 120);
      expect(peer.timeOffset, -2);
      expect(peer.kind, 'Regular');
      expect(peer.isReady, isTrue);
    });

    test('누락 필드는 안전한 기본값으로 처리한다', () {
      final peer = FlorestaPeerInfo.fromRpc(const {});
      expect(peer.id, 0);
      expect(peer.address, '');
      expect(peer.servicesNames, isEmpty);
      expect(peer.relayTxs, isFalse);
      expect(peer.initialHeight, 0);
      expect(peer.isReady, isFalse);
    });
  });
}
