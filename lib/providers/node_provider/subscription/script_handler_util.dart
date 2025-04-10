/// 스크립트 키를 생성합니다.
///
/// [walletId] 지갑 ID
/// [derivationPath] 스크립트 경로
///
/// 반환값: 스크립트 키 (형식: '지갑ID:derivationPath')
String getScriptKey(int walletId, String derivationPath) {
  return '$walletId:$derivationPath';
}

/// 주어진 스크립트 키가 특정 지갑 ID에 속하는지 확인합니다.
///
/// [scriptKey] 확인할 스크립트 키 (형식: '지갑ID:derivationPath')
/// [walletId] 확인할 지갑 ID
///
/// 반환값: 스크립트 키가 해당 지갑 ID에 속하면 true, 그렇지 않으면 false
bool isScriptKeyBelongsToWallet(String scriptKey, int walletId) {
  if (scriptKey.isEmpty) return false;

  final parts = scriptKey.split(':');
  if (parts.length < 2) return false;

  try {
    final scriptWalletId = int.parse(parts[0]);
    return scriptWalletId == walletId;
  } catch (e) {
    return false;
  }
}
