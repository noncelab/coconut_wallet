import 'package:coconut_lib/coconut_lib.dart';

class HardwareWalletPsbtSummary {
  final int amount;
  final int fee;
  final List<String> recipientAddresses;

  int get totalCost => amount + fee;

  const HardwareWalletPsbtSummary({required this.amount, required this.fee, required this.recipientAddresses});

  factory HardwareWalletPsbtSummary.parse({required String psbtBase64, required WalletBase wallet}) {
    final psbt = Psbt.parse(psbtBase64);
    final recipientOutputs = psbt.outputs.where((output) => !output.isChange(wallet)).toList();

    return HardwareWalletPsbtSummary(
      amount: recipientOutputs.fold<int>(0, (sum, output) => sum + (output.outAmount ?? 0)),
      fee: psbt.fee,
      recipientAddresses: recipientOutputs.map((output) => output.outAddress).whereType<String>().toList(),
    );
  }
}
