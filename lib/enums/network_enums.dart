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
