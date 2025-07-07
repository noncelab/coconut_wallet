class P2wpkhFeeEstimator {
  static const double baseTxVBytes = 10.5;
  static const double inputVBytes = 68;
  static const double outputVBytes = 31.0;

  late int numInputs;
  late int numOutputs;
  late double feeRate;

  P2wpkhFeeEstimator({required this.numInputs, required this.numOutputs, required this.feeRate});

  int get estimatedFee =>
      estimateFee(numInputs: numInputs, numOutputs: numOutputs, satPerVByte: feeRate);

  void updateFeeRate(double feeRate) {
    this.feeRate = feeRate;
  }

  void updateNumInputs(int numInputs) {
    this.numInputs = numInputs;
  }

  void updateNumOutputs(int numOutputs) {
    this.numOutputs = numOutputs;
  }

  static int estimateFee({
    required int numInputs,
    required int numOutputs,
    required double satPerVByte,
  }) {
    double totalVBytes = baseTxVBytes + (numInputs * inputVBytes) + (numOutputs * outputVBytes);

    return (totalVBytes * satPerVByte).ceil();
  }
}

/// TODO: 로직 체크
class P2wshFeeEstimator {
  static const double baseTxVBytes = 11;
  static const double outputVBytes = 31;

  late int numInputs;
  late int numOutputs;
  late double feeRate;
  late final int threshold;
  late final int totalSignature;
  late final int inputVBytes;
  P2wshFeeEstimator(
      {required this.numInputs,
      required this.numOutputs,
      required this.feeRate,
      required this.threshold,
      required this.totalSignature}) {
    inputVBytes = estimateP2WSHInputVBytes(threshold, totalSignature);
  }

  int get estimatedFee => estimateFee(
      numInputs: numInputs,
      numOutputs: numOutputs,
      satPerVByte: feeRate,
      threshold: threshold,
      totalSignature: totalSignature,
      inputVBytes: inputVBytes);

  void updateFeeRate(double feeRate) {
    this.feeRate = feeRate;
  }

  void updateNumInputs(int numInputs) {
    this.numInputs = numInputs;
  }

  void updateNumOutputs(int numOutputs) {
    this.numOutputs = numOutputs;
  }

  static int estimateFee(
      {required int numInputs,
      required int numOutputs,
      required int threshold,
      required int totalSignature,
      required double satPerVByte,
      int? inputVBytes}) {
    int inputVBytes0 = inputVBytes ?? estimateP2WSHInputVBytes(threshold, totalSignature);
    double totalVBytes = baseTxVBytes + (numInputs * inputVBytes0) + (numOutputs * outputVBytes);

    return (totalVBytes * satPerVByte).ceil();
  }

  static int estimateP2WSHInputVBytes(int m, int n) {
    const int nonWitnessBytes = 41;
    const int minSignatureSize = 72;
    const int compressedPubkeySize = 33;

    // witness 구성
    int signatureBytes = m * minSignatureSize;
    int witnessScriptBytes =
        1 + (n * compressedPubkeySize) + 1 + 1; // OP_m, pubkeys, OP_n, OP_CHECKMULTISIG
    int witnessBytes = 1 + signatureBytes + witnessScriptBytes; // 1: CompactSize item count

    int totalWeight = (nonWitnessBytes * 4) + witnessBytes;
    return (totalWeight / 4).ceil();
  }
}
