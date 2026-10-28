import 'package:coconut_lib/coconut_lib.dart';

/// 미서명 PSBT에서 사용자에게 보여줄 요약 정보(보낼 금액, 수수료, 수신 주소)를 추출한다.
/// 하드웨어 월렛(BitBox02, Trezor) 서명 화면에서 PSBT 문자열만으로 요약을 표시할 때 사용한다.
class UnsignedPsbtSummary {
  final int amount;
  final int fee;
  final List<String> recipientAddresses;

  int get totalCost => amount + fee;

  const UnsignedPsbtSummary({required this.amount, required this.fee, required this.recipientAddresses});

  factory UnsignedPsbtSummary.parse({required String psbtBase64, required WalletBase wallet}) {
    final psbt = Psbt.parse(psbtBase64);
    final recipientOutputs = psbt.outputs.where((output) => !output.isChange(wallet)).toList();

    return UnsignedPsbtSummary(
      amount: recipientOutputs.fold<int>(0, (sum, output) => sum + (output.outAmount ?? 0)),
      fee: psbt.fee,
      recipientAddresses: recipientOutputs.map((output) => output.outAddress).whereType<String>().toList(),
    );
  }

  /// [parse]와 동일하지만 파싱 중 예외 발생 시 `null`을 반환한다.
  static UnsignedPsbtSummary? tryParse({required String psbtBase64, required WalletBase wallet}) {
    try {
      return UnsignedPsbtSummary.parse(psbtBase64: psbtBase64, wallet: wallet);
    } catch (_) {
      return null;
    }
  }
}
