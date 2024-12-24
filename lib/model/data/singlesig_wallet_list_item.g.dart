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
      txCount: (json['txCount'] as num?)?.toInt(),
      isLatestTxBlockHeightZero:
          json['isLatestTxBlockHeightZero'] as bool? ?? false,
    )..walletType = $enumDecode(_$WalletTypeEnumMap, json['walletType']);

Map<String, dynamic> _$SinglesigWalletListItemToJson(
        SinglesigWalletListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'colorIndex': instance.colorIndex,
      'iconIndex': instance.iconIndex,
      'descriptor': instance.descriptor,
      'name': instance.name,
      'walletType': _$WalletTypeEnumMap[instance.walletType]!,
      'balance': instance.balance,
      'txCount': instance.txCount,
      'isLatestTxBlockHeightZero': instance.isLatestTxBlockHeightZero,
    };

const _$WalletTypeEnumMap = {
  WalletType.singleSignature: 'singleSignature',
  WalletType.multiSignature: 'multiSignature',
};
