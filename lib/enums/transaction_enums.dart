import 'package:coconut_wallet/localization/strings.g.dart';

enum TransactionStatus { received, receiving, sent, sending, self, selfsending }

enum TransactionFeeLevel { fastest, halfhour, hour }

enum TransactionDirection { incoming, outgoing, unknown }

enum TransactionDraftStatus {
  signed, // 서명된 트랜잭션
  unsignedFromSendScreen, // 보내기 화면에서 저장된 서명되지 않은 트랜잭션
  unsignedFromConfirmScreen, // 입력정보확인 화면에서 저장된 서명되지 않은 트랜잭션
}

extension TransactionDraftStatusExtension on TransactionDraftStatus {
  String get name {
    switch (this) {
      case TransactionDraftStatus.signed:
        return 'signed';
      case TransactionDraftStatus.unsignedFromSendScreen:
        return 'unsignedFromSendScreen';
      case TransactionDraftStatus.unsignedFromConfirmScreen:
        return 'unsignedFromConfirmScreen';
    }
  }

  static TransactionDraftStatus fromString(String name) {
    return TransactionDraftStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => TransactionDraftStatus.unsignedFromSendScreen,
    );
  }
}

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
