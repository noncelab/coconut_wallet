import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/multisig_signer.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'multisig_wallet_list_item.g.dart'; // 생성될 파일 이름 $ dart run build_runner build

@JsonSerializable(ignoreUnannotated: true)
class MultisigWalletListItem extends WalletListItemBase {
  MultisigWalletListItem({
    required super.id,
    required super.name,
    required super.colorIndex,
    required super.iconIndex,
    required super.descriptor,
    required this.signers,
    required this.requiredSignatureCount,
    super.balance,
  }) : super(walletType: WalletType.multiSignature) {
    walletBase = MultisignatureWallet.fromKeyStoreList(
      requiredSignatureCount,
      AddressType.p2wsh,
      '',
      signers.map((signer) => signer.keyStore).toList(),
    );
  }

  @JsonKey(name: "signers")
  late final List<MultisigSigner> signers;

  // json_serialization가 기본 생성자를 사용해서 추가함
  @JsonKey(name: "requiredSignatureCount")
  late final int requiredSignatureCount;

  Map<String, dynamic> toJson() => _$MultisigWalletListItemToJson(this);

  factory MultisigWalletListItem.fromJson(Map<String, dynamic> json) {
    json['walletType'] = _$WalletTypeEnumMap[WalletType.multiSignature];
    return _$MultisigWalletListItemFromJson(json);
  }
}
