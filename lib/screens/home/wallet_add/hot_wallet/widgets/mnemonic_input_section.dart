import 'package:flutter/material.dart';

class MnemonicInputSection extends StatelessWidget {
  const MnemonicInputSection({
    super.key,
    required this.scrollController,
    required this.mnemonicInput,
    required this.passphraseOptions,
    required this.walletNameField,
    this.overlay,
  });

  final ScrollController scrollController;
  final Widget mnemonicInput;
  final Widget passphraseOptions;
  final Widget walletNameField;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              mnemonicInput,
              const SizedBox(height: 28),
              passphraseOptions,
              const SizedBox(height: 28),
              walletNameField,
            ],
          ),
        ),
        if (overlay != null) overlay!,
      ],
    );
  }
}
