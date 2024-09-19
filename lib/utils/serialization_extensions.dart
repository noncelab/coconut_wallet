import 'package:coconut_lib/coconut_lib.dart';

/// TODO: UPDATE TX_LIST
/// List<Transfer> to/from Json
extension TransferListSerialization on List<Transfer> {
  List<Map<String, dynamic>> toJsonList() {
    return map((transfer) => transfer.toJson()).toList();
  }
}

extension TransferListDeserialization on List<Transfer> {
  static List<Transfer> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((json) => TransferSerialization.fromJson(json))
        .toList();
  }
}

/// TODO: UPDATE TX_LIST
/// 라이브러리에 추가 필요함
extension TransferSerialization on Transfer {
  Map<String, dynamic> toJson() {
    return {
      'transactionHash': transactionHash,
      'timestamp': timestamp?.toIso8601String(),
      'blockHeight': blockHeight,
      'transferType': transferType,
      'memo': memo,
      'amount': amount,
      'fee': fee,
      'inputAddressList': inputAddressList,
      'outputAddressList': outputAddressList,
    };
  }

  static Transfer fromJson(Map<String, dynamic> json) {
    return Transfer(
      json['transactionHash'] ?? '',
      json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      json['blockHeight'],
      json['transferType'],
      json['memo'],
      json['amount'],
      json['fee'],
      List<String>.from(json['inputAddressList']),
      List<String>.from(json['outputAddressList']),
    );
  }
}
