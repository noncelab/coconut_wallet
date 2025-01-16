import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';

abstract class WalletListItemBase {
  static const String walletTypeField = 'walletType';

  final int id;
  String name;
  int colorIndex;
  int iconIndex;
  final String descriptor;
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
