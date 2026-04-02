import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/merge_utxos/merge_utxos_view_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
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
  String? _selectedMergeStandard;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MergeUtxosViewModel>(
      create:
          (context) =>
              MergeUtxosViewModel(widget.id, context.read<UtxoRepository>(), context.read<UtxoTagProvider>())
                ..initialize(),
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
    if (viewModel.utxoCount < 2) {
      return Center(
        child: Text('병합할 수 있는 UTXO가 부족합니다.', style: CoconutTypography.body1_16.setColor(CoconutColors.white)),
      );
    }

    if (!_forceMerge && viewModel.utxoCount < 11) {
      return _buildFewUtxosWarning(viewModel);
    }

    return SafeArea(child: _buildMergeContent(context, viewModel));
  }

  Widget _buildFewUtxosWarning(MergeUtxosViewModel viewModel) {
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

  Widget _buildMergeContent(BuildContext context, MergeUtxosViewModel viewModel) {
    if (_selectedMergeStandard == null) {
      return _buildInitialSelectionView(context, viewModel);
    }

    if (_selectedMergeStandard == t.merge_utxos_screen.bottomsheet.merge_small_amounts) {
      return _buildMergeSmallAmountsBody(viewModel);
    }
    if (_selectedMergeStandard == t.merge_utxos_screen.bottomsheet.merge_same_tag) {
      return _buildMergeSameTagBody(viewModel);
    }
    if (_selectedMergeStandard == t.merge_utxos_screen.bottomsheet.merge_same_address) {
      return _buildMergeSameAddressBody(viewModel);
    }

    return const SizedBox.shrink();
  }

  Widget _buildInitialSelectionView(BuildContext context, MergeUtxosViewModel viewModel) {
    //TODO: 초기 화면 UI 구현 (예시에서는 버튼으로 대체)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('UTXO 합치기 화면 (UTXO 개수: ${viewModel.utxoCount})', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          'UTXO 합치기 화면 (UTXO 개수: ${viewModel.utxoCount})'.characterFadeInAnimation(
            textStyle: const TextStyle(color: Colors.white),
            duration: const Duration(milliseconds: 300),
          ),
          SizedBox(
            width: 160,
            child: CoconutButton(text: '바텀시트 열기', onPressed: () => _showMergeStandardBottomSheet(context, viewModel)),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeSmallAmountsBody(MergeUtxosViewModel viewModel) {
    return Center(child: Text('소액 UTXO 합치기 화면', style: CoconutTypography.body1_16.setColor(CoconutColors.white)));
  }

  Widget _buildMergeSameTagBody(MergeUtxosViewModel viewModel) {
    return Center(child: Text('동일 태그 UTXO 합치기 화면', style: CoconutTypography.body1_16.setColor(CoconutColors.white)));
  }

  Widget _buildMergeSameAddressBody(MergeUtxosViewModel viewModel) {
    return Center(child: Text('동일 주소 UTXO 합치기 화면', style: CoconutTypography.body1_16.setColor(CoconutColors.white)));
  }

  void _showMergeStandardBottomSheet(BuildContext context, MergeUtxosViewModel viewModel) async {
    final selectedItem = await CommonBottomSheets.showBottomSheet<String>(
      showCloseButton: true,
      context: context,
      backgroundColor: CoconutColors.gray900,
      title: t.merge_utxos_screen.bottomsheet.title,
      child: SelectableBottomSheetBody<String>(
        items: [
          t.merge_utxos_screen.bottomsheet.merge_small_amounts,
          t.merge_utxos_screen.bottomsheet.merge_same_tag,
          t.merge_utxos_screen.bottomsheet.merge_same_address,
        ],
        showGradient: false,
        getItemId: (item) => item,
        confirmText: t.complete,
        backgroundColor: CoconutColors.gray900,
        itemBuilder: (context, item, isSelected, onTap) {
          final isTagMergeItem = item == t.merge_utxos_screen.bottomsheet.merge_same_tag;
          final isAddressMergeItem = item == t.merge_utxos_screen.bottomsheet.merge_same_address;
          final isDisabled =
              (isTagMergeItem && !viewModel.hasMergeableTaggedUtxos) ||
              (isAddressMergeItem && !viewModel.hasSameAddressUtxos);

          return SelectableBottomSheetTextItem(
            text: item,
            isSelected: isSelected,
            onTap: onTap,
            isDisabled: isDisabled,
          );
        },
      ),
    );

    if (selectedItem != null && context.mounted) {
      setState(() {
        _selectedMergeStandard = selectedItem;
      });
    }
  }
}
