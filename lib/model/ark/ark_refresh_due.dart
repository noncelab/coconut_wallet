/// VTXO 만료 상태, 마지막 동기화와 현재 블록 높이 기준
class ArkRefreshDue {
  const ArkRefreshDue({required this.vtxoIds, required this.firstExpiryHeight, required this.tipHeight});

  static const none = ArkRefreshDue(vtxoIds: [], firstExpiryHeight: null, tipHeight: null);

  /// 만료 알림 시작, 메인넷 약 7일 전
  static const noticeBlocks = 1008;

  /// 알림 구간에 들어온 VTXO
  final List<String> vtxoIds;

  /// 가장 먼저 만료되는 VTXO의 만료 블록 높이
  final int? firstExpiryHeight;
  final int? tipHeight;

  bool get isDue => vtxoIds.isNotEmpty;

  int? get blocksLeft {
    final expiry = firstExpiryHeight;
    final tip = tipHeight;
    if (expiry == null || tip == null) return null;
    return expiry - tip;
  }

  bool get isExpired => (blocksLeft ?? 1) <= 0;
}
