/// 지갑의 트랜잭션 fetch 요청 진행 상태
class WalletFetchProgress {
  final int dispatched;
  final int completed;

  const WalletFetchProgress({this.dispatched = 0, this.completed = 0});

  bool get isFetching => completed < dispatched;

  WalletFetchProgress copyWith({int? dispatched, int? completed}) {
    return WalletFetchProgress(dispatched: dispatched ?? this.dispatched, completed: completed ?? this.completed);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletFetchProgress &&
          runtimeType == other.runtimeType &&
          dispatched == other.dispatched &&
          completed == other.completed;

  @override
  int get hashCode => Object.hash(dispatched, completed);
}
