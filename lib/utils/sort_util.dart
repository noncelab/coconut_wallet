import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo.dart' as model;

void sortUTXO(List<model.UTXO> utxos, UtxoOrderEnum order) {
  int getLastIndex(String path) => int.parse(path.split('/').last);

  int compareUTXOs(
      model.UTXO a, model.UTXO b, bool isAscending, bool byAmount) {
    int primaryCompare = byAmount
        ? (isAscending ? a.amount : b.amount)
            .compareTo(isAscending ? b.amount : a.amount)
        : (isAscending ? a.timestamp : b.timestamp)
            .compareTo(isAscending ? b.timestamp : a.timestamp);

    if (primaryCompare != 0) return primaryCompare;

    int secondaryCompare = byAmount
        ? b.timestamp.compareTo(a.timestamp)
        : b.amount.compareTo(a.amount);

    if (secondaryCompare != 0) return secondaryCompare;

    return getLastIndex(a.derivationPath)
        .compareTo(getLastIndex(b.derivationPath));
  }

  utxos.sort((a, b) {
    switch (order) {
      case UtxoOrderEnum.byAmountDesc:
        return compareUTXOs(a, b, false, true);
      case UtxoOrderEnum.byAmountAsc:
        return compareUTXOs(a, b, true, true);
      case UtxoOrderEnum.byTimestampDesc:
        return compareUTXOs(a, b, false, false);
      case UtxoOrderEnum.byTimestampAsc:
        return compareUTXOs(a, b, true, false);
    }
  });
}
