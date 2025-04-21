/// 스크립트 키를 생성합니다.
///
/// [walletId] 지갑 ID
/// [derivationPath] 스크립트 경로
///
/// 반환값: 스크립트 키 (형식: '지갑ID:derivationPath')
String getScriptKey(int walletId, String derivationPath) {
  return '$walletId:$derivationPath';
}

/// 트랜잭션 해시 키를 생성합니다.
///
/// [walletId] 지갑 ID
/// [txHash] 트랜잭션 해시
///
/// 반환값: 트랜잭션 해시 키 (형식: '지갑ID:트랜잭션해시')
String getTxHashKey(int walletId, String txHash) {
  return '$walletId:$txHash';
}
