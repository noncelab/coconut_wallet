// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_list_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WalletListItem _$WalletListItemFromJson(Map<String, dynamic> json) =>
    WalletListItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      colorIndex: (json['colorIndex'] as num).toInt(),
      iconIndex: (json['iconIndex'] as num).toInt(),
      descriptor: json['descriptor'] as String,
      balance: (json['balance'] as num?)?.toInt(),
      txCount: (json['txCount'] as num?)?.toInt(),
    )
      ..isLatestTxBlockHeightZero = json['isLatestTxBlockHeightZero'] as bool
      ..addressBalanceMap =
          (json['addressBalanceMap'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
            int.parse(k),
            (e as Map<String, dynamic>).map(
              (k, e) => MapEntry(int.parse(k), (e as num).toInt()),
            )),
      )
      ..usedIndexList = (json['usedIndexList'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(int.parse(k),
            (e as List<dynamic>).map((e) => (e as num).toInt()).toList()),
      );

Map<String, dynamic> _$WalletListItemToJson(WalletListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'colorIndex': instance.colorIndex,
      'iconIndex': instance.iconIndex,
      'descriptor': instance.descriptor,
      'balance': instance.balance,
      'txCount': instance.txCount,
      'isLatestTxBlockHeightZero': instance.isLatestTxBlockHeightZero,
      'addressBalanceMap': instance.addressBalanceMap?.map((k, e) =>
          MapEntry(k.toString(), e.map((k, e) => MapEntry(k.toString(), e)))),
      'usedIndexList':
          instance.usedIndexList?.map((k, e) => MapEntry(k.toString(), e)),
    };
