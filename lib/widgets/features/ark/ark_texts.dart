import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/wallet/wallet_activity.dart';
import 'package:coconut_wallet/utils/payment_request_parser.dart';

String formatSats(BitcoinUnit unit, int sats) =>
    unit.displayBitcoinAmount(sats, withUnit: true, shouldCheckZero: true, defaultWhenZero: '0 ${unit.symbol}');

String arkRailText(ArkRail rail) => switch (rail) {
  ArkRail.onchain => t.ark.rail.onchain,
  ArkRail.ark => t.ark.rail.ark,
  ArkRail.lightning => t.ark.rail.lightning,
};

String? arkActivityLabelText(ArkActivityLabel? label) {
  final texts = t.ark.activity;
  return switch (label) {
    null => null,
    ArkActivityLabel.refresh => texts.refresh,
    ArkActivityLabel.movedToArk => texts.moved_to_ark,
    ArkActivityLabel.movedOnchain => texts.moved_onchain,
    ArkActivityLabel.exit => texts.exit,
    ArkActivityLabel.failed => texts.failed,
    ArkActivityLabel.canceled => texts.canceled,
  };
}

/// 목록·최근 거래·상세에서 같은 이름을 쓰도록, 갱신은 진행 상태까지 담음
String? arkActivityText(ArkActivity activity) {
  if (activity.label != ArkActivityLabel.refresh) return arkActivityLabelText(activity.label);
  return switch (activity.movement.status) {
    ArkMovementStatus.pending => t.ark.activity.refresh_pending,
    ArkMovementStatus.failed || ArkMovementStatus.canceled => t.ark.activity.refresh_failed,
    _ => t.ark.activity.refresh_done,
  };
}

/// 거래 목록과 같은 상태 문구(받기 완료, 보내기 완료, 갱신 완료 등)
String activityStatusText(WalletActivity activity) {
  if (activity is ArkActivity) {
    final label = arkActivityText(activity);
    if (label != null) return label;
  }
  return switch (activity.status) {
    TransactionStatus.receiving => t.status_receiving,
    TransactionStatus.sending || TransactionStatus.selfsending => t.status_sending,
    TransactionStatus.sent || TransactionStatus.self => t.status_sent,
    _ => t.status_received,
  };
}

/// 보낼 수 없는 결제 요청의 이유
String? paymentRequestProblemText(PaymentRequest request) {
  final texts = t.ark.request_problem;
  return switch (request.problem) {
    null || PaymentRequestProblem.nothingEntered => null,
    PaymentRequestProblem.unknown || PaymentRequestProblem.invalidBitcoinAddress => t.errors.address_error.invalid,
    PaymentRequestProblem.bolt12 => texts.bolt12,
    PaymentRequestProblem.lnurl => texts.lnurl,
    PaymentRequestProblem.invoiceNetwork => texts.invoice_network,
    PaymentRequestProblem.arkNetwork => texts.ark_network,
    PaymentRequestProblem.requiredParameter => texts.required_parameter(name: request.problemDetail ?? ''),
    PaymentRequestProblem.invalidAmount => texts.invalid_amount,
    PaymentRequestProblem.noMethod => texts.no_method,
  };
}
