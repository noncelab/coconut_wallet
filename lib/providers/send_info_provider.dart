class SendInfoProvider {
  int? _walletId;
  String? _receipientAddress;

  int? get walletId => _walletId;
  String? get receipientAddress => _receipientAddress;

  setWalletId(int id) {
    _walletId = id;
  }

  setReceipientAddress(String address) {
    _receipientAddress = address;
  }
}
