import 'package:coconut_wallet/services/network/node_client.dart';

abstract class IsolateManagerBase extends NodeClient {
  bool get isInitialized;
  Future<void> initialize(
      NodeClientFactory factory, String host, int port, bool ssl);
}
