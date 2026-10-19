/// Floresta 노드의 체인 동기화 상태.
///
/// JSON-RPC `getblockchaininfo` 결과를 감싼 것으로, UI에서
/// 헤더 높이 / 검증 진행도 / IBD 여부를 표시하는 데 사용한다.
/// (Electrum 프로토콜에는 이 정보가 없어 Floresta 전용 RPC로만 얻을 수 있다.)
class FlorestaSyncInfo {
  /// most-work fully-validated chain 높이. IBD 중에는 [headers]보다 작다.
  final int blocks;

  /// 검증된 헤더 수. IBD 완료 후 [blocks]와 같아진다.
  final int headers;

  /// 검증 진행도 (0.0 ~ 1.0).
  final double verificationProgress;

  /// Initial Block Download 진행 중 여부.
  final bool initialBlockDownload;

  /// best(most-work) 블록 해시.
  final String? bestBlockHash;

  /// 최신 블록의 UNIX 타임스탬프.
  final int? time;

  const FlorestaSyncInfo({
    required this.blocks,
    required this.headers,
    required this.verificationProgress,
    required this.initialBlockDownload,
    this.bestBlockHash,
    this.time,
  });

  /// RPC `getblockchaininfo` 결과를 파싱합니다.
  ///
  /// Floresta 버전에 따라 필드명이 다르다:
  /// - 최신: `blocks`, `headers`, `verificationprogress`, `initialblockdownload`
  /// - 구버전(v0.9.x): `height`, `validated`, `progress`, `ibd`
  factory FlorestaSyncInfo.fromRpc(Map<String, dynamic> json) {
    num? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is num) return v;
      }
      return null;
    }

    final blocks = pick(['blocks', 'validated', 'height'])?.toInt() ?? 0;
    final headers = pick(['headers', 'height', 'validated'])?.toInt() ?? 0;
    final progress = pick(['verificationprogress', 'progress'])?.toDouble() ?? 0.0;
    final ibd = (json['initialblockdownload'] ?? json['ibd']) as bool? ?? false;

    return FlorestaSyncInfo(
      blocks: blocks,
      headers: headers < blocks ? blocks : headers,
      verificationProgress: progress,
      initialBlockDownload: ibd,
      bestBlockHash: (json['bestblockhash'] ?? json['best_block']) as String?,
      time: pick(['time', 'latest_block_time'])?.toInt(),
    );
  }

  /// 헤더를 모두 검증했고 IBD도 끝난 상태.
  bool get isSynced => !initialBlockDownload && headers > 0 && blocks >= headers;
}
