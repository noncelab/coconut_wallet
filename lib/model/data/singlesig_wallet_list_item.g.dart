// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'singlesig_wallet_list_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SinglesigWalletListItem _$SinglesigWalletListItemFromJson(
        Map<String, dynamic> json) =>
    SinglesigWalletListItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      colorIndex: (json['colorIndex'] as num).toInt(),
      iconIndex: (json['iconIndex'] as num).toInt(),
      descriptor: json['descriptor'] as String,
      balance: (json['balance'] as num?)?.toInt(),
    )
      ..walletType = $enumDecode(_$WalletTypeEnumMap, json['walletType'])
      ..txCount = (json['txCount'] as num?)?.toInt()
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

Map<String, dynamic> _$SinglesigWalletListItemToJson(
        SinglesigWalletListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'colorIndex': instance.colorIndex,
      'iconIndex': instance.iconIndex,
      'descriptor': instance.descriptor,
      'walletType': _$WalletTypeEnumMap[instance.walletType]!,
      'balance': instance.balance,
      'txCount': instance.txCount,
      'isLatestTxBlockHeightZero': instance.isLatestTxBlockHeightZero,
      'addressBalanceMap': instance.addressBalanceMap?.map((k, e) =>
          MapEntry(k.toString(), e.map((k, e) => MapEntry(k.toString(), e)))),
      'usedIndexList':
          instance.usedIndexList?.map((k, e) => MapEntry(k.toString(), e)),
    };

const _$WalletTypeEnumMap = {
  WalletType.singleSignature: 'singleSignature',
  WalletType.multiSignature: 'multiSignature',
};
