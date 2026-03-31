import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/split_utxo/split_utxo_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplitUtxoScreen extends StatefulWidget {
  final int id;

  const SplitUtxoScreen({super.key, required this.id});

  @override
  State<SplitUtxoScreen> createState() => SplitUtxoScreenState();
}

class SplitUtxoScreenState extends State<SplitUtxoScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SplitUtxoViewModel>(
      create: (context) => SplitUtxoViewModel(widget.id),
      child: Consumer<SplitUtxoViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: _buildAppBar(context),
            body: _buildBody(context, viewModel),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      context: context,
      backgroundColor: CoconutColors.black,
      title: t.split_utxo_screen.title,
      isBottom: true,
      isBackButton: true,
    );
  }

  Widget _buildBody(BuildContext context, SplitUtxoViewModel viewModel) {
    return const SafeArea(child: Text('나누기'));
  }
}
