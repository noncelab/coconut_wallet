// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'multisig_signer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MultisigSigner _$MultisigSignerFromJson(Map<String, dynamic> json) =>
    MultisigSigner(
      name: json['name'] as String?,
      iconIndex: (json['iconIndex'] as num?)?.toInt(),
      colorIndex: (json['colorIndex'] as num?)?.toInt(),
      memo: json['memo'] as String?,
    );

Map<String, dynamic> _$MultisigSignerToJson(MultisigSigner instance) =>
    <String, dynamic>{
      'name': instance.name,
      'iconIndex': instance.iconIndex,
      'colorIndex': instance.colorIndex,
      'memo': instance.memo,
    };
