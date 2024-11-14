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
    )..walletType = $enumDecode(_$WalletTypeEnumMap, json['walletType']);

Map<String, dynamic> _$MultisigWalletListItemToJson(
        MultisigWalletListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'colorIndex': instance.colorIndex,
      'iconIndex': instance.iconIndex,
      'descriptor': instance.descriptor,
      'walletType': _$WalletTypeEnumMap[instance.walletType]!,
      'balance': instance.balance,
      'signers': instance.signers,
      'requiredSignatureCount': instance.requiredSignatureCount,
    };

const _$WalletTypeEnumMap = {
  WalletType.singleSignature: 'singleSignature',
  WalletType.multiSignature: 'multiSignature',
};
