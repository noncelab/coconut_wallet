import 'package:coconut_wallet/services/network/electrum/electrum_client.dart';
import 'package:test/test.dart';

String host = 'regtest-electrum.coconut.onl';
int port = 60401;
bool ssl = true;

Future<void> main() async {
  ElectrumClient client = ElectrumClient();
  await client.connect(host, port, ssl: ssl);

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

    expect(result.runtimeType, int);
    expect(result >= 0 || result == -1, isTrue);
  });

  test('blockchain.scripthash.get_history', () async {
    var script = '0014f03a3abb34f5f6da0599dd00171386986e17c0b6';
    var result = await client.getHistory(script);

    expect(result, isList);
    expect(result.first.height, 44035);
    expect(result.first.txHash,
        'c1daebab4109114179ce05e90242c5dc8c43ac15af26c508e08107b9a5641624');
  });

  test('blockchain.transaction.broadcast', () async {
    var rawTransaction =
        '02000000000101b9852d317b08716d0f7db93bee16bab85660999e257e6d872730517332a01de701000000000100000002df060000000000001600143b27ed3704820dd9935bfd9027c9a77b7c1f9762b80b000000000000160014e1c691c1207b0a316f4bd11af39764c29fef5e4d02473044022005e531ba0225f8df4ea2936be1aaab9ac6816d01a974d0b0ab204daf8f9a92c10220128adf146a66c59a434a9c7e5252e9c66e2e40f258f9c49d13138a41acaf72be01210246c18ea7c5624b87e5f65a60842c9a22b27ae7e3630a95abeb3545525976182400000000';
    var result = await client.broadcast(rawTransaction);

    expect(result, isNotEmpty);
    // });
  }, skip: 'Requires a raw transaction (hexadecimal) to actually broadcast.');

  /// unconfirmed transaction:
  test('blockchain.transaction.get', () async {
    var txHash =
        'f21ffa3e814576b301182e710768f42cf5daa503a978b965cf0d1d4d49484712';
    var result = await client.getTransaction(txHash, verbose: true);
    print(result);

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
}
