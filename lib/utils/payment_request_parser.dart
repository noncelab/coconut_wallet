import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/ark/ark_payment.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';

enum PaymentRequestKind {
  bitcoinAddress,
  arkAddress,
  lightningInvoice,
  lightningAddress,

  /// A `bitcoin:` URI (BIP21/BIP321), which may carry `ark=` and `lightning=` alongside (or
  /// instead of) an on-chain address.
  bip321,

  /// Recognized but not payable here (BOLT12 offers, LNURL, another network).
  unsupported,
  unknown,
}

/// Why a request can't be paid.
enum PaymentRequestProblem {
  nothingEntered,
  unknown,
  bolt12,
  lnurl,
  invoiceNetwork,
  arkNetwork,

  /// A BIP21 `req-` parameter Coconut doesn't understand; [PaymentRequest.problemDetail] names it.
  requiredParameter,
  invalidBitcoinAddress,
  invalidAmount,
  noMethod,
}

/// One way to pay a request from the Ark balance.
class ArkPaymentOption {
  const ArkPaymentOption(this.rail, this.destination);

  final ArkPaymentRail rail;
  final String destination;
}

/// What a pasted, scanned or typed payment string asks for. bark-ffi doesn't expose bark's own
/// `parse_payment_request`, so Coconut parses it here.
class PaymentRequest {
  const PaymentRequest._({
    required this.kind,
    required this.raw,
    this.bitcoinAddress,
    this.arkAddress,
    this.lightningInvoice,
    this.lightningAddress,
    this.amountSats,
    this.invoiceAmountSats,
    this.problem,
    this.problemDetail,
  });

  final PaymentRequestKind kind;
  final String raw;
  final String? bitcoinAddress;
  final String? arkAddress;
  final String? lightningInvoice;
  final String? lightningAddress;

  /// The amount the request asks for (a BIP321 `amount`, or the invoice's), if any.
  final int? amountSats;

  /// The amount encoded in [lightningInvoice]; null for an amountless invoice.
  final int? invoiceAmountSats;

  /// Why it can't be paid, for [PaymentRequestKind.unsupported] and [PaymentRequestKind.unknown].
  final PaymentRequestProblem? problem;

  /// What the problem is about, when it names something (a `req-` parameter).
  final String? problemDetail;

  bool get hasArkOrLightning => arkAddress != null || lightningInvoice != null || lightningAddress != null;

  /// Whether it can be paid at all (not unsupported or unknown).
  bool get isPayable => kind != PaymentRequestKind.unsupported && kind != PaymentRequestKind.unknown;

  /// The ways to pay it from Ark, cheapest first: an Ark payment, then Lightning, then on-chain.
  List<ArkPaymentOption> get arkOptions => [
    if (arkAddress != null) ArkPaymentOption(ArkPaymentRail.ark, arkAddress!),
    if (lightningInvoice != null) ArkPaymentOption(ArkPaymentRail.lightningInvoice, lightningInvoice!),
    if (lightningAddress != null) ArkPaymentOption(ArkPaymentRail.lightningAddress, lightningAddress!),
    if (bitcoinAddress != null) ArkPaymentOption(ArkPaymentRail.onchain, bitcoinAddress!),
  ];

  static PaymentRequest parse(String input, NetworkType network) {
    final raw = input.trim();
    final lower = raw.toLowerCase();
    if (raw.isEmpty) return PaymentRequest._(kind: PaymentRequestKind.unknown, raw: raw, problem: PaymentRequestProblem.nothingEntered);
    if (lower.startsWith('bitcoin:')) return _parseBip321(raw, network);

    final withoutScheme = lower.startsWith('lightning:') ? raw.substring('lightning:'.length) : raw;
    final candidate = withoutScheme.trim();
    final candidateLower = candidate.toLowerCase();

    if (candidateLower.startsWith('lno1')) return _unsupported(raw, PaymentRequestProblem.bolt12);
    if (candidateLower.startsWith('lnurl1')) return _unsupported(raw, PaymentRequestProblem.lnurl);
    if (_looksLikeBolt11(candidateLower)) return _parseInvoice(raw, candidateLower, network);
    if (_lightningAddress.hasMatch(candidate)) {
      return PaymentRequest._(kind: PaymentRequestKind.lightningAddress, raw: raw, lightningAddress: candidateLower);
    }
    if (_arkAddress.hasMatch(candidateLower)) return _parseArkAddress(raw, candidateLower, network);
    if (AddressValidator.validateAddress(candidate, network) == null) {
      return PaymentRequest._(
        kind: PaymentRequestKind.bitcoinAddress,
        raw: raw,
        bitcoinAddress: normalizeAddress(candidate),
      );
    }
    return PaymentRequest._(kind: PaymentRequestKind.unknown, raw: raw, problem: PaymentRequestProblem.unknown);
  }

  /// The amount of a BOLT11 invoice in sats (rounded up from msat), or null when amountless or
  /// malformed. Only the human-readable part is read; bark checks the rest when paying.
  static int? bolt11AmountSats(String invoice) {
    final lower = invoice.toLowerCase();
    final prefix = _invoicePrefixes.where(lower.startsWith).firstOrNull;
    final separator = lower.lastIndexOf('1');
    if (prefix == null || separator < prefix.length) return null;
    final amountPart = lower.substring(prefix.length, separator);
    if (amountPart.isEmpty) return null;
    final match = RegExp(r'^([1-9][0-9]*)([munp]?)$').firstMatch(amountPart);
    if (match == null) return null;
    final value = BigInt.parse(match.group(1)!);
    final BigInt msat;
    switch (match.group(2)) {
      case 'm':
        msat = value * BigInt.from(100000000);
      case 'u':
        msat = value * BigInt.from(100000);
      case 'n':
        msat = value * BigInt.from(100);
      case 'p':
        // 1 msat = 10 pico-BTC; a pico amount that isn't a whole msat is invalid.
        if (value % BigInt.from(10) != BigInt.zero) return null;
        msat = value ~/ BigInt.from(10);
      default:
        msat = value * BigInt.from(100000000000);
    }
    return ((msat + BigInt.from(999)) ~/ BigInt.from(1000)).toInt();
  }

  /// The BOLT11 prefix for [network]; Coconut has no signet flavor.
  static String invoicePrefixFor(NetworkType network) {
    if (network == NetworkType.mainnet) return 'lnbc';
    if (network == NetworkType.testnet) return 'lntb';
    return 'lnbcrt';
  }

  // Longest first, so "lnbcrt" isn't read as "lnbc" and "lntbs" as "lntb".
  static const _invoicePrefixes = ['lnbcrt', 'lntbs', 'lnbc', 'lntb'];
  static final _lightningAddress = RegExp(r'^[a-zA-Z0-9._+-]+@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$');
  static final _arkAddress = RegExp(r'^t?ark1[02-9ac-hj-np-z]{20,}$');

  static bool _looksLikeBolt11(String lower) => _invoicePrefixes.any(lower.startsWith) && lower.contains('1');

  static PaymentRequest _unsupported(String raw, PaymentRequestProblem problem, {String? detail}) =>
      PaymentRequest._(kind: PaymentRequestKind.unsupported, raw: raw, problem: problem, problemDetail: detail);

  static PaymentRequest _parseInvoice(String raw, String invoice, NetworkType network) {
    final prefix = _invoicePrefixes.firstWhere(invoice.startsWith);
    if (prefix != invoicePrefixFor(network)) return _unsupported(raw, PaymentRequestProblem.invoiceNetwork);
    final amount = bolt11AmountSats(invoice);
    return PaymentRequest._(
      kind: PaymentRequestKind.lightningInvoice,
      raw: raw,
      lightningInvoice: invoice,
      amountSats: amount,
      invoiceAmountSats: amount,
    );
  }

  static PaymentRequest _parseArkAddress(String raw, String address, NetworkType network) {
    final isMainnetAddress = address.startsWith('ark1');
    if (isMainnetAddress != (network == NetworkType.mainnet)) {
      return _unsupported(raw, PaymentRequestProblem.arkNetwork);
    }
    return PaymentRequest._(kind: PaymentRequestKind.arkAddress, raw: raw, arkAddress: address);
  }

  static PaymentRequest _parseBip321(String raw, NetworkType network) {
    final body = raw.substring('bitcoin:'.length);
    final queryStart = body.indexOf('?');
    final addressPart = Uri.decodeComponent(queryStart == -1 ? body : body.substring(0, queryStart)).trim();
    final params = <String, String>{};
    if (queryStart != -1) {
      for (final pair in body.substring(queryStart + 1).split('&')) {
        if (pair.isEmpty) continue;
        final separator = pair.indexOf('=');
        final key = Uri.decodeQueryComponent(separator == -1 ? pair : pair.substring(0, separator)).toLowerCase();
        final value = separator == -1 ? '' : Uri.decodeQueryComponent(pair.substring(separator + 1));
        params.putIfAbsent(key, () => value);
      }
    }
    // BIP21: a required parameter we don't understand means we can't pay it correctly.
    final unknownRequired = params.keys.where((key) => key.startsWith('req-')).firstOrNull;
    if (unknownRequired != null) {
      return _unsupported(raw, PaymentRequestProblem.requiredParameter, detail: unknownRequired);
    }

    String? bitcoinAddress;
    if (addressPart.isNotEmpty) {
      if (AddressValidator.validateAddress(addressPart, network) != null) {
        return _unsupported(raw, PaymentRequestProblem.invalidBitcoinAddress);
      }
      bitcoinAddress = normalizeAddress(addressPart);
    } else {
      // BIP321 also allows the on-chain address as a parameter named after its human-readable
      // part. bark keys regtest addresses as `tb=`, so accept any of them that is valid here.
      for (final key in const ['bc', 'tb', 'bcrt']) {
        final candidate = params[key]?.trim();
        if (candidate != null && AddressValidator.validateAddress(candidate, network) == null) {
          bitcoinAddress = normalizeAddress(candidate);
          break;
        }
      }
    }

    String? arkAddress;
    final ark = params['ark']?.trim().toLowerCase();
    if (ark != null && _arkAddress.hasMatch(ark) && ark.startsWith('ark1') == (network == NetworkType.mainnet)) {
      arkAddress = ark;
    }

    String? invoice;
    int? invoiceAmount;
    final lightning = params['lightning']?.trim().toLowerCase();
    if (lightning != null && _looksLikeBolt11(lightning) && lightning.startsWith(invoicePrefixFor(network))) {
      invoice = lightning;
      invoiceAmount = bolt11AmountSats(lightning);
    }

    int? amount;
    final amountText = params['amount'];
    if (amountText != null && amountText.isNotEmpty) {
      final btc = double.tryParse(amountText);
      if (btc == null || btc <= 0) return _unsupported(raw, PaymentRequestProblem.invalidAmount);
      amount = UnitUtil.convertBitcoinToSatoshi(btc);
    }

    if (bitcoinAddress == null && arkAddress == null && invoice == null) {
      return _unsupported(raw, PaymentRequestProblem.noMethod);
    }
    return PaymentRequest._(
      kind: PaymentRequestKind.bip321,
      raw: raw,
      bitcoinAddress: bitcoinAddress,
      arkAddress: arkAddress,
      lightningInvoice: invoice,
      amountSats: amount ?? invoiceAmount,
      invoiceAmountSats: invoiceAmount,
    );
  }
}
