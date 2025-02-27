import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

UnaddressedScriptStatus mapRealmToUnaddressedScriptStatus(
    RealmScriptStatus realmScriptStatus) {
  return UnaddressedScriptStatus(
    scriptPubKey: realmScriptStatus.scriptPubKey,
    status: realmScriptStatus.status,
    timestamp: realmScriptStatus.timestamp,
  );
}
