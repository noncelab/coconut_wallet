import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/services/realm_debug_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Realm 데이터베이스 디버그 화면의 뷰모델
///
/// 상태 관리와 비즈니스 로직을 담당하는 클래스
class RealmDebugViewModel extends ChangeNotifier {
  final RealmDebugService _realmDebugService;

  // 상태 변수들
  String _selectedTable = 'RealmWalletBase';
  List<Map<String, dynamic>> _queryResults = [];
  String _errorMessage = '';
  bool _isLoading = false;
  final Set<String> _modifiedTransactionIds = {};

  // 정렬 옵션
  String _selectedSortField = '';
  bool _sortDescending = true;
  bool _enableSort = false;

  // Getters
  String get selectedTable => _selectedTable;
  List<Map<String, dynamic>> get queryResults => _queryResults;
  String get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  Set<String> get modifiedTransactionIds => _modifiedTransactionIds;
  String get selectedSortField => _selectedSortField;
  bool get sortDescending => _sortDescending;
  bool get enableSort => _enableSort;

  List<String> get availableTables => RealmDebugService.availableTables;

  RealmDebugViewModel(RealmManager realmManager)
      : _realmDebugService = RealmDebugService(realmManager: realmManager);

  /// 선택된 테이블 변경
  Future<void> changeSelectedTable(String tableName) async {
    _selectedTable = tableName;
    // 정렬 옵션 초기화
    _enableSort = false;
    _selectedSortField = '';
    _sortDescending = true;
    notifyListeners();

    // 전체 데이터 로드 (비동기로 처리)
    await executeQuery('TRUEPREDICATE');
  }

  /// 정렬 활성화/비활성화
  void toggleSortEnabled(bool enabled) {
    _enableSort = enabled;
    if (enabled && _selectedSortField.isEmpty) {
      final sortableFields = getSortableFields();
      if (sortableFields.isNotEmpty) {
        _selectedSortField = sortableFields.first;
      }
    }
    notifyListeners();
  }

  /// 정렬 필드 변경
  void changeSortField(String field) {
    _selectedSortField = field;
    notifyListeners();
  }

  /// 정렬 방향 변경
  void changeSortDirection(bool descending) {
    _sortDescending = descending;
    notifyListeners();
  }

  /// 최종 쿼리 빌드 (정렬 옵션 포함)
  String buildFinalQuery(String baseQuery) {
    String query = baseQuery.trim();
    if (query.isEmpty) {
      query = 'TRUEPREDICATE';
    }

    if (_enableSort && _selectedSortField.isNotEmpty) {
      final sortDirection = _sortDescending ? 'DESC' : 'ASC';
      query += ' SORT($_selectedSortField $sortDirection)';
    }

    return query;
  }

  /// 쿼리 실행
  Future<void> executeQuery(String query) async {
    _setLoading(true);
    _clearError();

    try {
      // UI 응답성을 위해 작은 지연 추가
      await Future.delayed(const Duration(milliseconds: 50));

      final finalQuery = buildFinalQuery(query);
      final results = _realmDebugService.executeQuery(_selectedTable, finalQuery);

      _queryResults = results;
      _setLoading(false);
    } catch (e) {
      _setError('쿼리 실행 오류: $e');
      _setLoading(false);
    }
  }

  /// 동적 쿼리 예제 가져오기
  List<String> getQueryExamples() {
    return _realmDebugService.getDynamicQueryExamples(_selectedTable);
  }

  /// 정렬 가능한 필드 목록 가져오기
  List<String> getSortableFields() {
    return _realmDebugService.getSortableFields(_selectedTable);
  }

  /// 테이블 통계 정보 가져오기
  Map<String, int> getTableStatistics() {
    return _realmDebugService.getTableStatistics();
  }

  /// JSON으로 내보내기
  void exportToJson() {
    if (_queryResults.isEmpty) {
      throw Exception('내보낼 데이터가 없습니다');
    }

    final query = _enableSort && _selectedSortField.isNotEmpty
        ? buildFinalQuery('TRUEPREDICATE')
        : 'TRUEPREDICATE';

    final jsonString = _realmDebugService.exportToJson(_selectedTable, query, _queryResults);

    Clipboard.setData(ClipboardData(text: jsonString));
  }

  /// 트랜잭션 데이터 비우기 (기본값으로 초기화)
  Future<void> clearTransactionData(Map<String, dynamic> transactionData) async {
    try {
      final clearedData = _createClearedTransactionData(transactionData);
      await _realmDebugService.updateTransactionData(clearedData);

      // 수정된 트랜잭션 ID 추적
      _modifiedTransactionIds.add(transactionData['id'].toString());
      notifyListeners();

      // 결과 다시 로드
      executeQuery(buildFinalQuery('TRUEPREDICATE'));
    } catch (e) {
      throw Exception('데이터 비우기 실패: $e');
    }
  }

  /// 비워진 트랜잭션 데이터 생성
  Map<String, dynamic> _createClearedTransactionData(Map<String, dynamic> originalData) {
    final now = DateTime.now();

    return {
      // 기본키는 유지
      'id': originalData['id'],
      'transactionHash': originalData['transactionHash'],
      'walletId': originalData['walletId'],

      // 문자열 필드는 빈 문자열
      'replaceByTransactionHash': null,

      // 숫자 필드는 1
      'blockHeight': 1,
      'amount': 1,
      'fee': 1,
      'vSize': 1.0,

      // 날짜 필드는 현재 시간
      'timestamp': now,
      'createdAt': now,

      // 리스트 필드는 빈 리스트
      'inputAddressList': <String>[],
      'outputAddressList': <String>[],
    };
  }

  /// 수정된 트랜잭션인지 확인
  bool isModifiedTransaction(Map<String, dynamic> transactionData) {
    return _modifiedTransactionIds.contains(transactionData['id']?.toString());
  }

  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _queryResults.clear();
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}
