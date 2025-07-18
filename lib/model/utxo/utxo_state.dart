import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';

enum UtxoStatus {
  unspent, // 사용되지 않은 상태, confirmed
  outgoing, // 출금 중인 상태, unconfirmed
  incoming, // 입금 중인 상태, unconfirmed
  locked, // 사용 불가 상태, confirmed
}

class UtxoState extends Utxo {
  final int blockHeight;
  final String to; // 소유 주소
  DateTime timestamp;
  List<UtxoTag>? tags;
  UtxoStatus status = UtxoStatus.unspent;
  String? spentByTransactionHash; // 이 UTXO를 사용한 트랜잭션 해시

  bool get isRbfable => status == UtxoStatus.outgoing && blockHeight == 0;

  bool get isCpfpable => status == UtxoStatus.incoming && blockHeight == 0;

  bool get isPending => status == UtxoStatus.outgoing || status == UtxoStatus.incoming;

  bool get isLocked => status == UtxoStatus.locked && blockHeight != 0;

  UtxoState({
    required String transactionHash,
    required int index,
    required int amount,
    required String derivationPath,
    required this.blockHeight,
    required this.to,
    required this.timestamp,
    this.tags,
    this.status = UtxoStatus.unspent,
    this.spentByTransactionHash,
  }) : super(transactionHash, index, amount, derivationPath);

  static void sortUtxo(List<UtxoState> utxos, UtxoOrder order) {
    int getLastIndex(String path) => int.parse(path.split('/').last);

    int compareUtxos(UtxoState a, UtxoState b, bool isAscending, bool byAmount) {
      // incoming/outgoing 우선 정렬
      if (a.isPending && !b.isPending) return -1;
      if (!a.isPending && b.isPending) return 1;

      int primaryCompare = byAmount
          ? (isAscending ? a.amount : b.amount).compareTo(isAscending ? b.amount : a.amount)
          : (isAscending ? a.timestamp : b.timestamp)
              .compareTo(isAscending ? b.timestamp : a.timestamp);

      if (primaryCompare != 0) return primaryCompare;

      int secondaryCompare =
          byAmount ? b.timestamp.compareTo(a.timestamp) : b.amount.compareTo(a.amount);

      if (secondaryCompare != 0) return secondaryCompare;

      return getLastIndex(a.derivationPath).compareTo(getLastIndex(b.derivationPath));
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
