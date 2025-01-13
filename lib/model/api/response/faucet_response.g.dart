// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'faucet_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FaucetResponse _$FaucetResponseFromJson(Map<String, dynamic> json) =>
    FaucetResponse(
      address: json['address'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      txHash: json['txHash'] as String? ?? '',
    );

Map<String, dynamic> _$FaucetResponseToJson(FaucetResponse instance) =>
    <String, dynamic>{
      'address': instance.address,
      'amount': instance.amount,
      'txHash': instance.txHash,
    };
