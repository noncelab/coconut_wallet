import 'package:realm/realm.dart';

/// 스키마 수정/추가 시 검토해야 할 코드
///
/// [realmAllSchemas]
/// [services/realm_debug_service.dart]
/// [widgets/realm_debug/transaction_edit_dialog.dart] 트랜잭션 수정 시 사용되는 코드
/// [repository/realm/realm_manager.dart] reset 함수
/// [test/repository/realm/test_realm_manager.dart]

part 'coconut_wallet_model.realm.dart'; // dart run realm generate

final realmAllSchemas = [
  RealmWalletBase.schema,
  RealmMultisigWallet.schema,
  RealmExternalWallet.schema,
  RealmTransaction.schema,
  RealmIntegerId.schema,
  RealmUtxoTag.schema,
  RealmWalletAddress.schema,
  RealmWalletBalance.schema,
  RealmScriptStatus.schema,
  RealmBlockTimestamp.schema,
  RealmUtxo.schema,
  RealmRbfHistory.schema,
  RealmCpfpHistory.schema,
  RealmTransactionMemo.schema,
  RealmWalletPreferences.schema,
  RealmTransactionDraft.schema,
];

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
class _RealmExternalWallet {
  @PrimaryKey()
  late int id;
  late String walletImportSource;
  late _RealmWalletBase? walletBase;
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
  late int amount;
  late int fee;
  late double vSize;
  late List<String> inputAddressList;
  late List<String> outputAddressList;
  late DateTime createdAt;
  String? replaceByTransactionHash;
}

@RealmModel()
class _RealmTransactionMemo {
  @PrimaryKey()
  late int id;
  @Indexed()
  late String transactionHash;
  @Indexed()
  late int walletId;
  late String memo;
  late DateTime createdAt;
}

@RealmModel()
class _RealmIntegerId {
  @PrimaryKey()
  late String key; // "RealmTransaction"처럼 테이블 이름
  late int value; // 마지막으로 사용한 id
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
  late String status; // unspent, outgoing, incoming, locked
  String? spentByTransactionHash; // 이 UTXO를 사용한 트랜잭션 해시 (RBF/CPFP에 필요)

  @Indexed()
  bool isDeleted = false;
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

@RealmModel()
class _RealmWalletPreferences {
  @PrimaryKey()
  late int id;
  // UI에서 표시되는 지갑 순서를 저장
  late List<int> walletOrder;
  // 즐겨찾기된 지갑 ID 목록 (최대 5개까지 사용).
  late List<int> favoriteWalletIds;
  // 총 잔액에서 제외되는 지갑 ID 목록.
  late List<int> excludedFromTotalBalanceWalletIds;
  // UTXO 수동 선택 지갑 ID 목록
  late List<int> manualUtxoSelectionWalletIds;
}

@RealmModel()
class _RealmTransactionDraft {
  @PrimaryKey()
  late int id;
  late int walletId;
  // 각 문자열은 {"address": "...", "amount": "..."} 형태
  late List<String> recipientJsons;
  late DateTime createdAt;
  late double feeRate;
  late bool isMaxMode;
  late bool? isFeeSubtractedFromSendAmount;
  late String? bitcoinUnit;
  late List<String> selectedUtxoIds;
  late String? txWaitingForSign;
}
