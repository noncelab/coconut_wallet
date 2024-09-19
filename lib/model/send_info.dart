class SendInfo {
  final String address;
  final double amount;

  SendInfo({required this.address, required this.amount});
}

class FullSendInfo extends SendInfo {
  final int satsPerVb;
  final int? estimatedFee;
  final bool isMaxMode;

  FullSendInfo({
    required this.satsPerVb,
    required this.estimatedFee,
    required this.isMaxMode,
    required super.address,
    required super.amount,
  });
}
