import 'dart:isolate';

class IsolateConnectorData {
  final SendPort isolateToMainSendPort; // 메인스레드로 보내는 포트
  final String host;
  final int port;
  final bool ssl;

  IsolateConnectorData(
      this.isolateToMainSendPort, this.host, this.port, this.ssl);
}
