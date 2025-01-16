import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable(ignoreUnannotated: true)
abstract class WalletListItemBase {
  static const String walletTypeField = 'walletType';

  @JsonKey(name: "id")
  final int id;
  @JsonKey(name: "colorIndex")
  int colorIndex;
  @JsonKey(name: "iconIndex")
  int iconIndex;
  @JsonKey(name: "descriptor")
  final String descriptor;
  @JsonKey(name: "name")
  String name;
  @JsonKey(name: walletTypeField)
  WalletType walletType;
  @JsonKey(name: "balance")
  int? balance;

  /// wallet.fetchOnChainData(nodeConnector) 또는 _nodeConnector.fetch 결과에서 txCount가 변경되지 않았는지 확인용
  @JsonKey(name: "txCount")
  int? txCount;
  @JsonKey(name: "isLatestTxBlockHeightZero")
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

  WalletFeature get walletFeature {
    switch (walletType) {
      case WalletType.singleSignature:
        return walletBase as SingleSignatureWallet;
      case WalletType.multiSignature:
        return walletBase as MultisignatureWallet;
      default:
        throw StateError('wrong walletType: ${walletType.name}');
    }
  }

  Future _fetchWalletStatusFromNetwork(NodeConnector nodeConnector) async {
    try {
      await walletFeature.fetchOnChainData(nodeConnector);
    } catch (e) {
      throw AppError(ErrorCodes.walletSyncFailedError.code, e.toString());
    }
  }

  bool _shouldUpdateToLatest() {
    if (walletFeature.walletStatus == null) {
      return false;
    }

    return txCount == null ||
        txCount != walletFeature.walletStatus!.transactionList.length ||
        isLatestTxBlockHeightZero ||
        balance == null;
  }

  Future<bool> checkIfWalletShouldUpdate(NodeConnector nodeConnector) async {
    await _fetchWalletStatusFromNetwork(nodeConnector);
    return _shouldUpdateToLatest();
  }

  @override
  String toString() =>
      'Wallet($id) / type=$walletType / name=$name / balance=$balance';
}
