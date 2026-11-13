import 'dart:async';
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

    when(mockSocketManager.connect(any, any, ssl: anyNamed('ssl'))).thenAnswer((_) async {
      return true;
    });
  });

  test('connect should call socketManager.connect', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);

    verify(mockSocketManager.connect('localhost', 50001, ssl: false)).called(1);
  });

  test('ping should return pong when connected', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);

    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({'id': id, 'result': null});
    });
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'server.ping');
    });

    final response = await electrumClient.ping();

    expect(response, 'pong');
    expect(electrumClient.reqId, 1);
  });

  test('getBlockHeader should return block header', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.block.header');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

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
      throwsA(
        isA<Exception>().having((e) => e.toString(), 'message', 'Exception: Only numbers greater than 0 are available'),
      ),
    );
  });

  test('getBalance should return GetBalanceRes Object', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.get_balance');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': {'confirmed': 0, 'unconfirmed': 0},
      });
    });
    final response = await electrumClient.getBalance(
      AddressType.p2wpkh,
      'bcrt1qp26663xm90par286v03syukvjnkdfzyy88zh5s',
    );

    expect(response.confirmed, 0);
    expect(response.unconfirmed, 0);
  });

  test('getHistory should return GetTxHistoryRes List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.get_history');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          {'height': 1, 'tx_hash': 'txHash1'},
          {'height': 2, 'tx_hash': 'txHash2'},
        ],
      });
    });
    final response = await electrumClient.getHistory(
      AddressType.p2wpkh,
      'bcrt1qp26663xm90par286v03syukvjnkdfzyy88zh5s',
    );

    expect(response, isList);
    expect(response[0].height, 1);
    expect(response[0].txHash, 'txHash1');
    expect(response[1].height, 2);
    expect(response[1].txHash, 'txHash2');
  });
  test('getUnspentList should return ListUnspentRes List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.listunspent');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          {'height': 1, 'tx_hash': 'txHash1', 'tx_pos': 1, 'value': 1000},
          {'height': 2, 'tx_hash': 'txHash2', 'tx_pos': 0, 'value': 2000},
        ],
      });
    });
    final response = await electrumClient.getUnspentList(
      AddressType.p2wpkh,
      'bcrt1qp26663xm90par286v03syukvjnkdfzyy88zh5s',
    );

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
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.transaction.broadcast');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({'id': id, 'result': 'txIdString'});
    });
    final response = await electrumClient.broadcast('0123456789abcdef');

    expect(response.runtimeType, String);
    expect(response, 'txIdString');
  });
  test('getTransaction should return RawTransaction String', () async {
    const genesisCoinbase =
        '01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff4d04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73ffffffff0100f2052a01000000434104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac00000000';
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.transaction.get');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({'id': id, 'result': genesisCoinbase});
    });
    final response = await electrumClient.getTransaction(
      '4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b',
    );

    expect(response.runtimeType, String);
    expect(response, genesisCoinbase);
  });
  test('getMempoolFeeHistogram should return Num List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'mempool.get_fee_histogram');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          [1, 1000],
          [2, 2000],
        ],
      });
    });
    final response = await electrumClient.getMempoolFeeHistogram();

    expect(response[0], [1, 1000]);
    expect(response[1], [2, 2000]);
  });

  test('getCurrentBlock should return BlockHeaderSubscribe Object', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.headers.subscribe');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': {'height': 100, 'hex': '0123456789abcdef'},
      });
    });
    final response = await electrumClient.getCurrentBlock();

    expect(response.height, 100);
    expect(response.hex, '0123456789abcdef');
  });

  test('getMempoolFeeHistogram should return empty List when json is empty', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'mempool.get_fee_histogram');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({'id': id, 'result': []});
    });
    final response = await electrumClient.getMempoolFeeHistogram();

    expect(response, isEmpty);
  });

  test('serverFeatures should return ServerFeaturesRes Object', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'server.features');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': {
          'server_version': '1.4.2',
          'genesis_hash': 'genesis123',
          'protocol_min': '1.4',
          'protocol_max': '1.4.2',
          'hash_function': 'sha256',
          'hosts': {
            'test.host': {'ssl_port': 50002, 'tcp_port': 50001},
          },
        },
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
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'server.version');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': ['ElectrumX 1.4.2', '1.4'],
      });
    });
    final response = await electrumClient.serverVersion();

    expect(response, ['ElectrumX 1.4.2', '1.4']);
  });

  test('estimateFee should return fee value', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.estimatefee');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

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
      throwsA(
        isA<Exception>().having((e) => e.toString(), 'message', 'Exception: Only numbers greater than 0 are available'),
      ),
    );
  });

  test('getMempool should return GetMempoolRes List', () async {
    await electrumClient.connect('localhost', 50001, ssl: false);
    when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
    when(mockSocketManager.send(any)).thenAnswer((invocation) async {
      Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
      expect(jsonReq['method'], 'blockchain.scripthash.get_mempool');
    });
    when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
      var id = invocation.positionalArguments[0];
      var completer = invocation.positionalArguments[1];

      completer.complete({
        'id': id,
        'result': [
          {'height': 0, 'tx_hash': 'txHash1', 'fee': 1000},
          {'height': 0, 'tx_hash': 'txHash2', 'fee': 2000},
        ],
      });
    });
    final response = await electrumClient.getMempool(
      AddressType.p2wpkh,
      'bcrt1qp26663xm90par286v03syukvjnkdfzyy88zh5s',
    );

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

  group('getPreviousTransactions', () {
    const legacyParent =
        '0100000001d06050454abde3bdd947312b9f54439acb097608a47b0b36a23d76820a3a4044000000006a4730440220360e6c5348a85270a3b14b84780ad56cd189bd12848b125c488a678f5e0d95be022011e51cfd849e5d005fc5352885a954c756f6073de633545f6045c4ad96ac9be0012102742148dd2f73733ce36202798298e8294b42b5aabf1ba87a9bb9b0167abfb8dfffffffff01277c5d000000000016001424b3e9491f3eadd9862389d98480acf89bdab07800000000';
    const segwitParent =
        '02000000000101a463a7a78daffa1bdb1248121adb14b94f70a1fabffc81637f4049c3d65cc69f00000000000000008002e803000000000000160014b247a00acc1cc2c0b4be0d3c38d866f9c08d244a051f000000000000160014d32c7c4dbb9457cff124c786bac87a9a706c5b3a02483045022100c2ce833d29b2bc4048e54fb5a9cb5131f31fe1254d4510339f3bfa2b6c3fe8120220576e45c680b2ab2fa184cf2b6caf7a165b1d5fc61cc165073017104011bfdc42012103324172078ccc5a19cf6db18b0c4bbd135b9d86131d6666bbd494c9474b3eb52600000000';
    late String legacyHash;
    late String segwitHash;
    late Map<String, String> served;
    late List<String> requested;

    String spend(String hash, int index) =>
        '${List.generate(32, (i) => hash.substring(62 - i * 2, 64 - i * 2)).join()}'
        '${index.toRadixString(16).padLeft(2, '0')}00000000ffffffff';

    Transaction child(List<(String, int)> inputs) => Transaction.parse(
      '01000000'
      '${inputs.length.toRadixString(16).padLeft(2, '0')}'
      '${inputs.map((input) => spend(input.$1, input.$2)).join()}'
      '01e803000000000000160014${'11' * 20}'
      '00000000',
    );

    setUp(() async {
      NetworkType.setNetworkType(NetworkType.regtest);
      legacyHash = Transaction.parse(legacyParent).transactionHash;
      segwitHash = Transaction.parse(segwitParent).transactionHash;
      served = {legacyHash: legacyParent, segwitHash: segwitParent};
      requested = [];
      final pendingHashes = <int, String>{};
      await electrumClient.connect('localhost', 50001, ssl: false);
      when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.connected);
      when(mockSocketManager.send(any)).thenAnswer((invocation) async {
        final Map<String, dynamic> request = jsonDecode(invocation.positionalArguments[0]);
        final hash = (request['params'] as List).first as String;
        requested.add(hash);
        pendingHashes[request['id'] as int] = hash;
      });
      when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
        final id = invocation.positionalArguments[0] as int;
        (invocation.positionalArguments[1] as Completer).complete({'id': id, 'result': served[pendingHashes[id]]});
      });
    });

    test('returns the previous transaction of every input in input order, fetching each parent once', () async {
      final tx = child([(legacyHash, 0), (segwitHash, 1), (legacyHash, 0)]);

      final previous = await electrumClient.getPreviousTransactions(tx);

      expect(previous.map((prev) => prev.transactionHash), [legacyHash, segwitHash, legacyHash]);
      expect(requested..sort(), [legacyHash, segwitHash]..sort());
    });

    test('keeps the other parents when one parent cannot be parsed', () async {
      served[segwitHash] = 'zz';
      final tx = child([(legacyHash, 0), (segwitHash, 1)]);

      final previous = await electrumClient.getPreviousTransactions(tx);

      expect(previous.map((prev) => prev.transactionHash), [legacyHash]);
    });

    test('drops a parent whose hash does not match the requested hash', () async {
      served[segwitHash] = legacyParent;
      final tx = child([(legacyHash, 0), (segwitHash, 1)]);

      final previous = await electrumClient.getPreviousTransactions(tx);

      expect(previous.map((prev) => prev.transactionHash), [legacyHash]);
    });

    test('does not fetch anything for a coinbase transaction', () async {
      const genesisCoinbase =
          '01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff4d04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73ffffffff0100f2052a01000000434104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac00000000';

      final previous = await electrumClient.getPreviousTransactions(Transaction.parse(genesisCoinbase));

      expect(previous, isEmpty);
      expect(requested, isEmpty);
    });

    test('getTransaction returns the transaction that was asked for', () async {
      expect(await electrumClient.getTransaction(legacyHash), legacyParent);
    });

    test('getTransaction refuses a different transaction than the one asked for', () async {
      served[segwitHash] = legacyParent;

      expect(() => electrumClient.getTransaction(segwitHash), throwsA(isA<FormatException>()));
    });

    test('uses transactions from existingTxList without fetching them', () async {
      final tx = child([(legacyHash, 0), (segwitHash, 1)]);

      final previous = await electrumClient.getPreviousTransactions(
        tx,
        existingTxList: [Transaction.parse(segwitParent)],
      );

      expect(previous.map((prev) => prev.transactionHash), [legacyHash, segwitHash]);
      expect(requested, [legacyHash]);
    });
  });

  group('GetTxHistoryRes Set', () {
    test('Should remove duplicates when adding identical GetTxHistoryRes objects to Set', () {
      final history1 = GetTxHistoryRes(height: 100, txHash: 'abc123');
      final history2 = GetTxHistoryRes(height: 100, txHash: 'abc123');

      final historySet = <GetTxHistoryRes>{history1, history2};

      expect(historySet.length, 1);
      expect(historySet.first, history1);
    });

    test('Should include all different GetTxHistoryRes objects when added to Set', () {
      final history1 = GetTxHistoryRes(height: 100, txHash: 'abc123');
      final history2 = GetTxHistoryRes(height: 200, txHash: 'abc123');
      final history3 = GetTxHistoryRes(height: 100, txHash: 'def456');

      final historySet = <GetTxHistoryRes>{history1, history2, history3};

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
      when(mockSocketManager.send(any)).thenAnswer((invocation) async {
        Map<String, dynamic> jsonReq = jsonDecode(invocation.positionalArguments[0]);
        expect(jsonReq['method'], 'server.ping');
      });
      when(mockSocketManager.setCompleter(any, any)).thenAnswer((invocation) {
        var id = invocation.positionalArguments[0];
        var completer = invocation.positionalArguments[1];

        completer.complete({'id': id, 'error': 'Server error occurred'});
      });

      expect(() => electrumClient.ping(), throwsA('Server error occurred'));
    });

    test('should throw error when not connected to server', () async {
      when(mockSocketManager.connectionStatus).thenReturn(SocketConnectionStatus.terminated);

      expect(() => electrumClient.ping(), throwsA('Can not connect to the server. Please connect and try again.'));
    });
  });
}
