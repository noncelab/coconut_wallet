import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:test/test.dart';

const host = 'electrum.coconut.onl';
const port = 443;

/// 거래소 일괄 출금 형태의 mainnet 거래 (입력 204개·출력 260개, 입력 249개·출력 1개)
const largeTransactionIds = [
  '4349b48861b5df6f497a654c8025d02b66d2c6b34df0a894ac2db46556adfb84',
  'd2d614abaad0cf8a79c42798c411d355fbfdfd67b8e741f6f6242b1a1a1e40c7',
];

void main() {
  group(
    'live Electrum mainnet large transactions',
    () {
      late ElectrumService client;
      setUpAll(() async {
        NetworkType.setNetworkType(NetworkType.mainnet);
        client = ElectrumService();
        expect(await client.connect(host, port, ssl: true), isTrue);
      });
      tearDownAll(() => client.close());

      for (final txid in largeTransactionIds) {
        test('$txid: every input gets its previous transaction', () async {
          final tx = Transaction.parse(await client.getTransaction(txid, timeout: const Duration(seconds: 60)));

          final previousTransactions = await client.getPreviousTransactions(tx);

          expect(previousTransactions, hasLength(tx.inputs.length));
        }, timeout: const Timeout(Duration(minutes: 5)));
      }
    },
    skip:
        const bool.fromEnvironment('RUN_ELECTRUM_MAINNET_E2E')
            ? false
            : 'Requires --dart-define=RUN_ELECTRUM_MAINNET_E2E=true; queries mainnet Electrum and mempool.space.',
  );
}
