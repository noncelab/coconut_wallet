import 'package:coconut_lib/coconut_lib.dart';

enum TransactionStatus { received, receiving, sent, sending, self, selfsending }

enum TransactionFeeLevel { fastest, halfhour, hour }

extension TransactionFeeLevelExtension on TransactionFeeLevel {
  String get text {
    switch (this) {
      case TransactionFeeLevel.fastest:
        return "빠른 전송";
      case TransactionFeeLevel.halfhour:
        return "보통 전송";
      case TransactionFeeLevel.hour:
        return "느린 전송";
    }
  }

  String get expectedTime {
    switch (this) {
      case TransactionFeeLevel.fastest:
        return "~10분";
      case TransactionFeeLevel.halfhour:
        return "~30분";
      case TransactionFeeLevel.hour:
        return "~1시간";
    }
  }
}

enum SyncResult {
  newWalletAdded,
  existingWalletUpdated,
  existingWalletNoUpdate,
  existingName, // fail sync
}

extension UtxoOrderEnumExtension on UtxoOrderEnum {
  String get text {
    switch (this) {
      case UtxoOrderEnum.byAmountDesc:
        return "큰 금액순";
      case UtxoOrderEnum.byAmountAsc:
        return "작은 금액순";
      case UtxoOrderEnum.byTimestampDesc:
        return "최신순";
      case UtxoOrderEnum.byTimestampAsc:
        return "오래된 순";
    }
  }
}
