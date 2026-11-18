import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';

enum ArkActivityGroupKind { pending, today, yesterday, day }

class ArkActivityGroup {
  const ArkActivityGroup(this.kind, this.movements, {this.day});

  final ArkActivityGroupKind kind;
  final List<ArkMovement> movements;

  /// [ArkActivityGroupKind.day]의 날짜
  final DateTime? day;
}

/// 진행 중 묶음을 먼저, 그다음 날짜별로 최신순
List<ArkActivityGroup> groupArkMovements(List<ArkMovement> movements, DateTime now) {
  final sorted = [...movements]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final pending = sorted.where((movement) => movement.isPending).toList();
  final byDay = <DateTime, List<ArkMovement>>{};
  for (final movement in sorted.where((movement) => !movement.isPending)) {
    final local = movement.timestamp.toLocal();
    byDay.putIfAbsent(DateTime(local.year, local.month, local.day), () => []).add(movement);
  }
  return [
    if (pending.isNotEmpty) ArkActivityGroup(ArkActivityGroupKind.pending, pending),
    for (final entry in byDay.entries)
      ArkActivityGroup(
        entry.key == today
            ? ArkActivityGroupKind.today
            : entry.key == yesterday
            ? ArkActivityGroupKind.yesterday
            : ArkActivityGroupKind.day,
        entry.value,
        day: entry.key,
      ),
  ];
}
