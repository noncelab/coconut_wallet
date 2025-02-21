import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';

class UtxoListScreen extends StatelessWidget {
  const UtxoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(
          title: t.utxo, context: context, hasRightIcon: false),
      body: const Center(
        child: Text('UTXO LIST SCREEN', style: Styles.body2Bold),
      ),
    );
  }
}
