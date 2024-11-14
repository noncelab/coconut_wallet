import 'dart:core';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:json_annotation/json_annotation.dart';

part 'multisig_signer.g.dart'; // 생성될 파일 이름 $ dart run build_runner build

@JsonSerializable(ignoreUnannotated: true)
class MultisigSigner {
  @JsonKey()
  int id;
  @JsonKey()
  String signerBsms; // 외부 지갑인 경우 bsms 정보
  @JsonKey()
  int? innerVaultId; // 내부 지갑이 Key로 사용된 경우 앱 내 id
  @JsonKey()
  String? memo; // 외부 지갑에 설정되는 메모

  late KeyStore keyStore;

  MultisigSigner(
      {required this.id,
      required this.signerBsms,
      this.innerVaultId,
      this.memo,
      KeyStore? keyStore}) {
    if (innerVaultId != null && keyStore == null) {
      throw ArgumentError('[MultisigSigner] innerVault has to pass keyStore');
    }
    if (keyStore == null) {
      // TODO:
      // this.keyStore = KeyStore.fromSignerBsms(signerBsms);
    }
  }

  Map<String, dynamic> toJson() => _$MultisigSignerToJson(this);

  factory MultisigSigner.fromJson(Map<String, dynamic> json) =>
      _$MultisigSignerFromJson(json);
}
