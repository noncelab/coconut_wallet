import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:test/test.dart';

String host = 'regtest-electrum.coconut.onl';
int port = 60401;
bool ssl = true;

void main() {
  group(
    'live Electrum regtest',
    () {
      late ElectrumService client;
      setUpAll(() async {
        client = ElectrumService();
        expect(await client.connect(host, port, ssl: ssl), isTrue);
      });
      tearDownAll(() => client.close());

      test('ping', () async {
        var result = await client.ping();

        expect(result, 'pong');
      });

      test('server.version', () async {
        /// param: ["electrs/0.10.5", ["1.1", "1.4"]]
        var result = await client.serverVersion();

        expect(result.contains('1.4'), isTrue);
      });

      test('blockchain.block.header', () async {
        var blockHeaderString =
            '0000002006226e46111a0b59caaf126043eb5bbf28c34f3a5e332a1fc7b2b73cf188910fc0cefb712ad31723702fab7a938fb966525001320c2b73b2a0cd7bc235a577fda9339666ffff7f2001000000';
        var result = await client.getBlockHeader(1);

        expect(result.runtimeType, String);
        expect(result, blockHeaderString);
      });

      test('blockchain.estimatefee', () async {
        /// 0.012229100000000001
        var result = await client.estimateFee(1);

        expect(result, isA<num>());
        expect(result >= 0 || result == -1, isTrue);
      });

      test('blockchain.scripthash.get_history', () async {
        var address = 'bcrt1qp26663xm90par286v03syukvjnkdfzyy88zh5s';
        var result = await client.getHistory(AddressType.p2wpkh, address);

        expect(result, isList);
        expect(result.first.height, greaterThan(0));
        expect(result.first.txHash, isNotEmpty);
      });

      test('blockchain.transaction.broadcast', () async {
        final previousNetwork = NetworkType.currentNetworkType;
        addTearDown(() => NetworkType.setNetworkType(previousNetwork));
        NetworkType.setNetworkType(NetworkType.regtest);
        final client = ElectrumService();
        final http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        addTearDown(() async {
          http.close(force: true);
          await client.close();
        });
        expect(await client.connect('regtest-electrum.coconut.onl', 60401), isTrue);
        expect(
          (await client.serverFeatures()).genesisHash,
          '0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206',
        );
        // Public synthetic seed, unique public passphrase; never import user key material.
        final fixture = 'epic2-public-broadcast-${DateTime.now().toUtc().microsecondsSinceEpoch}';
        final vault = SingleSignatureVault.fromEntropy(
          Uint8List(16),
          passphrase: Uint8List.fromList(utf8.encode(fixture)),
        );
        final address = vault.getAddress(0);
        final destination = vault.getAddress(1);
        expect(address, startsWith('bcrt1'));
        expect(destination, startsWith('bcrt1'));
        expect(await client.getUnspentList(AddressType.p2wpkh, address), isEmpty);
        final env = File('regtest.env').readAsLinesSync();
        final api = env
            .singleWhere((line) => line.startsWith('API_HOST='))
            .substring(9)
            .trim()
            .replaceAll(RegExp(r'''^['"]|['"]$'''), '');
        final uri = Uri.parse('${api.replaceFirst(RegExp(r"/+$"), "")}/faucet/request');
        expect(uri.scheme, 'https');
        final request = await http.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'address': address, 'amount': 0.00021}));
        final response = await request.close();
        await response.drain<void>();
        expect(
          response.statusCode,
          anyOf(200, 201),
          reason: 'A fresh fixture requires one successful normal faucet request.',
        );
        var coins = await client.getUnspentList(AddressType.p2wpkh, address);
        for (var attempt = 0; coins.isEmpty && attempt < 30; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 2));
          coins = await client.getUnspentList(AddressType.p2wpkh, address);
        }
        expect(coins, hasLength(1));
        expect(coins.single.value, 21000);
        final coin = coins.single;
        final transaction = Transaction.forSweep(
          [Utxo(coin.txHash, coin.txPos, coin.value, "m/84'/1'/0'/0/0")],
          destination,
          1.0,
          vault,
        );
        final signed = Psbt.parse(
          vault.addSignatureToPsbt(Psbt.fromTransaction(transaction, vault).serialize()),
        ).getSignedTransaction(AddressType.p2wpkh);
        final raw = signed.serialize();
        final expectedId = signed.transactionHash;
        final actualId = await client.broadcast(raw);
        expect(actualId, expectedId);
        expect(await client.getTransaction(actualId, verbose: false), raw);
        print('Fresh regtest broadcast verified: $actualId');
      }, timeout: const Timeout(Duration(minutes: 3)));

      /// unconfirmed transaction:
      test('blockchain.transaction.get returns error for unknown transaction', () async {
        // not found message: {code: 2, message: No such mempool or blockchain transaction. Use gettransaction for wallet transactions.}
        var txHash = '12d89567d4fdfef1ddd04fe786c6b9df1c52c124b9bcf456117c472cf7718413';
        await expectLater(
          client.getTransaction(txHash, verbose: true),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('HTTP 404: Transaction not found'))),
        );
      });

      /// confirmed transaction:
      test('blockchain.transaction.get returns confirmed transaction', () async {
        // not found message: {code: 2, message: No such mempool or blockchain transaction. Use gettransaction for wallet transactions.}
        var txHash = 'f21ffa3e814576b301182e710768f42cf5daa503a978b965cf0d1d4d49484712';
        var result = await client.getTransaction(txHash, verbose: true);

        expect(result, isNotEmpty);
      });

      test('mempool.get_fee_histogram', () async {
        var result = await client.getMempoolFeeHistogram();

        for (var fee in result) {
          print('$fee / ${fee.runtimeType}');
          for (var e in fee) {
            print('  $e / ${e.runtimeType}');
          }
        }
        expect(result, isList);
      });

      test('blockchain.headers.subscribe', () async {
        var result = await client.getCurrentBlock();

        expect(result.height, greaterThan(0));
        expect(result.hex.runtimeType, String);
        expect(result.hex, isNotEmpty);
      });
    },
    skip:
        const bool.fromEnvironment('RUN_ELECTRUM_E2E')
            ? false
            : 'Requires --dart-define=RUN_ELECTRUM_E2E=true; requests regtest funds and broadcasts.',
  );
}
