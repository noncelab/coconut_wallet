import 'package:coconut_wallet/model/data/wallet_type.dart';

class DerivationPathUtil {
  static String getPurpose(String derivationPath) {
    List<String> pathComponents = derivationPath.split('/');
    if (pathComponents.length < 2) throw "Wrong derivationPath";
    if (pathComponents[0] != 'm') throw "Wrong derivationPath";

    return pathComponents[1];
  }

  static int getChangeElement(WalletType walletType, String derivationPath) {
    List<String> pathComponents = derivationPath.split('/');
    if (walletType == WalletType.singleSignature) {
      return int.parse(pathComponents[4]);
    } else if (walletType == WalletType.multiSignature) {
      return int.parse(pathComponents[5]);
    } else {
      throw ArgumentError("wrong walletType: $walletType");
    }
  }

  static int getAccountIndex(WalletType walletType, String derivationPath) {
    List<String> pathComponents = derivationPath.split('/');
    if (walletType == WalletType.singleSignature) {
      return int.parse(pathComponents[5]);
    } else if (walletType == WalletType.multiSignature) {
      return int.parse(pathComponents[6]);
    } else {
      throw ArgumentError("wrong walletType: $walletType");
    }
  }
}
