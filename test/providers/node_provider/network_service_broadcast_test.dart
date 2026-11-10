import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Transaction extends Fake implements Transaction {
  @override
  String serialize() => 'raw';
}

class _ElectrumService extends Fake implements ElectrumService {
  Object? error;

  @override
  Future<String> broadcast(String rawTransaction) async {
    if (error != null) throw error!;
    return 'txid';
  }
}

void main() {
  late _ElectrumService electrum;
  late NetworkService service;

  setUp(() {
    electrum = _ElectrumService();
    service = NetworkService(electrum);
  });

  test('a node response is returned as the txid', () async {
    expect((await service.broadcast(_Transaction())).value, 'txid');
  });

  test('a node rejection is a broadcast error', () async {
    electrum.error = {'code': 2, 'message': 'bad-txns-inputs-missingorspent'};

    final result = await service.broadcast(_Transaction());

    expect(result.error.code, ErrorCodes.broadcastError.code);
    expect(result.error.message, contains('missingorspent'));
  });

  test('a response timeout is an unknown outcome, not a rejection', () async {
    electrum.error = TimeoutException('no response', const Duration(seconds: 60));

    final result = await service.broadcast(_Transaction());

    expect(result.error.code, ErrorCodes.nodeUnknown.code);
  });
}
