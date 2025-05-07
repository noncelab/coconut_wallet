import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';

class IsolateConnectorData {
  final SendPort isolateToMainSendPort; // 메인스레드로 보내는 포트
  final String host;
  final int port;
  final bool ssl;
  final NetworkType networkType;

  IsolateConnectorData(
      this.isolateToMainSendPort, this.host, this.port, this.ssl, this.networkType);
}
