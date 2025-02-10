import 'dart:isolate';

import 'package:coconut_wallet/services/network/node_client.dart';

class IsolateConnectorData {
  final SendPort sendPort;
  final NodeClientFactory factory;
  final String host;
  final int port;
  final bool ssl;

  IsolateConnectorData(
      this.sendPort, this.factory, this.host, this.port, this.ssl) {
    if (host.isEmpty) {
      throw Exception('Host cannot be empty');
    }
    if (port <= 0 || port > 65535) {
      throw Exception('Port must be between 1 and 65535');
    }
  }
}

enum IsolateMessageType {
  broadcast,
  getNetworkMinimumFeeRate,
  getLatestBlock,
  getTransaction,
}
