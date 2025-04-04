import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/network/socket/socket_manager.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'electrum_service_test.mocks.dart';

@GenerateMocks([SocketManager])
void main() {
  late ElectrumService electrumClient;
  late MockSocketManager mockSocketManager;

  setUpAll(() {
    mockSocketManager = MockSocketManager();
    electrumClient = ElectrumService(socketManager: mockSocketManager);

    when(mockSocketManager.connect(any, any, ssl: anyNamed('ssl'))).thenAnswer((_) async {});
  });

  test('connect should call socketManager.connect', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);

    verify(mockSocketManager.connect('localhost', 50001, ssl: false)).called(1);
  });

  test('ping should return pong when connected', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);

    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({'id': id, 'result': null});
    });
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'server.ping');
    });

    final response = await electrumClient.ping();

    expect(response, 'pong');
    expect(electrumClient.reqId, 1);
  });

  test('getBlockHeader should return block header', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.block.header');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({'id': id, 'result': 'block header data'});
    });
    final response = await electrumClient.getBlockHeader(100);

    expect(response, 'block header data');
  });

  test('getBlockHeader should throw error when height is negative', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);

    expect(
        () => electrumClient.getBlockHeader(-1),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message',
            'Exception: Only numbers greater than 0 are available')));
  });

  test('getBalance should return GetBalanceRes Object', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.get_balance');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': {'confirmed': 0, 'unconfirmed': 0}
      });
    });
    final response = await electrumClient.getBalance(AddressType.p2wpkh, '0123456789abcdef');

    expect(response.confirmed, 0);
    expect(response.unconfirmed, 0);
  });

  test('getHistory should return GetHistoryRes List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.get_history');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          {'height': 1, 'tx_hash': 'txHash1'},
          {'height': 2, 'tx_hash': 'txHash2'}
        ]
      });
    });
    final response = await electrumClient.getHistory(AddressType.p2wpkh, '0123456789abcdef');

    expect(response, isList);
    expect(response[0].height, 1);
    expect(response[0].txHash, 'txHash1');
    expect(response[1].height, 2);
    expect(response[1].txHash, 'txHash2');
  });
  test('getUnspentList should return ListUnspentRes List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.listunspent');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          {'height': 1, 'tx_hash': 'txHash1', 'tx_pos': 1, 'value': 1000},
          {'height': 2, 'tx_hash': 'txHash2', 'tx_pos': 0, 'value': 2000}
        ]
      });
    });
    final response = await electrumClient.getUnspentList(AddressType.p2wpkh, '0123456789abcdef');

    expect(response, isList);
    expect(response[0].height, 1);
    expect(response[0].txHash, 'txHash1');
    expect(response[0].txPos, 1);
    expect(response[0].value, 1000);
    expect(response[1].height, 2);
    expect(response[1].txHash, 'txHash2');
    expect(response[1].txPos, 0);
    expect(response[1].value, 2000);
  });
  test('broadcast should return TransactionId String', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.transaction.broadcast');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({'id': id, 'result': 'txIdString'});
    });
    final response = await electrumClient.broadcast('0123456789abcdef');

    expect(response.runtimeType, String);
    expect(response, 'txIdString');
  });
  test('getTransaction should return RawTransaction String', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.transaction.get');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({'id': id, 'result': 'txIdString'});
    });
    final response = await electrumClient.getTransaction('0123456789abcdef');

    expect(response.runtimeType, String);
    expect(response, 'txIdString');
  });
  test('getMempoolFeeHistogram should return Num List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'mempool.get_fee_histogram');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          [1, 1000],
          [2, 2000]
        ]
      });
    });
    final response = await electrumClient.getMempoolFeeHistogram();

    expect(response[0], [1, 1000]);
    expect(response[1], [2, 2000]);
  });

  test('getCurrentBlock should return BlockHeaderSubscribe Object', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.headers.subscribe');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': {'height': 100, 'hex': '0123456789abcdef'}
      });
    });
    final response = await electrumClient.getCurrentBlock();

    expect(response.height, 100);
    expect(response.hex, '0123456789abcdef');
  });

  test('getMempoolFeeHistogram should return empty List when json is empty', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'mempool.get_fee_histogram');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({'id': id, 'result': []});
    });
    final response = await electrumClient.getMempoolFeeHistogram();

    expect(response, isEmpty);
  });

  test('serverFeatures should return ServerFeaturesRes Object', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'server.features');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': {
          'server_version': '1.4.2',
          'genesis_hash': 'genesis123',
          'protocol_min': '1.4',
          'protocol_max': '1.4.2',
          'hash_function': 'sha256',
          'hosts': {
            'test.host': {'ssl_port': 50002, 'tcp_port': 50001}
          }
        }
      });
    });
    final response = await electrumClient.serverFeatures();

    expect(response.serverVersion, '1.4.2');
    expect(response.genesisHash, 'genesis123');
    expect(response.protocolMin, '1.4');
    expect(response.protocolMax, '1.4.2');
    expect(response.hashFunction, 'sha256');
    expect(response.hosts['test.host']?.sslPort, 50002);
    expect(response.hosts['test.host']?.tcpPort, 50001);
  });

  test('serverVersion should return version List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'server.version');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': ['ElectrumX 1.4.2', '1.4']
      });
    });
    final response = await electrumClient.serverVersion();

    expect(response, ['ElectrumX 1.4.2', '1.4']);
  });

  test('estimateFee should return fee value', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.estimatefee');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({'id': id, 'result': 0.00001234});
    });
    final response = await electrumClient.estimateFee(6);

    expect(response, 0.00001234);
  });

  test('estimateFee should throw error when targetConfirmation is negative', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);

    expect(
        () => electrumClient.estimateFee(-1),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message',
            'Exception: Only numbers greater than 0 are available')));
  });

  test('getMempool should return GetMempoolRes List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((_) async {
      Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.get_mempool');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
      var id = _.positionalArguments[0];
      var completer = _.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          {'height': 0, 'tx_hash': 'txHash1', 'fee': 1000},
          {'height': 0, 'tx_hash': 'txHash2', 'fee': 2000}
        ]
      });
    });
    final response = await electrumClient.getMempool(AddressType.p2wpkh, '0123456789abcdef');

    expect(response, isList);
    expect(response[0].height, 0);
    expect(response[0].txHash, 'txHash1');
    expect(response[0].fee, 1000);
    expect(response[1].height, 0);
    expect(response[1].txHash, 'txHash2');
    expect(response[1].fee, 2000);
  });

  test('close should cancel ping timer and disconnect socket', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.disconnect()).thenAnswer((_) async {});

    await electrumClient.close();

    verify(mockSocketManager.disconnect()).called(1);
  });

  group('GetHistoryRes Set', () {
    test('Should remove duplicates when adding identical GetHistoryRes objects to Set', () {
      final history1 = GetHistoryRes(height: 100, txHash: 'abc123');
      final history2 = GetHistoryRes(height: 100, txHash: 'abc123');

      final historySet = <GetHistoryRes>{history1, history2};

      expect(historySet.length, 1);
      expect(historySet.first, history1);
    });

    test('Should include all different GetHistoryRes objects when added to Set', () {
      final history1 = GetHistoryRes(height: 100, txHash: 'abc123');
      final history2 = GetHistoryRes(height: 200, txHash: 'abc123');
      final history3 = GetHistoryRes(height: 100, txHash: 'def456');

      final historySet = <GetHistoryRes>{history1, history2, history3};

      expect(historySet.length, 3);
      expect(historySet.contains(history1), true);
      expect(historySet.contains(history2), true);
      expect(historySet.contains(history3), true);
    });
  });

  group('_call error handling', () {
    test('should throw error when server returns error response', () async {
      await electrumClient.connect('localhost', 50001, ssl: false);
      when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
      when(mockSocketManager.send(any)).thenAnswer((_) async {
        Map<String, dynamic> jsonReq = jsonDecode(_.positionalArguments[0]);
        expect(jsonReq['method'], 'server.ping');
      });
      when(mockSocketManager.setCompleter(any, any)).thenAnswer((_) {
        var id = _.positionalArguments[0];
        var completer = _.positionalArguments[1];

        completer.complete({'id': id, 'error': 'Server error occurred'});
      });

      expect(() => electrumClient.ping(), throwsA('Server error occurred'));
    });

    test('should throw error when not connected to server', () async {
      when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.terminated);

      expect(() => electrumClient.ping(),
          throwsA('Can not connect to the server. Please connect and try again.'));
    });
  });
}
