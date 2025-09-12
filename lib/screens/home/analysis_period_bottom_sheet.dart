import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

class AnalysisPeriodBottomSheet extends StatefulWidget {
  final void Function(int days) onSelected;
  final void Function(TransactionType transactionType) onTransactionTypeSelected;
  final int initialPeriodPreset;
  final TransactionType initialAnalysisTransactionType;
  const AnalysisPeriodBottomSheet(
      {super.key,
      required this.onSelected,
      required this.onTransactionTypeSelected,
      this.initialPeriodPreset = 30,
      this.initialAnalysisTransactionType = TransactionType.unknown});

  @override
  State<AnalysisPeriodBottomSheet> createState() => _AnalysisPeriodBottomSheetState();
}

class _AnalysisPeriodBottomSheetState extends State<AnalysisPeriodBottomSheet> {
  final List<int> presets = const [30, 60, 90, 0];
  final List<TransactionType> transactionTypes = const [
    TransactionType.unknown,
    TransactionType.sent,
    TransactionType.received,
  ];
  int? customDays;
  late List<bool> _selectedPeriodIndices;
  late TransactionType _selectedAnalysisTransactionType;

  @override
  void initState() {
    super.initState();
    _selectedPeriodIndices =
        List.generate(presets.length, (index) => presets[index] == widget.initialPeriodPreset);
    _selectedAnalysisTransactionType = widget.initialAnalysisTransactionType;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CoconutColors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 55,
                height: 4,
                decoration: BoxDecoration(
                  color: CoconutColors.gray400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          CoconutLayout.spacing_400h,
          Text(t.wallet_home_screen.analysis_period_bottom_sheet.period_for_analysis,
              style: CoconutTypography.body1_16_Bold),
          CoconutLayout.spacing_300h,
          CoconutSegmentedControl(
            labels: [
              t.wallet_home_screen.analysis_period_bottom_sheet.days_30,
              t.wallet_home_screen.analysis_period_bottom_sheet.days_60,
              t.wallet_home_screen.analysis_period_bottom_sheet.days_90,
              t.wallet_home_screen.analysis_period_bottom_sheet.custom,
            ],
            isSelected: _selectedPeriodIndices,
            onPressed: (index) {
              setState(() {
                _selectedPeriodIndices = [index == 0, index == 1, index == 2, index == 3];
              });
              widget.onSelected(presets[index]);
            },
          ),
          CoconutLayout.spacing_500h,
          if (_selectedPeriodIndices[3])
            Row(
              children: [
                Expanded(
                  child: CoconutTextField(
                    controller: TextEditingController(),
                    focusNode: FocusNode(),
                    onChanged: (v) {
                      final val = int.tryParse(v);
                      setState(() => customDays = val);
                    },
                    placeholderText: '구현 예정',
                  ),
                ),
                CoconutLayout.spacing_200w,
                CoconutButton(
                  onPressed: () {},
                  text: '적용',
                )
              ],
            ),
          CoconutLayout.spacing_400h,
          Text(t.wallet_home_screen.analysis_period_bottom_sheet.transaction_type,
              style: CoconutTypography.body1_16_Bold),
          CoconutLayout.spacing_300h,
          CoconutSegmentedControl(
            labels: [
              t.all,
              t.send,
              t.receive,
            ],
            isSelected:
                transactionTypes.map((type) => type == _selectedAnalysisTransactionType).toList(),
            onPressed: (index) {
              setState(() {
                _selectedAnalysisTransactionType = transactionTypes[index];
              });
              widget.onTransactionTypeSelected(transactionTypes[index]);
            },
          ),
        ],
      ),
    );
  }
}
