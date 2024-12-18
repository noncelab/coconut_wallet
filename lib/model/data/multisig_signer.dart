import 'dart:core';

import 'package:json_annotation/json_annotation.dart';

part 'multisig_signer.g.dart'; // 생성될 파일 이름 $ dart run build_runner build

@JsonSerializable(ignoreUnannotated: true)
class MultisigSigner {
  @JsonKey()
  int? innerVaultId; // 내부 지갑이 Key로 사용된 경우 앱 내 id
  @JsonKey()
  String? name;
  @JsonKey()
  int? iconIndex;
  @JsonKey()
  int? colorIndex;
  @JsonKey()
  String? memo;

  MultisigSigner({
    this.name,
    this.iconIndex,
    this.colorIndex,
    this.memo,
  }) {
    name = name?.replaceAll('\n', ' ');
  }

  Map<String, dynamic> toJson() => _$MultisigSignerToJson(this);

  factory MultisigSigner.fromJson(Map<String, dynamic> json) =>
      _$MultisigSignerFromJson(json);
}
