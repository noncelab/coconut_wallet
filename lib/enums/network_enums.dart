enum ConnectionTypeEnum { electrum, rpc }

enum UtxoOrderEnum {
  byAmountDesc,
  byAmountAsc,
  byTimestampDesc,
  byTimestampAsc
}

enum TransactionTypeEnum {
  received('RECEIVED'),
  sent('SENT'),
  unknown('UNKNOWN'),
  self('SELF');

  const TransactionTypeEnum(this.name);

  final String name;
}

enum SocketConnectionStatus { reconnecting, connecting, connected, terminated }

/// 갱신된 데이터 종류
enum UpdateType { balance, utxo, transaction }

/// 갱신된 데이터의 상태
enum UpdateTypeState { waiting, syncing, completed }

/// 메인 소켓의 상태, 지갑 중 어느 하나라도 동기화 중이면 syncing, 모두 동기화 완료면 waiting로 변경
enum MainClientState { waiting, syncing, disconnected }
