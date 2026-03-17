import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';

class UtxoBucket {
  final String label;
  final int minSats;
  final int maxSats; // inclusive
  final List<UtxoState> utxos;
  const UtxoBucket({required this.label, required this.minSats, required this.maxSats, required this.utxos});
}

/// UTXO 금액 구간 정의 (그래프, 모달 등 공통 사용)
const utxoBucketRanges = [
  (label: 'whale', min: 1_000_000_000, max: 2_100_000_000_000_000),
  (label: 'whole', min: 100_000_000, max: 999_999_999),
  (label: 'huge', min: 10_000_000, max: 99_999_999),
  (label: 'large', min: 1_000_001, max: 9_999_999),
  (label: 'meduim', min: 100_001, max: 1_000_000),
  (label: 'small', min: 10_001, max: 100_000),
  (label: 'tiny', min: dustLimit + 1, max: 10_000),
  (label: 'dust', min: 0, max: dustLimit),
];

List<UtxoBucket> bucketize(List<UtxoState> utxos) {
  return utxoBucketRanges
      .map((r) {
        final list =
            utxos.where((u) => u.amount >= r.min && u.amount <= r.max).toList()..sort((a, b) {
              if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
              final cmp = b.amount.compareTo(a.amount);
              if (cmp != 0) return cmp;
              return b.timestamp.compareTo(a.timestamp);
            });
        return UtxoBucket(label: r.label, minSats: r.min, maxSats: r.max, utxos: list);
      })
      .where((b) => b.utxos.isNotEmpty)
      .toList();
}
