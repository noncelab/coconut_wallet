import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';

class IsolateStateMessage {
  IsolateStateMethod methodName;
  List<dynamic> params;

  IsolateStateMessage(this.methodName, this.params);

  @override
  String toString() {
    return 'IsolateStateMessage{methodName: $methodName, params: $params}';
  }
}
