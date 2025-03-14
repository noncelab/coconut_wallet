import 'dart:isolate';

class IsolateConnectorData {
  final SendPort sendPort;
  final String host;
  final int port;
  final bool ssl;

  IsolateConnectorData(this.sendPort, this.host, this.port, this.ssl);
}

enum IsolateMessageType {
  getBalanceBatch,
}
