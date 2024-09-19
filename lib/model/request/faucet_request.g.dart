// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'faucet_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FaucetRequest _$FaucetRequestFromJson(Map<String, dynamic> json) =>
    FaucetRequest(
      address: json['address'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$FaucetRequestToJson(FaucetRequest instance) =>
    <String, dynamic>{
      'address': instance.address,
      'amount': instance.amount,
    };
