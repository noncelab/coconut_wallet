import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

/// 스크립트 및 주소 관련 유틸리티 클래스
class ElectrumUtil {
  /// 지갑으로부터 주소 목록을 가져옵니다.
  static Map<int, String> prepareAddressesMap(
    WalletBase wallet,
    int startIndex,
    int endIndex,
    bool isChange,
  ) {
    Map<int, String> scripts = {};

    try {
      for (int derivationIndex = startIndex; derivationIndex < endIndex; derivationIndex++) {
        String address = wallet.getAddress(derivationIndex, isChange: isChange);
        scripts[derivationIndex] = address;
      }
      return scripts;
    } catch (e) {
      Logger.error('Error preparing addresses map: $e');
      return {};
    }
  }

  /// 주소 유형에 따른 스크립트를 생성합니다.
  static String getScriptForAddress(AddressType addressType, String address) {
    if (addressType == AddressType.p2wpkh) {
      return ScriptPublicKey.p2wpkh(address).serialize().substring(2);
    } else if (addressType == AddressType.p2wsh) {
      return ScriptPublicKey.p2wsh(address).serialize().substring(2);
    }
    throw 'Unsupported address type: $addressType';
  }

  static String addressToReversedScriptHash(AddressType addressType, String address) {
    String script = getScriptForAddress(addressType, address);
    final bytes = hex.decode(script);
    final digest = sha256.convert(bytes);
    return hex.encode(digest.bytes.reversed.toList());
  }
}
