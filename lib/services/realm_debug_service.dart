import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:realm/realm.dart';
import 'dart:convert';

/// Realm 데이터베이스 디버그 서비스
///
/// Realm 데이터 조회, 변환, 통계 등을 담당하는 서비스 클래스
class RealmDebugService {
  final RealmManager realmManager;

  RealmDebugService({required this.realmManager});

  /// 사용 가능한 Realm 테이블 목록
  static List<String> availableTables = realmAllSchemas.map((schema) => schema.name).toList();

  /// 선택된 테이블에 따른 정렬 가능 필드 목록
  static Map<String, List<String>> sortableFields = {
    'RealmWalletBase': ['id', 'name', 'colorIndex', 'walletType', 'usedReceiveIndex'],
    'RealmTransaction': ['id', 'timestamp', 'blockHeight', 'amount', 'fee', 'vSize', 'createdAt'],
    'RealmUtxo': ['id', 'amount', 'timestamp', 'blockHeight', 'index'],
    'RealmWalletAddress': ['id', 'address', 'index', 'total', 'confirmed'],
    'RealmWalletBalance': ['id', 'total', 'confirmed', 'unconfirmed'],
    'RealmUtxoTag': ['id', 'name', 'createAt'],
    'RealmScriptStatus': ['scriptPubKey', 'timestamp'],
    'RealmBlockTimestamp': ['blockHeight', 'timestamp'],
    'RealmRbfHistory': ['id', 'timestamp', 'feeRate'],
    'RealmCpfpHistory': ['id', 'timestamp', 'originalFee', 'newFee'],
    'RealmTransactionMemo': ['id', 'createdAt'],
  };

  /// Realm 쿼리 실행
  List<Map<String, dynamic>> executeQuery(String tableName, String query) {
    if (!realmManager.isInitialized) {
      throw Exception('RealmManager가 초기화되지 않았습니다.');
    }

    final realm = realmManager.realm;
    return _queryByTableType(realm, tableName, query);
  }

  /// 테이블 타입에 따른 쿼리 실행
  List<Map<String, dynamic>> _queryByTableType(Realm realm, String tableName, String query) {
    switch (tableName) {
      case 'RealmWalletBase':
        return _convertToMapList(realm.query<RealmWalletBase>(query));
      case 'RealmMultisigWallet':
        return _convertToMapList(realm.query<RealmMultisigWallet>(query));
      case 'RealmExternalWallet':
        return _convertToMapList(realm.query<RealmExternalWallet>(query));
      case 'RealmTransaction':
        return _convertToMapList(realm.query<RealmTransaction>(query));
      case 'RealmUtxo':
        return _convertToMapList(realm.query<RealmUtxo>(query));
      case 'RealmWalletAddress':
        return _convertToMapList(realm.query<RealmWalletAddress>(query));
      case 'RealmWalletBalance':
        return _convertToMapList(realm.query<RealmWalletBalance>(query));
      case 'RealmUtxoTag':
        return _convertToMapList(realm.query<RealmUtxoTag>(query));
      case 'RealmScriptStatus':
        return _convertToMapList(realm.query<RealmScriptStatus>(query));
      case 'RealmBlockTimestamp':
        return _convertToMapList(realm.query<RealmBlockTimestamp>(query));
      case 'RealmIntegerId':
        return _convertToMapList(realm.query<RealmIntegerId>(query));
      case 'RealmRbfHistory':
        return _convertToMapList(realm.query<RealmRbfHistory>(query));
      case 'RealmCpfpHistory':
        return _convertToMapList(realm.query<RealmCpfpHistory>(query));
      case 'RealmTransactionMemo':
        return _convertToMapList(realm.query<RealmTransactionMemo>(query));
      default:
        throw ArgumentError('지원되지 않는 테이블: $tableName');
    }
  }

  /// RealmResults를 Map 리스트로 변환
  List<Map<String, dynamic>> _convertToMapList<T extends RealmObject>(RealmResults<T> results) {
    return results.map((item) => realmObjectToMap(item)).toList();
  }

  /// RealmObject를 Map으로 변환
  Map<String, dynamic> realmObjectToMap(RealmObject obj) {
    final Map<String, dynamic> map = {};

    try {
      // 각 테이블별로 알려진 속성들을 직접 처리
      if (obj is RealmWalletBase) {
        map['id'] = obj.id;
        map['colorIndex'] = obj.colorIndex;
        map['iconIndex'] = obj.iconIndex;
        map['descriptor'] = obj.descriptor;
        map['name'] = obj.name;
        map['walletType'] = obj.walletType;
        map['usedReceiveIndex'] = obj.usedReceiveIndex;
        map['usedChangeIndex'] = obj.usedChangeIndex;
        map['generatedReceiveIndex'] = obj.generatedReceiveIndex;
        map['generatedChangeIndex'] = obj.generatedChangeIndex;
      } else if (obj is RealmTransaction) {
        map['id'] = obj.id;
        map['transactionHash'] = obj.transactionHash;
        map['walletId'] = obj.walletId;
        map['timestamp'] = obj.timestamp.toIso8601String();
        map['blockHeight'] = obj.blockHeight;
        map['transactionType'] = obj.transactionType;
        map['amount'] = obj.amount;
        map['fee'] = obj.fee;
        map['vSize'] = obj.vSize;
        map['inputAddressList'] = obj.inputAddressList.toList();
        map['outputAddressList'] = obj.outputAddressList.toList();
        map['createdAt'] = obj.createdAt.toIso8601String();
        map['replaceByTransactionHash'] = obj.replaceByTransactionHash;
      } else if (obj is RealmUtxo) {
        map['id'] = obj.id;
        map['walletId'] = obj.walletId;
        map['address'] = obj.address;
        map['amount'] = obj.amount;
        map['timestamp'] = obj.timestamp.toIso8601String();
        map['transactionHash'] = obj.transactionHash;
        map['index'] = obj.index;
        map['derivationPath'] = obj.derivationPath;
        map['blockHeight'] = obj.blockHeight;
        map['status'] = obj.status;
        map['spentByTransactionHash'] = obj.spentByTransactionHash;
        map['isDeleted'] = obj.isDeleted;
      } else if (obj is RealmWalletAddress) {
        map['id'] = obj.id;
        map['walletId'] = obj.walletId;
        map['address'] = obj.address;
        map['index'] = obj.index;
        map['isChange'] = obj.isChange;
        map['derivationPath'] = obj.derivationPath;
        map['isUsed'] = obj.isUsed;
        map['confirmed'] = obj.confirmed;
        map['unconfirmed'] = obj.unconfirmed;
        map['total'] = obj.total;
      } else if (obj is RealmWalletBalance) {
        map['id'] = obj.id;
        map['walletId'] = obj.walletId;
        map['total'] = obj.total;
        map['confirmed'] = obj.confirmed;
        map['unconfirmed'] = obj.unconfirmed;
      } else if (obj is RealmMultisigWallet) {
        map['id'] = obj.id;
        map['walletBase'] = obj.walletBase?.name ?? 'null';
        map['signersInJsonSerialization'] = obj.signersInJsonSerialization;
        map['requiredSignatureCount'] = obj.requiredSignatureCount;
      } else if (obj is RealmExternalWallet) {
        map['id'] = obj.id;
        map['walletImportSource'] = obj.walletImportSource;
        map['walletBase'] = obj.walletBase?.name ?? 'null';
      } else if (obj is RealmUtxoTag) {
        map['id'] = obj.id;
        map['walletId'] = obj.walletId;
        map['name'] = obj.name;
        map['colorIndex'] = obj.colorIndex;
        map['utxoIdList'] = obj.utxoIdList.toList();
        map['createAt'] = obj.createAt.toIso8601String();
      } else if (obj is RealmScriptStatus) {
        map['scriptPubKey'] = obj.scriptPubKey;
        map['status'] = obj.status;
        map['walletId'] = obj.walletId;
        map['timestamp'] = obj.timestamp.toIso8601String();
      } else if (obj is RealmBlockTimestamp) {
        map['blockHeight'] = obj.blockHeight;
        map['timestamp'] = obj.timestamp.toIso8601String();
      } else if (obj is RealmIntegerId) {
        map['key'] = obj.key;
        map['value'] = obj.value;
      } else if (obj is RealmRbfHistory) {
        map['id'] = obj.id;
        map['walletId'] = obj.walletId;
        map['originalTransactionHash'] = obj.originalTransactionHash;
        map['transactionHash'] = obj.transactionHash;
        map['feeRate'] = obj.feeRate;
        map['timestamp'] = obj.timestamp.toIso8601String();
      } else if (obj is RealmCpfpHistory) {
        map['id'] = obj.id;
        map['walletId'] = obj.walletId;
        map['parentTransactionHash'] = obj.parentTransactionHash;
        map['childTransactionHash'] = obj.childTransactionHash;
        map['originalFee'] = obj.originalFee;
        map['newFee'] = obj.newFee;
        map['timestamp'] = obj.timestamp.toIso8601String();
      } else if (obj is RealmTransactionMemo) {
        map['id'] = obj.id;
        map['transactionHash'] = obj.transactionHash;
        map['walletId'] = obj.walletId;
        map['memo'] = obj.memo;
        map['createdAt'] = obj.createdAt.toIso8601String();
      } else {
        // 알 수 없는 타입인 경우 기본 처리
        map['type'] = obj.runtimeType.toString();
        map['toString'] = obj.toString();
      }
    } catch (e) {
      // 오류 발생시 기본 정보만 표시
      map['error'] = 'Failed to parse object: $e';
      map['type'] = obj.runtimeType.toString();
      map['toString'] = obj.toString();
    }

    return map;
  }

  /// 실제 데이터를 기반으로 한 동적 쿼리 예제들
  List<String> getDynamicQueryExamples(String tableName) {
    if (!realmManager.isInitialized) {
      return ['TRUEPREDICATE'];
    }

    final realm = realmManager.realm;
    List<String> examples = ['TRUEPREDICATE'];

    try {
      switch (tableName) {
        case 'RealmWalletBase':
          final wallets = realm.all<RealmWalletBase>();
          if (wallets.isNotEmpty) {
            examples.addAll([
              'id == ${wallets.first.id}',
              if (wallets.any((w) => w.name.isNotEmpty))
                'name CONTAINS "${wallets.firstWhere((w) => w.name.isNotEmpty).name}"',
              if (wallets.any((w) => w.walletType.isNotEmpty))
                'walletType == "${wallets.firstWhere((w) => w.walletType.isNotEmpty).walletType}"',
              'colorIndex >= 0',
            ]);
          }
          break;

        case 'RealmTransaction':
          final transactions = realm.all<RealmTransaction>();
          if (transactions.isNotEmpty) {
            final walletIds = transactions.map((t) => t.walletId).toSet();
            final amounts = transactions.map((t) => t.amount).toList();
            amounts.sort();

            examples.addAll([
              if (walletIds.isNotEmpty) 'walletId == ${walletIds.first}',
              if (amounts.isNotEmpty) 'amount >= ${amounts[amounts.length ~/ 2]}',
              'fee > 0',
              'blockHeight > 0',
              'transactionType CONTAINS "receive"',
              'transactionType CONTAINS "send"',
            ]);
          }
          break;

        case 'RealmUtxo':
          final utxos = realm.all<RealmUtxo>();
          if (utxos.isNotEmpty) {
            final walletIds = utxos.map((u) => u.walletId).toSet();
            final amounts = utxos.map((u) => u.amount).toList();
            amounts.sort();

            examples.addAll([
              if (walletIds.isNotEmpty) 'walletId == ${walletIds.first}',
              'status == "unspent"',
              'status == "spent"',
              if (amounts.isNotEmpty) 'amount >= ${amounts[amounts.length ~/ 2]}',
              'isDeleted == false',
              'blockHeight > 0',
            ]);
          }
          break;

        case 'RealmWalletAddress':
          final addresses = realm.all<RealmWalletAddress>();
          if (addresses.isNotEmpty) {
            final walletIds = addresses.map((a) => a.walletId).toSet();

            examples.addAll([
              if (walletIds.isNotEmpty) 'walletId == ${walletIds.first}',
              'isChange == false',
              'isChange == true',
              'isUsed == true',
              'isUsed == false',
              'total > 0',
            ]);
          }
          break;

        case 'RealmWalletBalance':
          final balances = realm.all<RealmWalletBalance>();
          if (balances.isNotEmpty) {
            final walletIds = balances.map((b) => b.walletId).toSet();

            examples.addAll([
              if (walletIds.isNotEmpty) 'walletId == ${walletIds.first}',
              'total > 0',
              'confirmed > 0',
              'unconfirmed > 0',
            ]);
          }
          break;

        default:
          // 기타 테이블들은 기본 예시 사용
          break;
      }
    } catch (e) {
      // 오류 발생시 기본 예시만 반환
      print('동적 예시 생성 오류: $e');
    }

    return examples;
  }

  /// 테이블 통계 정보 조회
  Map<String, int> getTableStatistics() {
    if (!realmManager.isInitialized) return {};

    final realm = realmManager.realm;
    return {
      'RealmWalletBase': realm.all<RealmWalletBase>().length,
      'RealmMultisigWallet': realm.all<RealmMultisigWallet>().length,
      'RealmExternalWallet': realm.all<RealmExternalWallet>().length,
      'RealmTransaction': realm.all<RealmTransaction>().length,
      'RealmUtxo': realm.all<RealmUtxo>().length,
      'RealmWalletAddress': realm.all<RealmWalletAddress>().length,
      'RealmWalletBalance': realm.all<RealmWalletBalance>().length,
      'RealmUtxoTag': realm.all<RealmUtxoTag>().length,
      'RealmScriptStatus': realm.all<RealmScriptStatus>().length,
      'RealmBlockTimestamp': realm.all<RealmBlockTimestamp>().length,
      'RealmIntegerId': realm.all<RealmIntegerId>().length,
      'RealmRbfHistory': realm.all<RealmRbfHistory>().length,
      'RealmCpfpHistory': realm.all<RealmCpfpHistory>().length,
      'RealmTransactionMemo': realm.all<RealmTransactionMemo>().length,
    };
  }

  /// 트랜잭션 데이터 업데이트
  Future<void> updateTransactionData(Map<String, dynamic> updatedData) async {
    if (!realmManager.isInitialized) {
      throw Exception('RealmManager가 초기화되지 않았습니다.');
    }

    final realm = realmManager.realm;

    realm.write(() {
      final transaction = realm.find<RealmTransaction>(updatedData['id']);
      if (transaction != null) {
        // 기본 필드 업데이트
        transaction.walletId = updatedData['walletId'];
        transaction.timestamp = updatedData['timestamp'];
        transaction.blockHeight = updatedData['blockHeight'];
        transaction.amount = updatedData['amount'];
        transaction.fee = updatedData['fee'];
        transaction.vSize = updatedData['vSize'];
        transaction.createdAt = updatedData['createdAt'];
        transaction.replaceByTransactionHash = updatedData['replaceByTransactionHash'];

        // 리스트 필드 업데이트
        transaction.inputAddressList.clear();
        transaction.inputAddressList.addAll(updatedData['inputAddressList']);
        transaction.outputAddressList.clear();
        transaction.outputAddressList.addAll(updatedData['outputAddressList']);
      } else {
        throw Exception('트랜잭션을 찾을 수 없습니다. ID: ${updatedData['id']}');
      }
    });
  }

  /// 쿼리 결과를 JSON으로 변환
  String exportToJson(String tableName, String query, List<Map<String, dynamic>> results) {
    final jsonData = {
      'table': tableName,
      'query': query,
      'count': results.length,
      'exportTime': DateTime.now().toIso8601String(),
      'data': results,
    };

    return const JsonEncoder.withIndent('  ').convert(jsonData);
  }

  /// 선택된 테이블에 따른 정렬 가능 필드 목록 반환
  List<String> getSortableFields(String tableName) {
    return sortableFields[tableName] ?? ['id'];
  }
}
