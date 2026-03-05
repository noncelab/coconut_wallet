import 'package:coconut_wallet/utils/hex_util.dart';

const String rawTxVersion1Field = '01000000';
const String rawTxVersion2Field = '02000000';
const String rawTxSegwitField = '0001';

bool isRawTransactionHexString(String data) {
  try {
    if (!isHexString(data)) return false;
    if (!data.startsWith(rawTxVersion1Field) && !data.startsWith(rawTxVersion2Field)) return false;
    return true;
  } catch (_) {
    return false;
  }
}

/// 지갑 타입에 따라 input 1개 추가 시 증가하는 vSize(vbytes)를 반환합니다.
///
/// - singleSignature (P2WPKH): 68 vbytes
/// - multisig (P2WSH): [p2wshMultisigInputVSize] 계산 결과
int estimateVSizePerInput({required bool isMultisig, int? requiredSignatureCount, int? totalSignerCount}) {
  if (!isMultisig) return 68;
  if (requiredSignatureCount == null || totalSignerCount == null) {
    throw ArgumentError('requiredSignatureCount and totalSignerCount are required for multisig');
  }
  return p2wshMultisigInputVSize(m: requiredSignatureCount, n: totalSignerCount);
}

/// Returns the *virtual size* (vbytes) added by **one P2WSH bare multisig input**
/// for a standard m-of-n witnessScript:
///   OP_m <33B pubkey>...<33B pubkey> OP_n OP_CHECKMULTISIG
///
/// Assumptions (standard/common):
/// - Compressed pubkeys (33 bytes)
/// - DER signature length default 73 bytes (72~73 is typical; 73 is safe)
/// - n <= 15 (standard bare multisig uses OP_1..OP_15)
///
/// This computes vSize from weight:
///   vSize = ceil((nonWitnessBytes*4 + witnessBytes) / 4)
int p2wshMultisigInputVSize({
  required int m,
  required int n,
  int signatureLength = 73, // use 72 if you want "optimistic"
  int pubKeyLength = 33, // compressed pubkey
}) {
  if (m <= 0) throw ArgumentError.value(m, 'm', 'must be >= 1');
  if (n <= 0) throw ArgumentError.value(n, 'n', 'must be >= 1');
  if (m > n) throw ArgumentError('m must be <= n');
  if (n > 15) {
    throw ArgumentError.value(
      n,
      'n',
      'standard bare multisig witnessScript uses OP_1..OP_15 (n <= 15). '
          'If you really need larger n, script encoding/size rules change.',
    );
  }

  int varIntSize(int v) {
    if (v < 0) throw ArgumentError('varInt cannot be negative');
    if (v < 0xfd) return 1;
    if (v <= 0xffff) return 3;
    if (v <= 0xffffffff) return 5;
    return 9;
  }

  // ---- non-witness part of a segwit input (fixed) ----
  // outpoint(36) + scriptSigLen(1) + scriptSig(0) + sequence(4) = 41 bytes
  const int nonWitnessBytes = 41;

  // ---- witnessScript size for standard bare multisig ----
  // OP_m (1)
  // n * (PUSHDATA(1) + pubkey(33)) => n*(1+pubKeyLength)
  // OP_n (1)
  // OP_CHECKMULTISIG (1)
  final int witnessScriptSize = 1 + n * (1 + pubKeyLength) + 1 + 1;

  // ---- witness serialization bytes ----
  // stack item count: OP_0 + m sigs + witnessScript => (m + 2) items
  int witnessBytes = 0;

  // 1) number of stack items (varint)
  witnessBytes += varIntSize(m + 2);

  // 2) OP_0 item (a.k.a. "dummy element" for CHECKMULTISIG bug)
  // length = 0 => varint(0) + 0 bytes
  witnessBytes += varIntSize(0);

  // 3) m signatures: each item is [varint(sigLen) + sig bytes]
  for (int i = 0; i < m; i++) {
    witnessBytes += varIntSize(signatureLength) + signatureLength;
  }

  // 4) witnessScript item: [varint(scriptLen) + script bytes]
  witnessBytes += varIntSize(witnessScriptSize) + witnessScriptSize;

  // ---- weight / vsize ----
  final int weight = nonWitnessBytes * 4 + witnessBytes;
  final int vSize = (weight + 3) ~/ 4; // ceil(weight/4)

  return vSize;
}
