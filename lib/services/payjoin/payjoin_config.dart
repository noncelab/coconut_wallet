import 'dart:typed_data';

/// Where BIP 77 sessions are mediated.
///
/// The directory stores encrypted messages between sender and receiver. Every
/// request to it goes through an OHTTP relay so the directory never learns the
/// client's IP address, and the relay never sees the message contents. The
/// relay and the directory of one session are always run by different
/// operators; see `payjoinOperator`.
class PayjoinConfig {
  const PayjoinConfig({required this.directoryUrls, required this.ohttpRelayUrls, this.directoryCertificate});

  /// The mailrooms listed on https://payjoin.org/mailroom. Each one serves
  /// both roles, directory and OHTTP relay, from the one URL.
  ///
  /// Keep this list equal to that page. Each session picks among all of
  /// them at random, and wallets that ship a different subset can be told
  /// apart by the mailrooms they use.
  static const List<String> mailrooms = [
    'https://pj.bobspacebkk.com',
    'https://pj.pow.plan-b.foundation',
    'https://payjoin.lab.vinteum.org',
  ];

  static const PayjoinConfig defaults = PayjoinConfig(directoryUrls: mailrooms, ohttpRelayUrls: mailrooms);

  /// The configuration sessions use. Replaced only by test or local setups.
  static PayjoinConfig current = defaults;

  /// Directories a new receive session picks from at random. A sender uses
  /// whichever directory the receiver's URI names.
  final List<String> directoryUrls;
  final List<String> ohttpRelayUrls;

  /// DER certificate the directory must present when OHTTP keys are fetched.
  /// Null in production, where the system trust roots apply.
  final Uint8List? directoryCertificate;

  /// Receive sessions stay open for a day, matching the BIP 77 reference
  /// implementation, so a sender who scanned the URI late can still finish.
  static const Duration sessionExpiry = Duration(hours: 24);

  /// How often a foreground session asks the directory for news.
  static const Duration pollInterval = Duration(seconds: 5);
}
