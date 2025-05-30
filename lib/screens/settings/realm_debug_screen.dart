import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:realm/realm.dart';
import 'dart:convert';

/// Realm 데이터베이스 디버그 화면
///
/// 개발 과정에서 Realm 데이터를 동적으로 조회하고 관리할 수 있는 화면입니다.
/// SQL 쿼리와 유사한 방식으로 Realm 데이터를 조회할 수 있습니다.
class RealmDebugScreen extends StatefulWidget {
  final RealmManager realmManager;

  const RealmDebugScreen({
    super.key,
    required this.realmManager,
  });

  @override
  State<RealmDebugScreen> createState() => _RealmDebugScreenState();
}

class _RealmDebugScreenState extends State<RealmDebugScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedTable = 'RealmWalletBase';
  List<Map<String, dynamic>> _queryResults = [];
  String _errorMessage = '';
  bool _isLoading = false;

  /// 사용 가능한 Realm 테이블 목록
  final List<String> _availableTables = [
    'RealmWalletBase',
    'RealmMultisigWallet',
    'RealmExternalWallet',
    'RealmTransaction',
    'RealmUtxo',
    'RealmWalletAddress',
    'RealmWalletBalance',
    'RealmUtxoTag',
    'RealmScriptStatus',
    'RealmBlockTimestamp',
    'RealmIntegerId',
    'TempBroadcastTimeRecord',
    'RealmRbfHistory',
    'RealmCpfpHistory',
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 선택된 테이블의 모든 데이터를 로드
  void _loadAllData() {
    _executeQuery('TRUEPREDICATE');
  }

  /// Realm 쿼리 실행
  void _executeQuery(String query) {
    if (!widget.realmManager.isInitialized) {
      setState(() {
        _errorMessage = 'RealmManager가 초기화되지 않았습니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _queryResults.clear();
    });

    try {
      final realm = widget.realmManager.realm;
      final results = _queryByTableType(realm, _selectedTable, query);

      setState(() {
        _queryResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '쿼리 실행 오류: $e';
        _isLoading = false;
      });
    }
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
      case 'TempBroadcastTimeRecord':
        return _convertToMapList(realm.query<TempBroadcastTimeRecord>(query));
      case 'RealmRbfHistory':
        return _convertToMapList(realm.query<RealmRbfHistory>(query));
      case 'RealmCpfpHistory':
        return _convertToMapList(realm.query<RealmCpfpHistory>(query));
      default:
        throw ArgumentError('지원되지 않는 테이블: $tableName');
    }
  }

  /// RealmResults를 Map 리스트로 변환
  List<Map<String, dynamic>> _convertToMapList<T extends RealmObject>(RealmResults<T> results) {
    return results.map((item) => _realmObjectToMap(item)).toList();
  }

  /// RealmObject를 Map으로 변환
  Map<String, dynamic> _realmObjectToMap(RealmObject obj) {
    final Map<String, dynamic> map = {};

    // Realm 20.x에서는 dynamic property 접근 방식이 변경됨
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
        map['memo'] = obj.memo;
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
      } else if (obj is TempBroadcastTimeRecord) {
        map['transactionHash'] = obj.transactionHash;
        map['createdAt'] = obj.createdAt.toIso8601String();
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

  /// 미리 정의된 쿼리 예제들
  List<String> _getQueryExamples() {
    switch (_selectedTable) {
      case 'RealmWalletBase':
        return [
          'TRUEPREDICATE',
          'name CONTAINS "Test"',
          'id > 0',
          'walletType == "single"',
        ];
      case 'RealmTransaction':
        return [
          'TRUEPREDICATE',
          'walletId == 1',
          'amount > 1000',
          'timestamp >= \$0', // 날짜 파라미터 예제
        ];
      case 'RealmUtxo':
        return [
          'TRUEPREDICATE',
          'walletId == 1',
          'status == "unspent"',
          'amount > 5000',
          'isDeleted == false',
        ];
      default:
        return ['TRUEPREDICATE'];
    }
  }

  /// 쿼리 결과를 JSON으로 내보내기
  void _exportToJson() {
    if (_queryResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내보낼 데이터가 없습니다')),
      );
      return;
    }

    final jsonData = {
      'table': _selectedTable,
      'query': _queryController.text.isEmpty ? 'TRUEPREDICATE' : _queryController.text,
      'count': _queryResults.length,
      'exportTime': DateTime.now().toIso8601String(),
      'data': _queryResults,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

    Clipboard.setData(ClipboardData(text: jsonString));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('JSON 데이터가 클립보드에 복사되었습니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 테이블 통계 정보 조회
  Map<String, int> _getTableStatistics() {
    if (!widget.realmManager.isInitialized) return {};

    final realm = widget.realmManager.realm;
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
      'TempBroadcastTimeRecord': realm.all<TempBroadcastTimeRecord>().length,
      'RealmRbfHistory': realm.all<RealmRbfHistory>().length,
      'RealmCpfpHistory': realm.all<RealmCpfpHistory>().length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realm 데이터베이스 디버거'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 테이블 선택 및 쿼리 입력 영역
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 테이블 선택
                Row(
                  children: [
                    const Text('테이블: '),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedTable,
                        isExpanded: true,
                        items: _availableTables.map((table) {
                          return DropdownMenuItem(
                            value: table,
                            child: Text(table),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedTable = value;
                              _queryController.text = 'TRUEPREDICATE';
                            });
                            _loadAllData();
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 쿼리 입력
                TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    labelText: 'Realm 쿼리 (NSPredicate 형식)',
                    hintText: '예: id > 0, name CONTAINS "test"',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 8),

                // 쿼리 예제 버튼들
                Wrap(
                  spacing: 8,
                  children: _getQueryExamples().map((example) {
                    return ActionChip(
                      label: Text(example),
                      onPressed: () {
                        _queryController.text = example;
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // 실행 버튼
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              _executeQuery(_queryController.text.trim().isEmpty
                                  ? 'TRUEPREDICATE'
                                  : _queryController.text);
                            },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('쿼리 실행'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _loadAllData(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('전체 조회'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _queryResults.isEmpty ? null : _exportToJson,
                      icon: const Icon(Icons.download),
                      label: const Text('JSON 내보내기'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 테이블 통계 정보
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '테이블 통계',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: _getTableStatistics().entries.map((entry) {
                          return Text(
                            '${entry.key}: ${entry.value}개',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Text('결과: ${_queryResults.length}개'),
                    const Spacer(),
                    if (_queryResults.isNotEmpty)
                      Text(
                        '선택된 테이블: $_selectedTable',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 결과 영역
            _buildResultsArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsArea() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_queryResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text('조회 결과가 없습니다.'),
        ),
      );
    }

    // 데이터 행들을 세로로 나열
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _queryResults.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 2,
            child: ExpansionTile(
              title: Text(
                'Row ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${row.keys.first}: ${row.values.first}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: row.entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 키 (필드명)
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // 값
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: entry.value.toString()),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('클립보드에 복사되었습니다'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  entry.value.toString(),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
