import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/enums/wallet_enums.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:coconut_lib/coconut_lib.dart';

part 'singlesig_wallet_list_item.g.dart'; // 생성될 파일 이름 $ dart run build_runner build

@JsonSerializable(ignoreUnannotated: true)
class SinglesigWalletListItem extends WalletListItemBase {
  SinglesigWalletListItem(
      {required super.id,
      required super.name,
      required super.colorIndex,
      required super.iconIndex,
      required super.descriptor,
      super.balance,
      super.txCount,
      super.isLatestTxBlockHeightZero})
      : super(
          walletType: WalletType.singleSignature,
        ) {
    walletBase = SingleSignatureWallet.fromDescriptor(descriptor);
    name = name.replaceAll('\n', ' ');
  }

  Map<String, dynamic> toJson() => _$SinglesigWalletListItemToJson(this);

  factory SinglesigWalletListItem.fromJson(Map<String, dynamic> json) {
    json['walletType'] = _$WalletTypeEnumMap[WalletType.singleSignature];
    return _$SinglesigWalletListItemFromJson(json);
  }
}
