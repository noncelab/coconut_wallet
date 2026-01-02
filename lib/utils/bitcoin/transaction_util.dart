import 'package:coconut_wallet/utils/hex_util.dart';

const String rawTxVersion1Field = '01000000';
const String rawTxVersion2Field = '02000000';
const String rawTxSegwitField = '0001';

bool isRawTransactionHexString(String data) {
  try {
    if (!isHexString(data)) return false;
    if (!data.startsWith(rawTxVersion1Field) && !data.startsWith(rawTxVersion2Field)) return false;
    return true;
  } catch (_) {
    return false;
  }
}
