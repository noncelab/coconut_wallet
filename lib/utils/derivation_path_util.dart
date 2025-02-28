import 'package:coconut_wallet/enums/wallet_enums.dart';

// TODO: Remove this class if it is not used
// 현재 아무데도 쓰이는 곳 없음. utxo detail 화면에서 보유 주소(_buildAddress)렌더링 할 때 사용할 수 있긴 한데 굳이?
class DerivationPathUtil {
  static String getPurpose(String derivationPath) {
    List<String> pathComponents = _getPathList(derivationPath);
    return pathComponents[1];
  }

  static bool isChangeAddress(String derivationPath) {
    List<String> path = _getPathList(derivationPath);
    return path[path.length - 2] == '1';
  }

  static int getChangeIndex(String derivationPath) {
    List<String> path = _getPathList(derivationPath);
    return path.length - 2;
  }

  static int getAccountIndex(WalletType walletType, String derivationPath) {
    List<String> path = _getPathList(derivationPath);
    return int.parse(path[path.length - 1]);
  }

  static List<String> _getPathList(String derivationPath) {
    List<String> path = derivationPath.split('/');

    if (path.length == 6 || path.length == 7) {
      return path;
    }
    if (path.length < 2) throw "Wrong derivationPath";
    if (path[0] != 'm') throw "Wrong derivationPath";
    throw ArgumentError("wrong derivedPath: $derivationPath");
  }
}
