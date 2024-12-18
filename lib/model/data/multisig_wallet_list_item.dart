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
    walletBase = MultisignatureWallet.fromDescriptor(descriptor);
    name = name.replaceAll('\n', ' ');
  }

  @JsonKey(name: "signers")
  late List<MultisigSigner> signers;

  @JsonKey(name: "requiredSignatureCount")
  late final int requiredSignatureCount;

  /// wallet.fetchOnChainData(nodeConnector) 또는 _nodeConnector.fetch 결과에서 txCount가 변경되지 않았는지 확인용
  @JsonKey(name: "txCount")
  int? txCount;

  @JsonKey(name: "isLatestTxBlockHeightZero")
  bool isLatestTxBlockHeightZero =
      false; // _nodeConnector.fetch 결과에서 latestTxBlockHeight가 변경되지 않았는지 확인용

  // coconut_lib 0.6.x getAddressList 결과에 오류가 있어 사용했었습니다. coconut_lib 0.7에서 버그가 고쳐져서 더이상 사용되지 않지만, 앱 호환을 위해 프로퍼티를 유지합니다.
  /// deprecated
  @JsonKey(name: "addressBalanceMap")
  Map<int, Map<int, int>>? addressBalanceMap;
  // coconut_lib 0.6.x getAddressList 결과에 오류가 있어 사용했었습니다. coconut_lib 0.7에서 버그가 고쳐져서 더이상 사용되지 않지만, 앱 호환을 위해 프로퍼티를 유지합니다.
  /// deprecated
  @JsonKey(name: "usedIndexList")
  Map<int, List<int>>? usedIndexList;

  Map<String, dynamic> toJson() => _$MultisigWalletListItemToJson(this);

  factory MultisigWalletListItem.fromJson(Map<String, dynamic> json) {
    json['walletType'] = _$WalletTypeEnumMap[WalletType.multiSignature];
    return _$MultisigWalletListItemFromJson(json);
  }
}
