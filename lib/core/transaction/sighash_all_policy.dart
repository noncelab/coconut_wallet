import 'package:coconut_lib/coconut_lib.dart';

/// 코코넛 지갑의 서명 도구(핫·볼트·하드웨어)는 SIGHASH_ALL로만 서명하므로 SIGHASH_ALL 서명만 받는다.
/// - ECDSA(P2WPKH·P2WSH): 서명 끝 해시 유형 바이트가 0x01
/// - Schnorr(Taproot): 기본값인 64바이트, 또는 0x01을 붙인 65바이트
///
/// 그 밖의 해시 유형은 확인되지 않은 서명으로 보고, 서명을 확인하기 전에 여기서 거른다.
/// 아이솔레이트 안에서도 쓸 수 있도록 Realm·네트워크 설정에 기대지 않는다
bool usesSighashAllOnly(TransactionInput input, ScriptPublicKey prevoutScript) {
  final witness = input.witnessList;
  bool endsWithAll(String signature) => signature.length >= 2 && signature.substring(signature.length - 2) == '01';
  if (prevoutScript.isP2wpkh()) return witness.isNotEmpty && endsWithAll(witness.first);
  if (prevoutScript.isP2wsh()) {
    // [빈 값, 서명들, 스크립트]
    return witness.length >= 3 && witness.sublist(1, witness.length - 1).every(endsWithAll);
  }
  if (prevoutScript.isP2tr()) {
    // 키 경로 [서명], 스크립트 경로 [서명들(서명하지 않은 키는 빈 값), 스크립트, 제어 블록]
    final signatures = witness.length == 1 ? witness : witness.sublist(0, witness.length < 3 ? 0 : witness.length - 2);
    return signatures.every(
      (signature) =>
          signature.isEmpty || signature.length == 128 || (signature.length == 130 && endsWithAll(signature)),
    );
  }
  return false;
}
