import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';

abstract class WalletListItemBase {
  static const String walletTypeField = 'walletType';

  final int id;
  String name;
  int colorIndex;
  int iconIndex;
  final String descriptor;
  WalletType walletType;
  int? balance;
  int receiveUsedIndex;
  int changeUsedIndex;

  /// wallet.fetchOnChainData(nodeConnector) 또는 _nodeConnector.fetch 결과에서 txCount가 변경되지 않았는지 확인용
  int? txCount;
  bool isLatestTxBlockHeightZero =
      false; // _nodeConnector.fetch 결과에서 latestTxBlockHeight가 변경되지 않았는지 확인용

  late WalletBase walletBase;
  List<UtxoState> utxoList = []; // TODO: DB 추가 후 DB에서 조회하도록 수정

  WalletListItemBase(
      {required this.id,
      required this.name,
      required this.colorIndex,
      required this.iconIndex,
      required this.descriptor,
      required this.walletType,
      this.balance,
      this.txCount,
      this.isLatestTxBlockHeightZero = false,
      this.receiveUsedIndex = -1,
      this.changeUsedIndex = -1});

  // TODO: walletFeature
  // dynamic get walletFeature {
  //   switch (walletType) {
  //     case WalletType.singleSignature:
  //       return walletBase as SingleSignatureWallet;
  //     case WalletType.multiSignature:
  //       return walletBase as MultisignatureWallet;
  //     default:
  //       throw StateError('wrong walletType: ${walletType.name}');
  //   }
  // }

  @override
  String toString() =>
      'Wallet($id) / type=$walletType / name=$name / balance=$balance';
}
