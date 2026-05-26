class TaprootScriptPathConfig {
  final int requiredSignature;
  final int leafCount;
  final int tapScriptSize;

  const TaprootScriptPathConfig({
    required this.requiredSignature,
    required this.leafCount,
    required this.tapScriptSize,
  });
}
