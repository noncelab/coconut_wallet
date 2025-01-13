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
