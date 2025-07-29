import 'dart:convert';
import 'package:base32/base32.dart';

class InvalidScheme implements Exception {}

class InvalidType implements Exception {}

class InvalidPathLength implements Exception {}

class InvalidSequenceComponent implements Exception {}

class InvalidFragment implements Exception {}

class BbqrDecoder {
  // ColdCard Q1 Export Wallet Data
  /// ex: B$2J0700... (B$[encoding][dataType][total][index][payload])
  /// B$: 고정 prefix (BBQR 시작을 표시)
  /// encoding: 압축 및 인코딩 형식: 2(base32), Z(zlib+base32)
  /// dataType: 데이터 유형: J(Json), P(PSBT), A(Address), M(Multisig Info), S(Seed)
  /// total: 전체 QR 조각 수(2자리 base36 숫자)
  /// index: 현재 QR 조각의 순서(2자리 base36 숫자)
  /// payload: 압축된 base32 인코딩 데이터
  final Map<int, List<int>> _chunks = {};
  int? _expectedTotal;
  bool _isComplete = false;
  dynamic _result;

  dynamic get result => _result;
  int? get expectedTotal => _expectedTotal;
  int get receivedCount => _chunks.length;
  bool get isComplete => _isComplete;

  /// 조각을 받아서 저장. 모든 조각이 모이면 true 반환
  bool receivePart(String part) {
    if (!part.startsWith('B\$') || part.length < 9 || _isComplete) return false;

    try {
      final header = part.substring(0, 8); // B$2J0700
      final totalStr = header.substring(4, 6); // "07"
      final indexStr = header.substring(6, 8); // "00"

      final total = int.parse(totalStr, radix: 36);
      final index = int.parse(indexStr, radix: 36);

      if (total <= 0 || index < 0 || index >= total) return false;
      if (_chunks.containsKey(index)) return false;

      _expectedTotal ??= total;
      if (_expectedTotal != total) return false;

      final base32Data = part.substring(8);
      final rawBytes = base32.decode(base32Data);

      _chunks[index] = rawBytes;
      if (_chunks.length == _expectedTotal) {
        _isComplete = true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 모든 조각이 모였는지 확인
  bool checkComplete() {
    return _isComplete;
  }

  /// 조각을 합쳐서 JSON 문자열 반환 (완성된 경우에만)
  String? getCombinedJsonString() {
    if (!_isComplete) return null;

    final combinedBytes = <int>[];
    for (int i = 0; i < _expectedTotal!; i++) {
      if (!_chunks.containsKey(i)) return null;
      combinedBytes.addAll(_chunks[i]!);
    }

    try {
      return utf8.decode(combinedBytes);
    } catch (_) {
      return null;
    }
  }

  /// JSON 파싱 결과 반환 (완성된 경우에만)
  dynamic parseJson() {
    final jsonString = getCombinedJsonString();
    if (jsonString == null) return null;
    try {
      _result = json.decode(jsonString);
      return _result;
    } catch (_) {
      return null;
    }
  }

  /// 진행률 (0~1)
  double get progress {
    if (_expectedTotal == null || _expectedTotal == 0) return 0;
    return (_chunks.length / _expectedTotal!).clamp(0, 1);
  }

  /// 상태 초기화
  void reset() {
    _chunks.clear();
    _expectedTotal = null;
    _isComplete = false;
    _result = null;
  }
}
