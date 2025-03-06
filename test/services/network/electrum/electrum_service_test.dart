@Tags(['unit', 'network'])
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/services/network/electrum/electrum_client.dart';
import 'package:coconut_wallet/services/network/electrum/electrum_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'electrum_service_test.mocks.dart';

@GenerateMocks([ElectrumClient])
void main() async {
  group('electrumService Tests', () {
    SinglesigWalletListItem wallet = SinglesigWalletListItem(
        id: 1,
        name: 'test',
        colorIndex: 0,
        iconIndex: 0,
        descriptor:
            "wpkh([98C7D774/84'/1'/0']vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7/<0;1>/*)#7ra9g9d8",
        receiveUsedIndex: -1,
        changeUsedIndex: -1);
    late MockElectrumClient client;
    late ElectrumService electrumService;

    setUp(() {
      client = MockElectrumClient();
      when(client.connectionStatus)
          .thenReturn(SocketConnectionStatus.connected);
      electrumService =
          ElectrumService('localhost', 1234, ssl: false, client: client);
      when(client.getTransaction(any)).thenAnswer((_) async => '');
      when(client.getHistory(any)).thenAnswer((_) async => []);
      when(client.getUnspentList(any)).thenAnswer((_) async => []);
      when(client.getCurrentBlock()).thenAnswer((_) async => BlockHeaderSubscribe(
          height: 1000,
          hex:
              '000000203075fe151ad71408f237b917e953f3056515087246b7b5d522120c6fb9e65b166907739518f1a8d826146a96079c4d018d9695161645a78d5bdfe76ef2a08bdc7c647b67ffff7f2000000000'));
    });

    test('electrumService factory', () {
      MockElectrumClient disconnectedClient = MockElectrumClient();
      when(disconnectedClient.connectionStatus)
          .thenReturn(SocketConnectionStatus.reconnecting);
      when(disconnectedClient.connect(any, any, ssl: anyNamed('ssl')))
          .thenAnswer((_) async {});

      ElectrumService('localhost', 1234,
          ssl: false, client: disconnectedClient);

      verify(disconnectedClient.connect('localhost', 1234, ssl: false))
          .called(1);
    });

    test('connectSync', () async {
      MockElectrumClient mockClient = MockElectrumClient();
      when(mockClient.connect(any, any, ssl: false)).thenAnswer((_) async {});
      when(mockClient.connectionStatus)
          .thenReturn(SocketConnectionStatus.connected);

      await ElectrumService.connectSync('localhost', 1234,
          ssl: false, client: mockClient);

      verify(mockClient.connect(any, any, ssl: false)).called(1);
    });

    test('getReqId', () async {
      when(client.reqId).thenReturn(1);

      expect(electrumService.reqId, 1);
    });

    test('broadcast successful', () async {
      when(client.broadcast(any)).thenAnswer((_) async => 'transaction_id');
      var result = await electrumService.broadcast('raw_transaction');

      expect(result, 'transaction_id');
    });

    test('broadcast failure', () async {
      when(client.broadcast(any)).thenThrow(Exception('Broadcast Error'));

      expect(() => electrumService.broadcast('invalid_transaction'),
          throwsException);
    });

    test('broadcast failure with fee exceeds', () async {
      Map<String, dynamic> error = {
        'message': 'Fee exceeds',
      };
      when(client.broadcast(any)).thenThrow(error);

      await expectLater(electrumService.broadcast('invalid_transaction'),
          throwsA(isA<Map<String, dynamic>>()));
    });

    test('getNetworkMinimumFeeRate no-mempool-tx', () async {
      when(client.getMempoolFeeHistogram()).thenAnswer((_) async => []);
      var result = await electrumService.getNetworkMinimumFeeRate();
      expect(result, 1);
    });

    test('getNetworkMinimumFeeRate', () async {
      when(client.getMempoolFeeHistogram()).thenAnswer((_) async => [
            [5, 1000],
            [3, 2000]
          ]);
      var result = await electrumService.getNetworkMinimumFeeRate();
      expect(result, 3);
    });

    test('getTransaction successful', () async {
      when(client.getTransaction(any))
          .thenAnswer((_) async => 'transaction_data');
      var result = await electrumService.getTransaction('valid_tx_hash');
      expect(result, 'transaction_data');
    });

    test('getTransaction failure', () async {
      when(client.getTransaction(any))
          .thenThrow(Exception('Transaction Error'));

      await expectLater(
          electrumService.getTransaction('invalid_tx_hash'), throwsException);
    });

    test('getLatestBlock', () async {
      when(client.getCurrentBlock()).thenAnswer((_) async => BlockHeaderSubscribe(
          height: 1000,
          hex:
              '000000203075fe151ad71408f237b917e953f3056515087246b7b5d522120c6fb9e65b166907739518f1a8d826146a96079c4d018d9695161645a78d5bdfe76ef2a08bdc7c647b67ffff7f2000000000'));
      var result = await electrumService.getLatestBlock();
      expect(result.height, 1000);
    });

    test('etc api error', () async {
      when(client.getTransaction(any)).thenThrow('RPC ERROR');

      await expectLater(electrumService.getTransaction('invalid_tx_hash'),
          throwsA(isA<String>()));
    });

    test('rpc unknown error', () async {
      Map<String, dynamic> error = {
        'message': 'Unknown Error',
      };

      when(client.getTransaction(any)).thenThrow(error);

      await expectLater(electrumService.getTransaction('invalid_tx_hash'),
          throwsA(isA<Map<String, dynamic>>()));
    });

    group('fetchBlocksByHeight', () {
      test('should emit success state', () async {
        // Arrange
        when(client.getBlockHeader(1000)).thenAnswer((_) async =>
            '000000202a25b55e70596e07b52b0fba74fbe464e2e6677deb1cd8bd47670a7b6e8b027be601172e5dc38d15db848dcc66f5c75369765ea86d9c2f03dbbc35b46c218e6eec699d66ffff7f2001000000');
        when(client.getBlockHeader(1001)).thenAnswer((_) async =>
            '00000020c4f3f2bc22847efff536c6915adaf6dec28b7288d7ca3594d89eab0adb9d6b2c6046068db0248e07a723cc2170923cb861a165a3684f82827db834a9db2db708186b9d66ffff7f2000000000');

        // Act
        final states = await electrumService.getBlocksByHeight({1000, 1001});

        // Assert
        expect(states.length, 2);
        expect(states[1000]?.timestamp,
            DateTime.parse('2024-07-22 05:05:00 +09:00'));
        expect(states[1001]?.timestamp,
            DateTime.parse('2024-07-22 05:10:00 +09:00'));
      });
    });
  });
}
