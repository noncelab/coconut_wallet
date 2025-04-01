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
  int usedReceiveIndex = -1;
  int usedChangeIndex = -1;
  int generatedReceiveIndex = -1;
  int generatedChangeIndex = -1;
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
  @Indexed()
  late String transactionHash;
  @Indexed()
  late int walletId;
  @Indexed()
  late DateTime timestamp;
  late int blockHeight;
  late String transactionType;
  String? memo;
  late int amount;
  late int fee;
  late double vSize;
  late List<String> inputAddressList;
  late List<String> outputAddressList;
  String? note;
  late DateTime createdAt;
  String? replaceByTransactionHash;
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
  late int walletId;
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
  late int total;
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

@RealmModel()
class _RealmBlockTimestamp {
  @PrimaryKey()
  late int blockHeight;
  late DateTime timestamp;
}

@RealmModel()
class _RealmScriptStatus {
  @PrimaryKey()
  late String scriptPubKey;
  late String status;
  @Indexed()
  late int walletId;
  late DateTime timestamp;
}

@RealmModel()
class _RealmUtxo {
  @PrimaryKey()
  late String id;
  @Indexed()
  late int walletId;
  @Indexed()
  late String address;
  @Indexed()
  late int amount;
  @Indexed()
  late DateTime timestamp;
  late String transactionHash;
  late int index; // 트랜잭션 내 인덱스
  late String derivationPath;
  late int blockHeight;

  /// [UtxoStatus] 참고
  @Indexed()
  late String status; // unspent, outgoing, incoming
  String? spentByTransactionHash; // 이 UTXO를 사용한 트랜잭션 해시 (RBF/CPFP에 필요)
}

@RealmModel()
class _RealmRbfHistory {
  @PrimaryKey()
  late int id;
  @Indexed()
  late int walletId;
  @Indexed()
  late String originalTransactionHash;
  @Indexed()
  late String transactionHash;
  late double feeRate;
  late DateTime timestamp;
}

@RealmModel()
class _RealmCpfpHistory {
  @PrimaryKey()
  late int id;
  @Indexed()
  late int walletId;
  @Indexed()
  late String parentTransactionHash;
  @Indexed()
  late String childTransactionHash;
  late double originalFee;
  late double newFee;
  late DateTime timestamp;
}
