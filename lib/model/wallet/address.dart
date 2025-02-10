/// Represents an address information in a wallet.
class Address {
  final String _address;
  final String _derivationPath;
  final int _index;
  bool _isUsed;
  int _amount;

  /// The address string.
  String get address => _address;

  /// The derivation path of the address.
  String get derivationPath => _derivationPath;

  /// Check if this address is already used.
  bool get isUsed => _isUsed;

  /// The amount of the address.
  int get amount => _amount;

  /// The index of the address.
  int get index => _index;

  /// Creates a new address object.
  Address(this._address, this._derivationPath, this._index, this._isUsed,
      this._amount);

  /// @nodoc
  @override
  int get hashCode => address.hashCode;

  /// @nodoc
  @override
  bool operator ==(Object other) {
    if (other is! Address) {
      return false;
    } else {
      return address == other.address;
    }
  }

  /// Set the amount of the address.
  void setAmount(int amount) {
    _amount = amount;
  }

  /// Set the used status of the address.
  void setUsed(bool isUsed) {
    _isUsed = isUsed;
  }
}
