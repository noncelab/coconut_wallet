/// A BOLT11 invoice for receiving over Lightning into the Ark wallet.
class ArkLightningInvoice {
  const ArkLightningInvoice({
    required this.invoice,
    required this.paymentHash,
    required this.amountSats,
    required this.feeSats,
  });

  final String invoice;
  final String paymentHash;
  final int amountSats;

  /// What the Ark server charges to receive it, taken out of [amountSats].
  final int feeSats;

  int get netAmountSats => amountSats - feeSats;
}
