import 'package:coconut_wallet/model/script/script_status.dart';

class SubscribeWalletResponse {
  final List<ScriptStatus> scriptStatuses;
  final int usedReceiveIndex;
  final int usedChangeIndex;

  SubscribeWalletResponse({
    required this.scriptStatuses,
    required this.usedReceiveIndex,
    required this.usedChangeIndex,
  });
}
