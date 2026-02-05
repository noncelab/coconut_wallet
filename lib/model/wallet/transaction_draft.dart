import 'dart:convert';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';

class TransactionDraft {
  final int id;
  final int walletId;
  final DateTime createdAt;

  // 서명 전 임시 저장
  final List<RecipientDraft>? recipients;
  final double? feeRate;
  final bool? isMaxMode;
  final bool? isFeeSubtractedFromSendAmount;

  /// 저장 시 사용한 비트코인 단위 ("BTC" / "sats")
  final BitcoinUnit? bitcoinUnit;

  /// 선택된 UTXO 리스트 (자동 선택 모드면 빈 리스트).
  final List<String> selectedUtxoIds;

  // 서명 후 임시 저장
  final String? txWaitingForSign;
  final String? signedPsbtBase64Encoded;

  const TransactionDraft({
    required this.id,
    required this.walletId,
    required this.createdAt,
    this.recipients,
    this.feeRate,
    this.isMaxMode,
    this.isFeeSubtractedFromSendAmount,
    this.bitcoinUnit,
    this.selectedUtxoIds = const [],
    this.txWaitingForSign,
    this.signedPsbtBase64Encoded,
  });

  bool get isSigned => signedPsbtBase64Encoded != null && txWaitingForSign != null;
}

class RecipientDraft {
  final String address;
  final int amount;

  RecipientDraft({required this.address, required this.amount});

  Map<String, dynamic> toJson() => {'address': address, 'amount': amount};

  factory RecipientDraft.fromJson(Map<String, dynamic> json) {
    return RecipientDraft(address: json['address'] as String, amount: json['amount'] as int);
  }

  factory RecipientDraft.fromRecipientInfo(String address, String amount, BitcoinUnit bitcoinUnit) {
    int? amountInSats;
    switch (bitcoinUnit) {
      case BitcoinUnit.btc:
        amountInSats = UnitUtil.convertBitcoinToSatoshi(double.parse(amount));
      case BitcoinUnit.sats:
        amountInSats = int.parse(amount);
    }

    return RecipientDraft(address: address, amount: amountInSats);
  }

  factory RecipientDraft.fromJsonString(String json) {
    return RecipientDraft.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  static List<RecipientDraft> fromJsonStringList(List<String> jsonList) {
    return jsonList.map((json) => RecipientDraft.fromJsonString(json)).toList();
  }

  static List<String> toJsonList(List<RecipientDraft> recipients) {
    return recipients.map((recipient) => jsonEncode(recipient.toJson())).toList();
  }
}
