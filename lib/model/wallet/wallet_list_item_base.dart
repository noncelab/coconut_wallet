import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';

abstract class WalletListItemBase {
  static const String walletTypeField = 'walletType';

  final int id;
  String name;
  int colorIndex;
  int iconIndex;
  final String descriptor;
  WalletType walletType;
  int receiveUsedIndex;
  int changeUsedIndex;

  late WalletBase walletBase;

  Map<String, UnaddressedScriptStatus> subscribedScriptMap = {}; // { ScriptPubKey: ScriptStatus }

  WalletListItemBase(
      {required this.id,
      required this.name,
      required this.colorIndex,
      required this.iconIndex,
      required this.descriptor,
      required this.walletType,
      this.receiveUsedIndex = -1,
      this.changeUsedIndex = -1});

  @override
  String toString() => 'Wallet($id) / type=$walletType / name=$name';
}
