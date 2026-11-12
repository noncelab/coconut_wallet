import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';

/// An amount typed on the send screen's keypad: a canonical string ('.' decimal) in the current
/// unit, edited one key at a time with the send screen's rules (SendViewModel.onKeyTap).
abstract final class SendAmountText {
  /// [amount] after [key]: a digit, '.' or ',' (decimal), or '<' (backspace).
  static String apply(String amount, String key, {required bool isSats}) {
    if (key == ',') key = '.';
    if (isSats && key == '.') return amount;
    if (key == '<') return amount.isEmpty ? amount : amount.substring(0, amount.length - 1);
    if (key == '.') {
      if (amount.isEmpty) return '0.';
      return amount.contains('.') ? amount : '$amount.';
    }
    if (!RegExp(r'^[0-9]$').hasMatch(key)) return amount;
    if (amount.isEmpty) return key;
    // A leading zero is replaced by the next digit.
    if (amount == '0') return key;
    if (amount.contains('.')) {
      // At most 8 decimals.
      return amount.length - amount.indexOf('.') <= 8 ? '$amount$key' : amount;
    }
    // At most 8 integer digits in BTC, 16 in sats.
    return amount.length < (isSats ? 16 : 8) ? '$amount$key' : amount;
  }

  /// Several keys at once (a paste), applied in order.
  static String applyAll(String amount, String keys, {required bool isSats}) {
    var result = amount;
    for (final key in keys.split('')) {
      result = apply(result, key, isSats: isSats);
    }
    return result;
  }

  static int? toSats(String amount, BitcoinUnit unit) {
    final value = double.tryParse(amount);
    if (value == null || value <= 0) return null;
    return unit.toSatoshi(value);
  }

  /// The canonical text of [sats] in [unit], without trailing zeros.
  static String fromSats(int sats, BitcoinUnit unit) {
    if (unit.isBasedOnSatoshi) return '$sats';
    final btc = UnitUtil.convertSatoshiToBitcoinString(sats);
    if (!btc.contains('.')) return btc;
    return btc.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}
