import 'package:coconut_wallet/localization/strings.g.dart';

enum TransactionStatus { received, receiving, sent, sending, self, selfsending }

enum TransactionFeeLevel { fastest, halfhour, hour }

enum TransactionDirection { incoming, outgoing, unknown }

extension TransactionFeeLevelExtension on TransactionFeeLevel {
  String get text {
    switch (this) {
      case TransactionFeeLevel.fastest:
        return t.transaction_enums.high_priority;
      case TransactionFeeLevel.halfhour:
        return t.transaction_enums.medium_priority;
      case TransactionFeeLevel.hour:
        return t.transaction_enums.low_priority;
    }
  }

  String get expectedTime {
    switch (this) {
      case TransactionFeeLevel.fastest:
        return t.transaction_enums.expected_time_high_priority;
      case TransactionFeeLevel.halfhour:
        return t.transaction_enums.expected_time_medium_priority;
      case TransactionFeeLevel.hour:
        return t.transaction_enums.expected_time_low_priority;
    }
  }
}
