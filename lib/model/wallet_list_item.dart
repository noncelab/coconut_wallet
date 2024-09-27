import 'dart:core';

import 'package:json_annotation/json_annotation.dart';
import 'package:coconut_wallet/model/wallet_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coconut_lib/coconut_lib.dart' as coconut;

part 'wallet_list_item.g.dart'; // 생성될 파일 이름 $ dart run build_runner build

@JsonSerializable(ignoreUnannotated: true)
class WalletListItem {
  WalletListItem(
      {required this.id,
      required this.name,
      required this.colorIndex,
      required this.iconIndex,
      required this.descriptor,
      this.balance,
      this.txCount}) {
    coconutWallet = coconut.SingleSignatureWallet.fromDescriptor(descriptor);
  }

  @JsonKey(name: "id")
  final int id;
  @JsonKey(name: "name")
  final String name;
  @JsonKey(name: "colorIndex")
  final int colorIndex;
  @JsonKey(name: "iconIndex")
  final int iconIndex;
  @JsonKey(name: "descriptor")
  final String descriptor;
  late coconut.SingleSignatureWallet coconutWallet;
  @JsonKey(name: "balance")
  int? balance;
  @JsonKey(name: "txCount")
  int? txCount; // _nodeConnector.fetch 결과에서 txCount가 변경되지 않았는지 확인용
  @JsonKey(name: "isLatestTxBlockHeightZero")
  bool isLatestTxBlockHeightZero =
      false; // _nodeConnector.fetch 결과에서 latestTxBlockHeight가 변경되지 않았는지 확인용
  // TODO: 현재 coconut_lib getAddressList 결과에 오류가 있어 대신 사용합니다. (라이브러리 버그 픽싱 후 삭제)
  @JsonKey(name: "addressBalanceMap")
  Map<int, Map<int, int>>? addressBalanceMap;
  // TODO: 현재 coconut_lib getAddressList 결과에 오류가 있어 대신 사용합니다. (라이브러리 버그 픽싱 후 삭제)
  @JsonKey(name: "usedIndexList")
  Map<int, List<int>>? usedIndexList;

  static Future<int> _loadNextId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('nextId') ?? 1;
  }

  static Future<void> _saveNextId(int nextId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nextId', nextId);
  }

  static Future<WalletListItem> create(
      {required WalletSync walletSyncObject}) async {
    final nextId = await _loadNextId();

    var WalletSync(:name, :colorIndex, :iconIndex, :descriptor) =
        walletSyncObject;

    final newItem = WalletListItem(
        id: nextId,
        name: name,
        colorIndex: colorIndex,
        iconIndex: iconIndex,
        descriptor: descriptor);

    await _saveNextId(nextId + 1); // 다음 일련번호 저장
    return newItem;
  }

  @override
  String toString() => 'Wallet($id) / name=$name / balance=$balance';

  factory WalletListItem.fromJson(Map<String, dynamic> json) =>
      _$WalletListItemFromJson(json);

  Map<String, dynamic> toJson() => _$WalletListItemToJson(this);
}
