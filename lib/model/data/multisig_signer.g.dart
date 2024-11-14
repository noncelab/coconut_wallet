// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'multisig_signer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MultisigSigner _$MultisigSignerFromJson(Map<String, dynamic> json) =>
    MultisigSigner(
      id: (json['id'] as num).toInt(),
      signerBsms: json['signerBsms'] as String,
      innerVaultId: (json['innerVaultId'] as num?)?.toInt(),
      memo: json['memo'] as String?,
    );

Map<String, dynamic> _$MultisigSignerToJson(MultisigSigner instance) =>
    <String, dynamic>{
      'id': instance.id,
      'signerBsms': instance.signerBsms,
      'innerVaultId': instance.innerVaultId,
      'memo': instance.memo,
    };
