class SendInfoProvider {
  int? _walletId;
  String? _receipientAddress;
  double? _amount;

  int? get walletId => _walletId;
  String? get receipientAddress => _receipientAddress;
  double? get amount => _amount;

  setWalletId(int id) {
    _walletId = id;
  }

  setReceipientAddress(String address) {
    _receipientAddress = address;
  }

  setAmount(double amount) {
    _amount = amount;
  }
}
