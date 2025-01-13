import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';

abstract class WalletListItemBase {
  static const String walletTypeField = 'walletType';

  final int id;
  int colorIndex;
  int iconIndex;
  final String descriptor;
  String name;
  WalletType walletType;
  int? balance;

  /// wallet.fetchOnChainData(nodeConnector) 또는 _nodeConnector.fetch 결과에서 txCount가 변경되지 않았는지 확인용
  int? txCount;
  bool isLatestTxBlockHeightZero =
      false; // _nodeConnector.fetch 결과에서 latestTxBlockHeight가 변경되지 않았는지 확인용

  late WalletBase walletBase;

  WalletListItemBase(
      {required this.id,
      required this.name,
      required this.colorIndex,
      required this.iconIndex,
      required this.descriptor,
      required this.walletType,
      this.balance,
      this.txCount,
      this.isLatestTxBlockHeightZero = false});

  @override
  String toString() =>
      'Wallet($id) / type=$walletType / name=$name / balance=$balance';
}
