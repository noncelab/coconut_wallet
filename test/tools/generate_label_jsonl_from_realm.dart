import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/constants/realm_constants.dart';
import 'package:coconut_wallet/core/bip/329/bip329_converter.dart';
import 'package:coconut_wallet/core/bip/329/bip329_record.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:realm/realm.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      [
        'Usage: dart run test/tools/generate_label_jsonl_from_realm.dart <realm-path> <output-jsonl> [wallet-id]',
        '',
        'Example:',
        '  dart run test/tools/generate_label_jsonl_from_realm.dart '
            '/private/tmp/coconut_wallet_default.realm '
            'test_artifacts/large_memos.jsonl',
        '',
        'Example with wallet id:',
        '  dart run test/tools/generate_label_jsonl_from_realm.dart '
            '/private/tmp/coconut_wallet_default.realm '
            'test_artifacts/large_memos.jsonl '
            '3',
      ].join('\n'),
    );
    exitCode = 64;
    return;
  }

  final realmPath = args[0];
  final outputPath = args[1];
  final requestedWalletId = args.length >= 3 ? int.tryParse(args[2]) : null;

  final realm = Realm(
    Configuration.local(realmAllSchemas, path: realmPath, schemaVersion: kRealmVersion, isReadOnly: true),
  );
  try {
    final wallets = realm.all<RealmWalletBase>().toList();
    if (wallets.isEmpty) {
      stderr.writeln('No wallets found in Realm.');
      exitCode = 1;
      return;
    }

    final walletStats =
        wallets.map((wallet) {
          final txs = realm.query<RealmTransaction>('walletId == ${wallet.id}').length;
          final utxos = realm.query<RealmUtxo>('walletId == ${wallet.id} AND isDeleted == false').length;
          return (wallet: wallet, txs: txs, utxos: utxos);
        }).toList();

    final selected =
        requestedWalletId == null
            ? walletStats.firstWhere(
              (stat) => stat.txs == 150 && stat.utxos == 71,
              orElse: () => walletStats.reduce((a, b) => (a.txs + a.utxos) >= (b.txs + b.utxos) ? a : b),
            )
            : walletStats.firstWhere(
              (stat) => stat.wallet.id == requestedWalletId,
              orElse: () {
                stderr.writeln('Wallet id $requestedWalletId not found.');
                exit(1);
              },
            );

    final wallet = selected.wallet;
    final origin = Bip329Converter.getOriginFromDescriptor(wallet.descriptor);
    final transactions = realm.query<RealmTransaction>('walletId == ${wallet.id} SORT(createdAt DESC)').toList();
    final utxos =
        realm.query<RealmUtxo>('walletId == ${wallet.id} AND isDeleted == false SORT(timestamp DESC)').toList();

    if (transactions.isEmpty && utxos.isEmpty) {
      stderr.writeln('Selected wallet has no transactions or UTXOs.');
      exitCode = 1;
      return;
    }

    final records = <Bip329Record>[];

    for (var i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      records.add(
        Bip329Record(
          type: Bip329Type.tx,
          ref: tx.transactionHash,
          label: '전체 거래 메모 가져오기 테스트 ${i + 1}/${transactions.length}',
          origin: origin,
        ),
      );
    }

    for (var i = 0; i < utxos.length; i++) {
      final utxo = utxos[i];
      records.add(
        Bip329Record(
          type: Bip329Type.output,
          ref: '${utxo.transactionHash}:${utxo.index}',
          label: '전체 UTXO 태그 가져오기 테스트 ${i + 1}/${utxos.length}',
          tagColor: i % 10,
          spendable: false,
          origin: origin,
        ),
      );
    }

    final output = File(outputPath);
    output.parent.createSync(recursive: true);
    output.writeAsStringSync('${records.map((record) => record.toJsonLine()).join('\n')}\n');

    final summary = {
      'output': output.path,
      'lineCount': records.length,
      'walletId': wallet.id,
      'walletName': wallet.name,
      'origin': origin,
      'transactionCount': transactions.length,
      'utxoCount': utxos.length,
      'sizeBytes': output.lengthSync(),
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));
  } finally {
    realm.close();
  }
}
