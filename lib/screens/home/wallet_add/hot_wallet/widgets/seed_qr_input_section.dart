import 'package:flutter/material.dart';

class SeedQrInputSection extends StatelessWidget {
  const SeedQrInputSection.scanner({super.key, required Widget scanner})
    : scrollController = null,
      scannedResult = scanner,
      passphraseOptions = null,
      walletNameField = null;

  const SeedQrInputSection.scanned({
    super.key,
    required this.scrollController,
    required this.scannedResult,
    required this.passphraseOptions,
    required this.walletNameField,
  });

  final ScrollController? scrollController;
  final Widget scannedResult;
  final Widget? passphraseOptions;
  final Widget? walletNameField;

  @override
  Widget build(BuildContext context) {
    if (scrollController == null) return scannedResult;
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          scannedResult,
          const SizedBox(height: 28),
          passphraseOptions!,
          const SizedBox(height: 28),
          walletNameField!,
        ],
      ),
    );
  }
}
