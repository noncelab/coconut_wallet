import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _rawTransaction =
    '02000000000101aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0000000000fdffffff01583e0f000000'
    '0000160014b3910b705bdb9cc0765320fc4096e865e84ad2c802483045022100b1ba2b673485903d6e2057df4a8153581f645e9bf2f5'
    '92123e82d6dab677c7ce0220474641ea708075d6c1457df7a3b084c20179aaee17866d222c35768c1447167f012102e7ab2537b5d49e'
    '970309aae06e9e49f36ce1c9febbd44ec8e0d1cca0b4f9c31900000000';

class _Electrum extends Fake implements ElectrumService {
  Object? error;
  int explorerFallbackLookups = 0;

  @override
  Future<String> getTransactionFromServer(
    String txHash, {
    bool? verbose,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    throw const ElectrumServerError({'code': 2, 'message': 'missing transaction'});
  }

  @override
  Future<String> getTransaction(String txHash, {bool? verbose, Duration timeout = const Duration(seconds: 5)}) async {
    explorerFallbackLookups++;
    return 'raw from explorer';
  }

  @override
  Future<String> broadcast(String rawTransaction) async {
    if (error != null) throw error!;
    return 'txid';
  }
}

void main() {
  late _Electrum electrum;
  late NetworkService service;
  final transaction = Transaction.parse(_rawTransaction);

  setUp(() {
    electrum = _Electrum();
    service = NetworkService(electrum);
  });

  test('a server error response is reported as a rejection with its message', () async {
    electrum.error = const ElectrumServerError({'code': -26, 'message': 'min relay fee not met'});
    final result = await service.broadcast(transaction);
    expect(result.error.code, ErrorCodes.broadcastError.code);
    expect(result.error.message, contains('min relay fee not met'));
  });

  for (final error in <Object>[
    TimeoutException('no reply'),
    'Can not connect to the server. Please connect and try again.',
    StateError('socket closed'),
  ]) {
    test('a missing reply is not reported as a rejection (${error.runtimeType})', () async {
      electrum.error = error;
      final result = await service.broadcast(transaction);
      expect(result.error.code, ErrorCodes.nodeConnectionError.code);
    });
  }

  test('a node-only lookup never falls back to the public explorer', () async {
    final result = await service.getTransactionFromNode('txid');
    expect(result.isFailure, isTrue);
    expect(electrum.explorerFallbackLookups, 0, reason: 'the txid must not leave the chosen node');
  });
}
