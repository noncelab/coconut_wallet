/// Represents an address information in a wallet.
class WalletAddress {
  final String _address;
  final String _derivationPath;
  final int _index;
  bool _isUsed;
  int _confirmed;
  int _unconfirmed;
  int _total;
  final bool _isChange;

  /// The address string.
  String get address => _address;

  /// The derivation path of the address.
  String get derivationPath => _derivationPath;

  /// Check if this address is already used.
  bool get isUsed => _isUsed;

  /// The amount of the address.
  int get total => _total;

  int get confirmed => _confirmed;

  int get unconfirmed => _unconfirmed;

  /// The index of the address.
  int get index => _index;

  bool get isChange => _isChange;

  /// Creates a new address object.
  WalletAddress(
      this._address,
      this._derivationPath,
      this._index,
      this._isChange,
      this._isUsed,
      this._confirmed,
      this._unconfirmed,
      this._total);

  /// @nodoc
  @override
  int get hashCode => address.hashCode;

  /// @nodoc
  @override
  bool operator ==(Object other) {
    if (other is! WalletAddress) {
      return false;
    } else {
      return address == other.address;
    }
  }

  /// Set the amount of the address.
  void setConfirmed(int confirmed) {
    _confirmed = confirmed;
    _total = confirmed + _unconfirmed;
  }

  void setUnconfirmed(int unconfirmed) {
    _unconfirmed = unconfirmed;
    _total = confirmed + _unconfirmed;
  }

  /// Set the used status of the address.
  void setUsed(bool isUsed) {
    _isUsed = isUsed;
  }
}
