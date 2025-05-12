import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';

class ScriptStatusMock {
  static ScriptStatus createMockScriptStatus(WalletListItemBase walletItem, int index,
      {bool isChange = false}) {
    final address = walletItem.walletBase.getAddress(index, isChange: isChange);
    return ScriptStatus(
        scriptPubKey: address,
        status: Hash.sha256(address),
        timestamp: DateTime.now(),
        derivationPath: '${walletItem.walletBase.derivationPath}/${isChange ? '1' : '0'}/$index',
        address: address,
        index: index,
        isChange: isChange);
  }
}
