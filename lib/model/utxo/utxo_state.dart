import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';

class UtxoState extends Utxo {
  final int blockHeight;
  final String to; // 소유 주소
  late DateTime timestamp;
  List<UtxoTag>? tags;

  UtxoState({
    required String transactionHash,
    required int index,
    required int amount,
    required String derivationPath,
    required this.blockHeight,
    required this.to,
    this.tags,
  }) : super(transactionHash, index, amount, derivationPath);

  void updateTimestamp(DateTime timestamp) {
    this.timestamp = timestamp;
  }

  static void updateTimestampFromBlocks(
      List<UtxoState> utxos, Map<int, BlockTimestamp> blockTimestamps) {
    for (var utxo in utxos) {
      // 언컨펌 Utxo의 경우 현재 시간으로 설정
      utxo.updateTimestamp(
          blockTimestamps[utxo.blockHeight]?.timestamp ?? DateTime.now());
    }
  }

  static void sortUtxo(List<UtxoState> utxos, UtxoOrder order) {
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
        case UtxoOrder.byAmountDesc:
          return compareUtxos(a, b, false, true);
        case UtxoOrder.byAmountAsc:
          return compareUtxos(a, b, true, true);
        case UtxoOrder.byTimestampDesc:
          return compareUtxos(a, b, false, false);
        case UtxoOrder.byTimestampAsc:
          return compareUtxos(a, b, true, false);
      }
    });
  }

  String get utxoId => '$transactionHash$index';
}
