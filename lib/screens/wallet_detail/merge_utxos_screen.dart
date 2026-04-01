import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/merge_utxos/merge_utxos_view_model.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';

class MergeUtxosScreen extends StatefulWidget {
  final int id;

  const MergeUtxosScreen({super.key, required this.id});

  @override
  State<MergeUtxosScreen> createState() => _MergeUtxosScreenState();
}

class _MergeUtxosScreenState extends State<MergeUtxosScreen> {
  bool _forceMerge = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MergeUtxosViewModel>(
      create: (context) => MergeUtxosViewModel(widget.id, context.read<UtxoRepository>())..initialize(),
      child: Consumer<MergeUtxosViewModel>(
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
      title: t.merge_utxos_screen.title,
      isBottom: true,
      isBackButton: true,
    );
  }

  Widget _buildBody(BuildContext context, MergeUtxosViewModel viewModel) {
    final int utxoCount = viewModel.utxoCount;

    if (_forceMerge || utxoCount >= 11) {
      return SafeArea(child: _buildMergeBody(context, viewModel));
    } else if (utxoCount >= 2 && utxoCount < 11) {
      return _buildFewUtxosBody(context, viewModel);
    } else {
      throw StateError('비정상적인 접근: 병합할 수 있는 UTXO 개수가 부족합니다. (현재 개수: $utxoCount)');
    }
  }

  Widget _buildFewUtxosBody(BuildContext context, MergeUtxosViewModel viewModel) {
    return Stack(
      children: [
        SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CoconutLayout.spacing_500h,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    t.merge_utxos_screen.not_enough_utxos,
                    style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                CoconutLayout.spacing_800h,
                Text(
                  t.merge_utxos_screen.efficient_utxo_state(count: viewModel.utxoCount),
                  style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: FixedBottomButton(
            text: t.merge_utxos_screen.merge_anyway,
            onButtonClicked: () {
              setState(() {
                _forceMerge = true;
              });
            },
            backgroundColor: CoconutColors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMergeBody(BuildContext context, MergeUtxosViewModel viewModel) {
    return Center(
      child: Text('UTXO 합치기 화면 (UTXO 개수: ${viewModel.utxoCount})', style: const TextStyle(color: Colors.white)),
    );
  }
}
