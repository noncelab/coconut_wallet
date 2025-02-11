import 'network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

extension UtxoOrderEnumExtension on UtxoOrderEnum {
  String get text {
    switch (this) {
      case UtxoOrderEnum.byAmountDesc:
        return t.utxo_order_enums.amt_desc;
      case UtxoOrderEnum.byAmountAsc:
        return t.utxo_order_enums.amt_asc;
      case UtxoOrderEnum.byTimestampDesc:
        return t.utxo_order_enums.time_desc;
      case UtxoOrderEnum.byTimestampAsc:
        return t.utxo_order_enums.time_asc;
    }
  }
}
