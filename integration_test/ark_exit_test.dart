// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/services/ark/ark_wallet_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// 안 A(bark 내장 온체인 지갑으로 단독 출금 수수료를 냄)를 로컬 regtest에서 끝까지 확인
///
/// ```bash
/// fvm flutter test integration_test/ark_exit_test.dart -d <다른 시뮬레이터> --flavor regtest \
///   --dart-define-from-file=regtest.local.json
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('안 A: 보딩 → 단독 출금 → 대기 → 회수', () async {
    CoconutWalletApp.kArkServerUrl = const String.fromEnvironment('ARK_SERVER_URL');
    CoconutWalletApp.kArkEsploraUrl = const String.fromEnvironment('ARK_ESPLORA_URL');
    NetworkType.setNetworkType(NetworkType.regtest);
    final service = ArkWalletService();
    final random = Random.secure();
    final seedHex = List.generate(64, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final fingerprint = 'exit${random.nextInt(1 << 30).toRadixString(16)}';
    final stopwatch = Stopwatch()..start();
    void log(String message) => print('[exit-a ${stopwatch.elapsed.inSeconds}s] $message');

    await service.create(fingerprint, seedHex, restore: false);
    log('ark wallet created');

    final feeAddress = await service.exitFeeAddress(fingerprint);
    await _rpc('sendtoaddress', [feeAddress, 0.003], wallet: 'wallet');
    await _waitFor(log, 'fee wallet funded', () async => (await service.exitFeeBalance(fingerprint)).confirmedSats > 0);
    final funded = (await service.exitFeeBalance(fingerprint)).confirmedSats;
    log('fee wallet balance $funded');

    await service.withWallet(fingerprint, (wallet) => wallet.boardAmount(amountSats: 100000));
    log('boarding 100000');
    String? vtxoId;
    await _waitFor(log, 'board spendable', () async {
      await service.syncAndProgressRounds(fingerprint);
      final vtxos = await service.withWallet(fingerprint, (wallet) => wallet.vtxos());
      vtxoId = vtxos.where((vtxo) => vtxo.state is bark.SpendableVtxoState).firstOrNull?.id;
      return vtxoId != null;
    });
    final afterBoard = (await service.exitFeeBalance(fingerprint)).confirmedSats;
    log('vtxo $vtxoId, fee wallet after board $afterBoard');

    final estimate = await service.estimateExitFee(fingerprint, [vtxoId!], 1);
    log('estimate total ${estimate.totalFeeSats} (broadcast ${estimate.exitBroadcastFeeSats}, claim ${estimate.claimFeeSats}, txs ${estimate.txsToBroadcast}, fundable ${estimate.fundable})');

    await service.startExit(fingerprint, [vtxoId!]);
    log('exit started');
    await _waitFor(log, 'exit awaiting delta', () async {
      final statuses = await service.progressExits(fingerprint);
      for (final status in statuses) {
        log('  ${status.state.runtimeType}${status.error == null ? '' : ' error ${status.error}'}');
      }
      return statuses.every((status) => status.state is bark.AwaitingDeltaExitState || status.state is bark.ClaimableExitState);
    });
    final claimableAt = await service.exitsClaimableAtHeight(fingerprint);
    final tip = await _rpc('getblockcount', []) as int;
    log('claimable at $claimableAt (tip $tip), mining ${claimableAt! - tip + 2}');
    final miner = await _rpc('getnewaddress', [], wallet: 'wallet');
    await _rpc('generatetoaddress', [claimableAt - tip + 2, miner]);

    await _waitFor(log, 'exit claimable', () async {
      await service.progressExits(fingerprint);
      final exits = await service.exitVtxos(fingerprint);
      return exits.isNotEmpty && exits.every((exit) => exit.isClaimable);
    });
    final destination = await _rpc('getnewaddress', [], wallet: 'wallet') as String;
    final txid = await service.claimExits(fingerprint, destination);
    log('claim broadcast $txid');
    await _waitFor(log, 'claim received', () async => ((await _rpc('getreceivedbyaddress', [destination, 0], wallet: 'wallet')) as num) > 0);
    final received = await _rpc('getreceivedbyaddress', [destination, 0], wallet: 'wallet');
    final feeLeft = (await service.exitFeeBalance(fingerprint)).totalSats;
    log('RESULT received $received BTC for 100000 vtxo, fee wallet $afterBoard -> $feeLeft (spent ${afterBoard - feeLeft}), total ${stopwatch.elapsed.inSeconds}s');
    await service.delete(fingerprint);
  }, timeout: const Timeout(Duration(minutes: 30)));

  test('실패 재현: 출금 시작 뒤 진행 못 한 채 만료 → 서버 회수', () async {
    CoconutWalletApp.kArkServerUrl = const String.fromEnvironment('ARK_SERVER_URL');
    CoconutWalletApp.kArkEsploraUrl = const String.fromEnvironment('ARK_ESPLORA_URL');
    NetworkType.setNetworkType(NetworkType.regtest);
    final service = ArkWalletService();
    final random = Random.secure();
    final seedHex = List.generate(64, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final fingerprint = 'fail${random.nextInt(1 << 30).toRadixString(16)}';
    final stopwatch = Stopwatch()..start();
    void log(String message) => print('[exit-fail ${stopwatch.elapsed.inSeconds}s] $message');
    Future<void> dump(String when) async {
      await service.withWallet(fingerprint, (wallet) async {
        final b = await wallet.balance();
        log('$when balance spendable ${b.spendableSats} pendingExit ${b.pendingExitSats}');
        for (final m in await wallet.history()) {
          log('$when movement ${m.id} ${m.subsystemName}/${m.subsystemKind} ${m.status} intended ${m.intendedBalanceSats} effective ${m.effectiveBalanceSats} fee ${m.offchainFeeSats} exited ${m.exitedVtxoIds.length}');
        }
        for (final e in await wallet.getExitVtxos()) {
          log('$when exit ${e.vtxoId.substring(0, 8)} ${e.amountSats} ${e.state.runtimeType} claimable ${e.isClaimable}');
        }
        for (final v in await wallet.allVtxos()) {
          log('$when vtxo ${v.id.substring(0, 8)} ${v.amountSats} exp ${v.expiryHeight} ${v.state.runtimeType}');
        }
      });
    }

    await service.create(fingerprint, seedHex, restore: false);
    await _rpc('sendtoaddress', [await service.exitFeeAddress(fingerprint), 0.003], wallet: 'wallet');
    await _waitFor(log, 'fee wallet funded', () async => (await service.exitFeeBalance(fingerprint)).confirmedSats > 0);
    await service.withWallet(fingerprint, (wallet) => wallet.boardAmount(amountSats: 100000));
    String? vtxoId;
    int? expiry;
    await _waitFor(log, 'board spendable', () async {
      await service.syncAndProgressRounds(fingerprint);
      final vtxos = await service.withWallet(fingerprint, (wallet) => wallet.vtxos());
      final vtxo = vtxos.where((v) => v.state is bark.SpendableVtxoState).firstOrNull;
      vtxoId = vtxo?.id;
      expiry = vtxo?.expiryHeight;
      return vtxo != null;
    });
    log('vtxo $vtxoId expiry $expiry');
    await service.startExit(fingerprint, [vtxoId!]);
    await dump('started');
    final miner = await _rpc('getnewaddress', [], wallet: 'wallet');
    final tip = await _rpc('getblockcount', []) as int;
    log('mining ${expiry! - tip + 3} blocks past expiry without progressing the exit');
    var left = expiry! - tip + 3;
    while (left > 0) {
      final n = left > 500 ? 500 : left;
      await _rpc('generatetoaddress', [n, miner]);
      left -= n;
    }
    await _waitFor(log, 'esplora caught up', () async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('${CoconutWalletApp.kArkEsploraUrl}/blocks/tip/height'));
        final height = int.parse(await (await request.close()).transform(utf8.decoder).join());
        return height >= (await _rpc('getblockcount', []) as int) - 1;
      } finally {
        client.close();
      }
    });
    log('waiting 120s for the server to sweep');
    await Future<void>.delayed(const Duration(seconds: 120));
    for (var i = 0; i < 8; i++) {
      try {
        final statuses = await service.progressExits(fingerprint);
        for (final s in statuses) {
          log('progress ${s.state.runtimeType}${s.error == null ? '' : ' error ${s.error}'}');
        }
      } catch (error) {
        log('progress threw $error');
      }
      await Future<void>.delayed(const Duration(seconds: 10));
    }
    await service.syncAndProgressRounds(fingerprint);
    await dump('after');
    final feeLeft = (await service.exitFeeBalance(fingerprint)).totalSats;
    log('RESULT fee wallet left $feeLeft');
    await service.delete(fingerprint);
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('안 A: 내장 지갑 없이 만든 기존 아크 지갑에 나중에 붙여 열기', () async {
    CoconutWalletApp.kArkServerUrl = const String.fromEnvironment('ARK_SERVER_URL');
    CoconutWalletApp.kArkEsploraUrl = const String.fromEnvironment('ARK_ESPLORA_URL');
    NetworkType.setNetworkType(NetworkType.regtest);
    final random = Random.secure();
    final seedHex = List.generate(64, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final fingerprint = 'old${random.nextInt(1 << 30).toRadixString(16)}';
    final datadir = Directory('${(await getApplicationSupportDirectory()).path}/bark/$fingerprint');
    await datadir.create(recursive: true);
    final config = bark.Config(
      serverAddress: CoconutWalletApp.kArkServerUrl,
      esploraAddress: CoconutWalletApp.kArkEsploraUrl,
      daemonManualSync: true,
    );
    final legacy = await bark.Wallet.open(
      network: bark.Network.regtest,
      mnemonicOrSeed: seedHex,
      config: config,
      args: bark.WalletOpenArgs(datadir: datadir.path, createIfNotExists: true, createWithoutServer: true, skipRecovery: true),
    );
    final legacyAddress = await legacy.newAddress();
    await legacy.stopDaemonWait();
    legacy.dispose();
    print('[exit-a-old] legacy wallet created without fee wallet, ark address $legacyAddress');

    final service = ArkWalletService();
    await service.open(fingerprint, seedHex);
    final feeAddress = await service.exitFeeAddress(fingerprint);
    final balance = await service.exitFeeBalance(fingerprint);
    final snapshot = await service.snapshot(fingerprint);
    print('[exit-a-old] RESULT reopened with fee wallet $feeAddress balance ${balance.totalSats}, ark address ${snapshot.address}');
    expect(feeAddress, startsWith('bcrt1'));
    await service.delete(fingerprint);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _waitFor(void Function(String) log, String what, Future<bool> Function() check) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    try {
      if (await check()) {
        log('ok: $what');
        return;
      }
    } catch (error) {
      log('retry $what: $error');
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
  throw StateError('timed out: $what');
}

Future<Object?> _rpc(String method, List<Object?> params, {String? wallet}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('http://127.0.0.1:18443${wallet == null ? '' : '/wallet/$wallet'}');
    final request = await client.postUrl(uri);
    request.headers.set('Authorization', 'Basic ${base64.encode(utf8.encode('second:ark'))}');
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'jsonrpc': '1.0', 'id': 'exit', 'method': method, 'params': params}));
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
    if (body['error'] != null) throw StateError('rpc $method: ${body['error']}');
    return body['result'];
  } finally {
    client.close();
  }
}
