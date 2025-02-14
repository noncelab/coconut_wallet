class TransactionAddress {
  final String _address;
  final int _amount;

  /// The address string.
  String get address => _address;

  /// The amount of the address.
  int get amount => _amount;

  TransactionAddress(this._address, this._amount);
}
