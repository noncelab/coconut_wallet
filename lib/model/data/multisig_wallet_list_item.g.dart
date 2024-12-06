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
      'signers': instance.signers,
      'requiredSignatureCount': instance.requiredSignatureCount,
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
