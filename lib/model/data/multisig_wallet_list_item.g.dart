// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'multisig_wallet_list_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MultisigWalletListItem _$MultisigWalletListItemFromJson(
        Map<String, dynamic> json) =>
    MultisigWalletListItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      colorIndex: (json['colorIndex'] as num).toInt(),
      iconIndex: (json['iconIndex'] as num).toInt(),
      descriptor: json['descriptor'] as String,
      signers: (json['signers'] as List<dynamic>)
          .map((e) => MultisigSigner.fromJson(e as Map<String, dynamic>))
          .toList(),
      requiredSignatureCount: (json['requiredSignatureCount'] as num).toInt(),
      balance: (json['balance'] as num?)?.toInt(),
      txCount: (json['txCount'] as num?)?.toInt(),
      isLatestTxBlockHeightZero:
          json['isLatestTxBlockHeightZero'] as bool? ?? false,
    )..walletType = $enumDecode(_$WalletTypeEnumMap, json['walletType']);

Map<String, dynamic> _$MultisigWalletListItemToJson(
        MultisigWalletListItem instance) =>
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
      'signers': instance.signers,
      'requiredSignatureCount': instance.requiredSignatureCount,
    };

const _$WalletTypeEnumMap = {
  WalletType.singleSignature: 'singleSignature',
  WalletType.multiSignature: 'multiSignature',
};
