import 'package:coconut_wallet/services/electrum_service.dart';

abstract class IsolateManagerBase {
  bool get isInitialized;
  Future<void> initialize(
      ElectrumService electrumService, String host, int port, bool ssl);
}
