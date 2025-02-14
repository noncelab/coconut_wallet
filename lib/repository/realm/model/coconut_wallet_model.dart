import 'package:realm/realm.dart';

part 'coconut_wallet_model.realm.dart'; // dart run realm generate

@RealmModel()
class _RealmWalletBase {
  @PrimaryKey()
  late int id;

  late int colorIndex;
  late int iconIndex;
  late String descriptor;
  late String name;
  late String walletType;
  int lastUsedReceiveIndex = -1;
  int lastUsedChangeIndex = -1;
  int? balance;
  int? txCount;
  bool isLatestTxBlockHeightZero = false;
}

@RealmModel()
class _RealmMultisigWallet {
  @PrimaryKey()
  late int id;
  // Realm은 N:0 관계를 지원하며, N:1 관계는 지원하지 않습니다. 따라서 1:1 관계를 설정할 수 없습니다.
  late _RealmWalletBase? walletBase;
  late String signersInJsonSerialization;
  late int requiredSignatureCount;
}

@RealmModel()
class _RealmTransaction {
  @PrimaryKey()
  late int id; // RealmIntegerId에 마지막 사용한 id 값을 저장합니다.
  late String transactionHash;
  // Realm은 N:0 관계를 지원하며, N:1 관계는 지원하지 않습니다. 따라서 1:1 관계를 설정할 수 없습니다.
  late _RealmWalletBase? walletBase;
  @Indexed()
  DateTime? timestamp;
  int? blockHeight;
  String? transactionType;
  String? memo;
  int? amount;
  int? fee;
  late List<String> inputAddressList;
  late List<String> outputAddressList;
  String? note;
  DateTime? createdAt;
}

@RealmModel()
class _RealmIntegerId {
  @PrimaryKey()
  late String key; // "RealmTransaction"처럼 테이블 이름
  late int value; // 마지막으로 사용한 id
}

@RealmModel()
class _TempBroadcastTimeRecord {
  @PrimaryKey()
  late String transactionHash;
  late DateTime createdAt;
}

@RealmModel()
class _RealmUtxoTag {
  @PrimaryKey()
  late String id; // UUID 사용
  late int walletId;
  late String name;
  late int colorIndex;
  late List<String> utxoIdList;
  late DateTime createAt;
}

@RealmModel()
class _RealmWalletAddress {
  @PrimaryKey()
  late int id;
  @Indexed()
  late String walletId;
  @Indexed()
  late String address;
  @Indexed()
  late int index;
  @Indexed()
  late bool isChange;
  late String derivationPath;
  late bool isUsed;
  late int confirmed;
  late int unconfirmed;
}

// 지갑 목록 화면이나 상세 화면에서 전체 잔액을 삐르게 갱신하고 조회하기 위해 사용
@RealmModel()
class _RealmWalletBalance {
  @PrimaryKey()
  late int id;
  @Indexed()
  late int walletId;

  late int total;
  late int confirmed;
  late int unconfirmed;
}
