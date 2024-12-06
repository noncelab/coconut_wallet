import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable(ignoreUnannotated: true)
abstract class WalletListItemBase {
  @JsonKey(name: "id")
  final int id;
  @JsonKey(name: "colorIndex")
  final int colorIndex;
  @JsonKey(name: "iconIndex")
  final int iconIndex;
  @JsonKey(name: "descriptor")
  final String descriptor;
  @JsonKey(name: "name")
  String name;
  @JsonKey(name: "walletType")
  WalletType walletType;
  @JsonKey(name: "balance")
  int? balance;

  late WalletBase walletBase;

  WalletListItemBase({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.iconIndex,
    required this.descriptor,
    required this.walletType,
    this.balance,
  });

  @override
  String toString() =>
      'Wallet($id) / type=$walletType / name=$name / balance=$balance';
}
