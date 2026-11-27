/// '지갑별 잔액' 상세 화면의 계산. 화면·Provider에 기대지 않는 순수 함수만 둔다.
library;

/// 지갑 목록 정렬 기준
enum WalletBalanceSort {
  /// 잔액이 큰 순(기본)
  balance,

  /// 기간 변화량이 큰 순. 부호 있는 값 내림차순이며 절댓값이 아니다.
  change,
}

/// 지갑 이름 옆 라벨
enum WalletKindTag { hot, watchOnly, vault, multisig }

/// 화면이 지갑 하나에 대해 모아 온 원자료
class WalletBalanceInput {
  final int walletId;
  final String name;

  /// 기간의 매일 마지막 잔액. 오래된 날부터이며 마지막이 현재 잔액이다.
  final List<int> balances;

  /// 지갑의 첫 거래 시각. 거래가 없으면 null.
  final DateTime? firstTransactionAt;
  final List<WalletKindTag> tags;
  final int? colorIndex;

  const WalletBalanceInput({
    required this.walletId,
    required this.name,
    required this.balances,
    this.firstTransactionAt,
    this.tags = const [],
    this.colorIndex,
  });

  int get current => balances.isEmpty ? 0 : balances.last;
  int get start => balances.isEmpty ? 0 : balances.first;
}

/// 목록의 한 줄
class WalletBalanceRow {
  final WalletBalanceInput input;

  /// 선택한 지갑 합계 기준 비중(0~1). 합계가 0이면 0.
  final double share;

  /// 기간 시작 잔액 대비 현재 잔액의 차이
  final int change;

  /// 기간 중 첫 거래로 잔액이 생긴 날. 기간 시작 잔액이 0이고 첫 거래가 기간 안일 때만 값이 있다.
  final DateTime? firstActiveDay;

  const WalletBalanceRow({
    required this.input,
    required this.share,
    required this.change,
    required this.firstActiveDay,
  });

  int get walletId => input.walletId;
  int get balance => input.current;
}

/// 선택한 지갑들로 다시 계산한 결과
class WalletBalanceBreakdown {
  /// 포함된 지갑 줄. 정렬 기준이 적용돼 있다.
  final List<WalletBalanceRow> rows;

  /// 정렬 기준과 상관없이 잔액이 큰 순으로 고정한 줄. 도넛·범례가 쓴다.
  final List<WalletBalanceRow> balanceRows;

  /// 차트의 쌓임 순서. 정렬 기준과 상관없이 현재 잔액이 큰 지갑이 아래에 온다.
  final List<WalletBalanceInput> stack;
  final int total;
  final int change;

  /// 포함된 지갑 합계의 매일 잔액
  final List<int> totals;

  const WalletBalanceBreakdown({
    required this.rows,
    required this.balanceRows,
    required this.stack,
    required this.total,
    required this.change,
    required this.totals,
  });

  /// 포함된 지갑이 하나뿐이면 도넛·비중 대신 잔액 변화로 보여 준다.
  bool get isSingle => rows.length == 1;

  /// [day] 번째 날 지갑별 비중(0~1). 합계가 0이면 모두 0이다. [stack] 순서.
  List<double> sharesAt(int day) {
    final total = totals[day];
    return [for (final input in stack) total <= 0 ? 0.0 : input.balances[day] / total];
  }
}

class WalletBalanceDetailMath {
  /// 비중(0~1). 합계가 0 이하면 0.
  static double shareOf(int balance, int total) => total <= 0 ? 0 : balance / total;

  /// 칩을 눌렀을 때의 새 제외 집합. 이미 제외한 지갑은 다시 넣고, 마지막 한 개는 제외하지 못한다.
  /// [existingIds]에 없는 id(삭제된 지갑)는 결과에서 걷어 낸다.
  static Set<int> toggleExcluded(Set<int> excluded, int walletId, Iterable<int> existingIds) {
    final ids = existingIds.toSet();
    final next = {
      for (final id in excluded)
        if (ids.contains(id)) id,
    };
    if (next.remove(walletId)) return next;
    final included = ids.where((id) => !next.contains(id)).length;
    if (included > 1 && ids.contains(walletId)) next.add(walletId);
    return next;
  }

  /// 화면이 들고 있는 제외 집합을 현재 있는 지갑 기준으로 바로잡는다.
  /// 삭제된 id는 걷어 내고, 남은 지갑이 모두 제외된 상태면 제외 집합을 비운다.
  static Set<int> normalizeExcluded(Set<int> excluded, Iterable<int> existingIds) {
    final ids = existingIds.toSet();
    final next = {
      for (final id in excluded)
        if (ids.contains(id)) id,
    };
    return next.length >= ids.length ? <int>{} : next;
  }

  /// 지갑 이름 옆 라벨. 금고는 보기 전용이기도 하지만 '금고'로만 표시한다.
  static List<WalletKindTag> tagsOf({required bool hasLocalKey, required bool isVault, required bool isMultisig}) => [
    if (hasLocalKey) WalletKindTag.hot else if (isVault) WalletKindTag.vault else WalletKindTag.watchOnly,
    if (isMultisig) WalletKindTag.multisig,
  ];

  /// 기간 중 첫 거래로 잔액이 생긴 날. 기간 시작 잔액이 0이 아니거나 첫 거래가 기간 밖이면 null.
  static DateTime? firstActiveDay(WalletBalanceInput input, List<DateTime> days) {
    final first = input.firstTransactionAt?.toLocal();
    if (first == null || days.isEmpty || input.start != 0) return null;
    final day = DateTime(first.year, first.month, first.day);
    final startDay = days.first;
    // 시작일 당일 거래는 이미 시작 잔액에 들어가 있으므로 그 다음 날부터 '기간 중'이다.
    return day.isAfter(startDay) && !day.isAfter(days.last) ? day : null;
  }

  /// 정렬 기준에 맞게 줄을 늘어놓는다. 같은 값이면 잔액이 큰 쪽, 그것도 같으면 원래 순서를 지킨다.
  static List<WalletBalanceRow> sorted(List<WalletBalanceRow> rows, WalletBalanceSort sort) {
    final indexed = rows.indexed.toList();
    indexed.sort((a, b) {
      final byBalance = b.$2.balance.compareTo(a.$2.balance);
      final primary = switch (sort) {
        WalletBalanceSort.balance => byBalance,
        WalletBalanceSort.change => b.$2.change.compareTo(a.$2.change),
      };
      if (primary != 0) return primary;
      if (byBalance != 0) return byBalance;
      return a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }

  /// [wallets] 중 [excluded]를 뺀 지갑으로 합계·비중·변화량을 다시 계산한다.
  /// 모두 제외된 상태(삭제 등)면 전부 다시 넣는다. [days]는 [WalletBalanceInput.balances]와 같은 길이의 날짜다.
  static WalletBalanceBreakdown compose({
    required List<WalletBalanceInput> wallets,
    required Set<int> excluded,
    required List<DateTime> days,
    WalletBalanceSort sort = WalletBalanceSort.balance,
  }) {
    final kept = [
      for (final wallet in wallets)
        if (!excluded.contains(wallet.walletId)) wallet,
    ];
    final included = kept.isEmpty ? wallets : kept;
    final length = days.length;
    final totals = [for (var i = 0; i < length; i++) included.fold<int>(0, (sum, wallet) => sum + wallet.balances[i])];
    final total = totals.isEmpty ? 0 : totals.last;
    final rows = [
      for (final wallet in included)
        WalletBalanceRow(
          input: wallet,
          share: shareOf(wallet.current, total),
          change: wallet.current - wallet.start,
          firstActiveDay: firstActiveDay(wallet, days),
        ),
    ];
    final stack = [
      for (final entry
          in ([...included].indexed.toList()..sort((a, b) {
            final byBalance = b.$2.current.compareTo(a.$2.current);
            return byBalance != 0 ? byBalance : a.$1.compareTo(b.$1);
          })))
        entry.$2,
    ];
    return WalletBalanceBreakdown(
      rows: sorted(rows, sort),
      balanceRows: sorted(rows, WalletBalanceSort.balance),
      stack: stack,
      total: total,
      change: totals.isEmpty ? 0 : totals.last - totals.first,
      totals: totals,
    );
  }
}
