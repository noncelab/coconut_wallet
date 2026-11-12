import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/payment_request_parser.dart';

/// Why a row of Send's first page can't be sent yet.
enum SendRecipientProblem {
  /// The destination can't be paid at all; the request's own problem says why.
  unsupported,

  /// One of several recipients without an on-chain address (Ark pays one destination), or a
  /// destination the only balance that may pay can't reach (a move from on-chain).
  onchainOnly,
  duplicate,
  needsAmount,
}

/// Which balance a recipient's "everything" comes from: tapping a balance box on Send's first page
/// fills the amount with that balance.
enum SendMaxSource { onchain, ark }

/// Which balances may pay: either (a send), or only one (a move from that balance).
enum SendFunding { any, onchain, ark }

/// One row of Send's first page, as entered.
class SendRecipientRow {
  const SendRecipientRow(this.input, {this.enteredAmountSats, this.maxSource});

  final String input;
  final int? enteredAmountSats;

  /// Send everything left in this balance to this row; honoured only where the rules allow it.
  final SendMaxSource? maxSource;
}

/// What Send's first page found in one row.
class SendRecipientCheck {
  const SendRecipientCheck({
    this.request,
    this.fixedAmountSats,
    this.amountSats,
    this.problem,
    this.canUseOnchainMax = false,
    this.canUseArkMax = false,
    this.maxSource,
  });

  /// Null for an empty row.
  final PaymentRequest? request;

  /// The amount the destination carries (an invoice's, or a BIP21/BIP321 `amount`).
  final int? fixedAmountSats;

  /// The amount to send: the fixed one, else the one entered; null when it's "everything".
  final int? amountSats;

  /// Why the row can't be sent yet.
  final SendRecipientProblem? problem;

  /// Whether the row may take everything left on-chain: the last row, with a Bitcoin address and
  /// no fixed amount.
  final bool canUseOnchainMax;

  /// Whether the row may take everything in Ark: the only row, with a Bitcoin or Ark address and no
  /// fixed amount.
  final bool canUseArkMax;

  /// The balance this row takes everything from, when it does.
  final SendMaxSource? maxSource;

  bool get isEmpty => request == null;
  bool get isValid => !isEmpty && problem == null;
}

/// The rules for Send's first page: one recipient can be anything payable; several are paid in
/// one on-chain transaction, so each needs an on-chain address (Ark pays one destination). A move
/// ([funding] other than [SendFunding.any]) pays only from its source balance.
class SendRecipientList {
  SendRecipientList(
    List<SendRecipientRow> rows, {
    required NetworkType network,
    required int onchainAvailableSats,
    required int arkAvailableSats,
    this.funding = SendFunding.any,
  }) {
    final requests = [
      for (final row in rows) row.input.trim().isEmpty ? null : PaymentRequest.parse(row.input.trim(), network),
    ];
    final filled = [
      for (var i = 0; i < rows.length; i++)
        if (requests[i] != null) i,
    ];
    final several = filled.length > 1;
    final lastFilled = filled.isEmpty ? null : filled.last;
    final seen = <String>{};

    for (var i = 0; i < rows.length; i++) {
      final request = requests[i];
      if (request == null) {
        checks.add(const SendRecipientCheck());
        continue;
      }
      final row = rows[i];
      final fixed = request.amountSats;
      final address = request.bitcoinAddress == null ? null : normalizeAddress(request.bitcoinAddress!);
      final open = fixed == null && request.isPayable;
      final canUseOnchainMax = funding != SendFunding.ark && i == lastFilled && address != null && open;
      final canUseArkMax =
          funding != SendFunding.onchain && !several && open && (address != null || request.arkAddress != null);
      final maxSource = switch (row.maxSource) {
        SendMaxSource.onchain when canUseOnchainMax => SendMaxSource.onchain,
        SendMaxSource.ark when canUseArkMax => SendMaxSource.ark,
        _ => null,
      };
      final amount = maxSource != null ? null : (fixed ?? row.enteredAmountSats);
      SendRecipientProblem? problem;
      if (!request.isPayable) {
        problem = SendRecipientProblem.unsupported;
      } else if ((several || funding == SendFunding.onchain) && address == null) {
        problem = SendRecipientProblem.onchainOnly;
      } else if (several && !seen.add(address!)) {
        problem = SendRecipientProblem.duplicate;
      } else if (maxSource == null && (amount == null || amount <= 0)) {
        problem = SendRecipientProblem.needsAmount;
      }
      checks.add(
        SendRecipientCheck(
          request: request,
          fixedAmountSats: fixed,
          amountSats: amount,
          problem: problem,
          canUseOnchainMax: canUseOnchainMax,
          canUseArkMax: canUseArkMax,
          maxSource: maxSource,
        ),
      );
      if (maxSource == SendMaxSource.onchain) maxLast = true;
      if (maxSource == SendMaxSource.ark) maxFromArk = true;
    }

    final first = filled.isEmpty ? null : checks[filled.first].request;
    final total = checks.fold<int>(0, (sum, check) => sum + (check.amountSats ?? 0));
    final int available;
    if (funding == SendFunding.onchain || several) {
      available = onchainAvailableSats;
    } else if (funding == SendFunding.ark) {
      available = arkAvailableSats;
    } else if (first == null) {
      available = onchainAvailableSats;
    } else {
      // A single recipient can be paid from either balance it can use.
      available = [
        if (first.bitcoinAddress != null) onchainAvailableSats,
        if (first.bitcoinAddress != null || first.hasArkOrLightning) arkAvailableSats,
      ].fold(0, (best, sats) => sats > best ? sats : best);
    }
    exceedsAvailable = total > available;
  }

  final SendFunding funding;
  final List<SendRecipientCheck> checks = [];

  /// The amounts add up to more than any balance that could pay them.
  bool exceedsAvailable = false;

  /// The last recipient gets everything left on-chain.
  bool maxLast = false;

  /// The only recipient gets everything in Ark.
  bool maxFromArk = false;

  /// The filled rows, in order.
  List<SendRecipientCheck> get recipients => checks.where((check) => !check.isEmpty).toList();

  /// As the send screen: every page needs a recipient, so an added page left empty holds Next back.
  bool get canContinue => !exceedsAvailable && checks.isNotEmpty && checks.every((check) => check.isValid);
}
