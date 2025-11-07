import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/utils/logger.dart';
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

  /// RealmResults를 Map 리스트로 변환 (최적화)
  List<Map<String, dynamic>> _convertToMapList<T extends RealmObject>(RealmResults<T> results) {
    // 대량 데이터 처리를 위한 제한 (필요시 페이징 구현 가능)
    const int maxResults = 1000;
    final limitedResults = results.length > maxResults ? results.take(maxResults) : results;

    return limitedResults.map((item) => realmObjectToMap(item)).toList();
  }

  /// RealmObject를 Map으로 변환 (최적화)
  Map<String, dynamic> realmObjectToMap(RealmObject obj) {
    final Map<String, dynamic> map = {};

    try {
      // 각 테이블별로 알려진 속성들을 직접 처리 (최적화)

      switch (obj) {
        case RealmWalletBase wallet:
          map['id'] = wallet.id;
          map['colorIndex'] = wallet.colorIndex;
          map['iconIndex'] = wallet.iconIndex;
          map['descriptor'] = wallet.descriptor;
          map['name'] = wallet.name;
          map['walletType'] = wallet.walletType;
          map['usedReceiveIndex'] = wallet.usedReceiveIndex;
          map['usedChangeIndex'] = wallet.usedChangeIndex;
          map['generatedReceiveIndex'] = wallet.generatedReceiveIndex;
          map['generatedChangeIndex'] = wallet.generatedChangeIndex;
          break;

        case RealmTransaction tx:
          map['id'] = tx.id;
          map['transactionHash'] = tx.transactionHash;
          map['walletId'] = tx.walletId;
          map['timestamp'] = tx.timestamp.toIso8601String();
          map['blockHeight'] = tx.blockHeight;
          map['transactionType'] = tx.transactionType;
          map['amount'] = tx.amount;
          map['fee'] = tx.fee;
          map['vSize'] = tx.vSize;
          map['inputAddressList'] = tx.inputAddressList.toList();
          map['outputAddressList'] = tx.outputAddressList.toList();
          map['createdAt'] = tx.createdAt.toIso8601String();
          map['replaceByTransactionHash'] = tx.replaceByTransactionHash;
          break;

        case RealmUtxo utxo:
          map['id'] = utxo.id;
          map['walletId'] = utxo.walletId;
          map['address'] = utxo.address;
          map['amount'] = utxo.amount;
          map['timestamp'] = utxo.timestamp.toIso8601String();
          map['transactionHash'] = utxo.transactionHash;
          map['index'] = utxo.index;
          map['derivationPath'] = utxo.derivationPath;
          map['blockHeight'] = utxo.blockHeight;
          map['status'] = utxo.status;
          map['spentByTransactionHash'] = utxo.spentByTransactionHash;
          map['isDeleted'] = utxo.isDeleted;
          break;

        case RealmWalletAddress addr:
          map['id'] = addr.id;
          map['walletId'] = addr.walletId;
          map['address'] = addr.address;
          map['index'] = addr.index;
          map['isChange'] = addr.isChange;
          map['derivationPath'] = addr.derivationPath;
          map['isUsed'] = addr.isUsed;
          map['confirmed'] = addr.confirmed;
          map['unconfirmed'] = addr.unconfirmed;
          map['total'] = addr.total;
          break;

        case RealmWalletBalance balance:
          map['id'] = balance.id;
          map['walletId'] = balance.walletId;
          map['total'] = balance.total;
          map['confirmed'] = balance.confirmed;
          map['unconfirmed'] = balance.unconfirmed;
          break;

        case RealmMultisigWallet multisig:
          map['id'] = multisig.id;
          map['walletBase'] = multisig.walletBase?.name ?? 'null';
          map['signersInJsonSerialization'] = multisig.signersInJsonSerialization;
          map['requiredSignatureCount'] = multisig.requiredSignatureCount;
          break;

        case RealmExternalWallet external:
          map['id'] = external.id;
          map['walletImportSource'] = external.walletImportSource;
          map['walletBase'] = external.walletBase?.name ?? 'null';
          break;

        case RealmUtxoTag tag:
          map['id'] = tag.id;
          map['walletId'] = tag.walletId;
          map['name'] = tag.name;
          map['colorIndex'] = tag.colorIndex;
          map['utxoIdList'] = tag.utxoIdList.toList();
          map['createAt'] = tag.createAt.toIso8601String();
          break;

        case RealmScriptStatus script:
          map['scriptPubKey'] = script.scriptPubKey;
          map['status'] = script.status;
          map['walletId'] = script.walletId;
          map['timestamp'] = script.timestamp.toIso8601String();
          break;

        case RealmBlockTimestamp block:
          map['blockHeight'] = block.blockHeight;
          map['timestamp'] = block.timestamp.toIso8601String();
          break;

        case RealmIntegerId integerId:
          map['key'] = integerId.key;
          map['value'] = integerId.value;
          break;

        case RealmRbfHistory rbf:
          map['id'] = rbf.id;
          map['walletId'] = rbf.walletId;
          map['originalTransactionHash'] = rbf.originalTransactionHash;
          map['transactionHash'] = rbf.transactionHash;
          map['feeRate'] = rbf.feeRate;
          map['timestamp'] = rbf.timestamp.toIso8601String();
          break;

        case RealmCpfpHistory cpfp:
          map['id'] = cpfp.id;
          map['walletId'] = cpfp.walletId;
          map['parentTransactionHash'] = cpfp.parentTransactionHash;
          map['childTransactionHash'] = cpfp.childTransactionHash;
          map['originalFee'] = cpfp.originalFee;
          map['newFee'] = cpfp.newFee;
          map['timestamp'] = cpfp.timestamp.toIso8601String();
          break;

        case RealmTransactionMemo memo:
          map['id'] = memo.id;
          map['transactionHash'] = memo.transactionHash;
          map['walletId'] = memo.walletId;
          map['memo'] = memo.memo;
          map['createdAt'] = memo.createdAt.toIso8601String();
          break;

        default:
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
      Logger.error('동적 예시 생성 오류: $e');
    }

    return examples;
  }

  /// 테이블 통계 정보 조회
  Map<String, int> getTableStatistics() {
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
