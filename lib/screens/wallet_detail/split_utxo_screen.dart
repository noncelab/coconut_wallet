import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/split_utxo/split_utxo_view_model.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplitUtxoScreen extends StatefulWidget {
  final int id;

  const SplitUtxoScreen({super.key, required this.id});

  @override
  State<SplitUtxoScreen> createState() => SplitUtxoScreenState();
}

class SplitUtxoScreenState extends State<SplitUtxoScreen> {
  String? _selectedSplitCriteria;

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
    Widget bodyContent;
    if (_selectedSplitCriteria == null) {
      bodyContent = _buildInitialSelectionView(context, viewModel);
    } else if (_selectedSplitCriteria == t.split_utxo_screen.bottomsheet.split_by_amount) {
      bodyContent = _buildSplitByAmountBody(viewModel);
    } else if (_selectedSplitCriteria == t.split_utxo_screen.bottomsheet.split_evenly) {
      bodyContent = _buildSplitEvenlyBody(viewModel);
    } else if (_selectedSplitCriteria == t.split_utxo_screen.bottomsheet.split_manually) {
      bodyContent = _buildSplitManuallyBody(viewModel);
    } else {
      bodyContent = const SizedBox.shrink();
    }
    return SafeArea(child: bodyContent);
  }

  Widget _buildInitialSelectionView(BuildContext context, SplitUtxoViewModel viewModel) {
    //TODO: 초기 화면 UI 구현 (예시에서는 버튼으로 대체)
    return Center(
      child: SizedBox(
        width: 100,
        height: 100,
        child: CoconutButton(text: '바텀시트 열기', onPressed: () => _showSplitCriteriaBottomSheet(context, viewModel)),
      ),
    );
  }

  Widget _buildSplitByAmountBody(SplitUtxoViewModel viewModel) {
    return Center(child: Text('금액 기준으로 나누기 화면', style: CoconutTypography.body1_16.setColor(CoconutColors.white)));
  }

  Widget _buildSplitEvenlyBody(SplitUtxoViewModel viewModel) {
    return Center(child: Text('균등하게 나누기 화면', style: CoconutTypography.body1_16.setColor(CoconutColors.white)));
  }

  Widget _buildSplitManuallyBody(SplitUtxoViewModel viewModel) {
    return Center(child: Text('수동으로 나누기 화면', style: CoconutTypography.body1_16.setColor(CoconutColors.white)));
  }

  void _showSplitCriteriaBottomSheet(BuildContext context, SplitUtxoViewModel viewModel) async {
    final items = [
      t.split_utxo_screen.bottomsheet.split_by_amount,
      t.split_utxo_screen.bottomsheet.split_evenly,
      t.split_utxo_screen.bottomsheet.split_manually,
    ];

    final selectedItem = await CommonBottomSheets.showSelectableDraggableSheet<String>(
      context: context,
      title: t.split_utxo_screen.bottomsheet.title,
      items: items,
      getItemId: (item) => item,
      initialChildSize: 0.5,
      confirmText: t.complete,
      minChildSize: 0.49,
      maxChildSize: 0.9,
      backgroundColor: CoconutColors.gray900,
      itemBuilder: (context, item, isSelected, onTap) {
        return SelectableBottomSheetTextItem(text: item, isSelected: isSelected, onTap: onTap);
      },
    );

    if (selectedItem != null && context.mounted) {
      setState(() {
        _selectedSplitCriteria = selectedItem;
      });
    }
  }
}
