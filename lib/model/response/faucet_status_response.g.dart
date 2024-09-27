// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'faucet_status_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FaucetStatusResponse _$FaucetStatusResponseFromJson(
        Map<String, dynamic> json) =>
    FaucetStatusResponse(
      totalBalance: (json['totalBalance'] as num?)?.toDouble() ?? 0,
      todayBalance: (json['todayBalance'] as num?)?.toDouble() ?? 0,
      todayRequestedCount: (json['todayRequestedCount'] as num?)?.toInt() ?? 0,
      maxLimit: (json['maxLimit'] as num?)?.toDouble() ?? 0,
      minLimit: (json['minLimit'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$FaucetStatusResponseToJson(
        FaucetStatusResponse instance) =>
    <String, dynamic>{
      'totalBalance': instance.totalBalance,
      'todayBalance': instance.todayBalance,
      'todayRequestedCount': instance.todayRequestedCount,
      'maxLimit': instance.maxLimit,
      'minLimit': instance.minLimit,
    };
