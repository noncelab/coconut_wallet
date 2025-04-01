import 'package:coconut_wallet/localization/strings.g.dart';

enum UtxoOrder { byAmountDesc, byAmountAsc, byTimestampDesc, byTimestampAsc }

extension UtxoOrderEnumExtension on UtxoOrder {
  String get text {
    switch (this) {
      case UtxoOrder.byAmountDesc:
        return t.utxo_order_enums.amt_desc;
      case UtxoOrder.byAmountAsc:
        return t.utxo_order_enums.amt_asc;
      case UtxoOrder.byTimestampDesc:
        return t.utxo_order_enums.time_desc;
      case UtxoOrder.byTimestampAsc:
        return t.utxo_order_enums.time_asc;
    }
  }
}
