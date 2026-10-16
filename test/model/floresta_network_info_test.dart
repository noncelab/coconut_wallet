import 'package:coconut_wallet/model/node/floresta_network_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlorestaNetworkInfo.fromRpc', () {
    test('getnetworkinfo 결과(Core 스타일 키)를 파싱한다', () {
      final info = FlorestaNetworkInfo.fromRpc(const {
        'version': 1000000,
        'subversion': '/Floresta:0.9.0/',
        'protocolversion': 70016,
        'localservices': '0000000000000409',
        'localrelay': true,
        'connections': 4,
        'connections_in': 1,
        'connections_out': 3,
        'networkactive': true,
        'relayfee': 0.00001,
        'warnings': ['something'],
      });

      expect(info.version, 1000000);
      expect(info.subversion, '/Floresta:0.9.0/');
      expect(info.protocolVersion, 70016);
      expect(info.connections, 4);
      expect(info.connectionsIn, 1);
      expect(info.connectionsOut, 3);
      expect(info.networkActive, isTrue);
      expect(info.relayFee, closeTo(0.00001, 1e-12));
      expect(info.warnings, ['something']);
    });

    test('누락 필드는 안전한 기본값으로 처리한다', () {
      final info = FlorestaNetworkInfo.fromRpc(const {});
      expect(info.connections, 0);
      expect(info.connectionsIn, isNull);
      expect(info.networkActive, isFalse);
      expect(info.relayFee, isNull);
      expect(info.warnings, isEmpty);
    });
  });
}
