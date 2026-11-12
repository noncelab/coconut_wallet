/// How a payment leaves the Ark wallet.
enum ArkPaymentRail {
  /// An Ark payment to an Ark address (arkoor): instant, off-chain.
  ark,

  /// A BOLT11 invoice, paid over Lightning through the Ark server.
  lightningInvoice,

  /// A Lightning address (`user@domain`), resolved over LNURL-pay.
  lightningAddress,

  /// An on-chain payment from the Ark balance to a Bitcoin address.
  onchain,
}
