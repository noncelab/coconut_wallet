import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:json_annotation/json_annotation.dart';

part 'multisig_wallet_list_item.g.dart'; // 생성될 파일 이름 $ dart run build_runner build

@JsonSerializable(ignoreUnannotated: true)
class MultisigWalletListItem extends WalletListItemBase {
  MultisigWalletListItem(
      {required super.id,
      required super.name,
      required super.colorIndex,
      required super.iconIndex,
      required super.descriptor,
      required this.signers,
      required this.requiredSignatureCount,
      super.balance,
      super.txCount,
      super.isLatestTxBlockHeightZero})
      : super(walletType: WalletType.multiSignature) {
    walletBase = MultisignatureWallet.fromDescriptor(descriptor);
    name = name.replaceAll('\n', ' ');
  }

  @JsonKey(name: "signers")
  late List<MultisigSigner> signers;

  @JsonKey(name: "requiredSignatureCount")
  late final int requiredSignatureCount;

  Map<String, dynamic> toJson() => _$MultisigWalletListItemToJson(this);

  factory MultisigWalletListItem.fromJson(Map<String, dynamic> json) {
    json['walletType'] = _$WalletTypeEnumMap[WalletType.multiSignature];
    return _$MultisigWalletListItemFromJson(json);
  }
}
