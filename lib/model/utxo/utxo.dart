import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';

class UtxoState extends UTXO {
  final String timestamp;
  final String blockHeight;
  final String to; // 소유 주소
  List<UtxoTag>? tags;

  UtxoState({
    required String transactionHash,
    required int index,
    required int amount,
    required String derivationPath,
    required this.timestamp,
    required this.blockHeight,
    required this.to,
    this.tags,
  }) : super(transactionHash, index, amount, derivationPath);

  static void sortUtxo(List<UtxoState> utxos, UtxoOrderEnum order) {
    int getLastIndex(String path) => int.parse(path.split('/').last);

    int compareUtxos(
        UtxoState a, UtxoState b, bool isAscending, bool byAmount) {
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
          return compareUtxos(a, b, false, true);
        case UtxoOrderEnum.byAmountAsc:
          return compareUtxos(a, b, true, true);
        case UtxoOrderEnum.byTimestampDesc:
          return compareUtxos(a, b, false, false);
        case UtxoOrderEnum.byTimestampAsc:
          return compareUtxos(a, b, true, false);
      }
    });
  }

  String get utxoId => '$transactionHash$index';
}
