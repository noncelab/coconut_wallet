import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_home_view_model.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

class AnalysisPeriodBottomSheet extends StatefulWidget {
  final void Function(int days) onSelected;
  final void Function(AnalysisTransactionType transactionType) onTransactionTypeSelected;
  final int initialPeriodPreset;
  final AnalysisTransactionType initialAnalysisTransactionType;
  const AnalysisPeriodBottomSheet({
    super.key,
    required this.onSelected,
    required this.onTransactionTypeSelected,
    this.initialPeriodPreset = 30,
    this.initialAnalysisTransactionType = AnalysisTransactionType.all,
  });

  @override
  State<AnalysisPeriodBottomSheet> createState() => _AnalysisPeriodBottomSheetState();
}

class _AnalysisPeriodBottomSheetState extends State<AnalysisPeriodBottomSheet> {
  final List<int> presets = const [30, 60, 90, 0];
  final List<AnalysisTransactionType> transactionTypes = const [
    AnalysisTransactionType.all,
    AnalysisTransactionType.onlySent,
    AnalysisTransactionType.onlyReceived,
  ];
  late List<bool> _selectedPeriodIndices;
  late AnalysisTransactionType _selectedAnalysisTransactionType;

  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _showDateSpinner({required bool isStart, ValueChanged<DateTime>? onDateChanged}) async {
    final now = DateTime.now();
    final initial = isStart ? (_startDate ?? now) : _endDate;
    final firstDate = isStart ? DateTime(2009, 1, 3) : (_startDate ?? DateTime(2009, 1, 3));
    final today = DateTime(now.year, now.month, now.day);
    final currentLanguage = Provider.of<PreferenceProvider>(context, listen: false).language;
    final isKorean = currentLanguage == 'kr';
    final isEnglish = currentLanguage == 'en';
    debugPrint('DEBUG11 - _showDateSpinner: $isStart');
    await showCupertinoModalPopup(
      context: context,
      builder: (context) {
        DateTime temp = initial!;
        final DateTime maxDate = isStart ? _endDate ?? today : today; // 종료는 무조건 오늘까지
        return Localizations.override(
          context: context,
          locale:
              isKorean
                  ? const Locale('ko', 'KR')
                  : isEnglish
                  ? const Locale('en', 'US')
                  : const Locale('ja', 'JP'),
          delegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          child: CupertinoTheme(
            data: CupertinoThemeData(
              primaryColor: CupertinoColors.white, // 선택 포커스/악센트
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: CoconutTypography.heading3_21.setColor(CoconutColors.white),
              ),
            ),
            child: SafeArea(
              bottom: true,
              child: Container(
                color: CoconutColors.black,
                height: 300,
                child: Column(
                  children: [
                    SizedBox(
                      height: 216,
                      child: Builder(
                        builder: (context) {
                          final DateTime initialClamped = () {
                            DateTime v = DateTime(temp.year, temp.month, temp.day);
                            if (v.isBefore(firstDate)) return firstDate;
                            if (v.isAfter(maxDate)) return maxDate;
                            return v;
                          }();
                          return CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.date,
                            initialDateTime: initialClamped,
                            minimumDate: firstDate,
                            maximumDate: maxDate,
                            minimumYear: firstDate.year,
                            maximumYear: maxDate.year,
                            onDateTimeChanged: (d) {
                              temp = DateTime(d.year, d.month, d.day);
                            },
                          );
                        },
                      ),
                    ),
                    CoconutLayout.spacing_200h,
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16),
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width,
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
                            child: Row(
                              children: [
                                Flexible(
                                  flex: 1,
                                  child: SizedBox(
                                    width: MediaQuery.sizeOf(context).width,
                                    child: ShrinkAnimationButton(
                                      defaultColor: CoconutColors.white,
                                      pressedColor: CoconutColors.gray350,
                                      onPressed: () => Navigator.pop(context),
                                      borderRadius: CoconutStyles.radius_200,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        child: Text(
                                          t.cancel,
                                          textAlign: TextAlign.center,
                                          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.black),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                CoconutLayout.spacing_200w,
                                Flexible(
                                  flex: 2,
                                  child: SizedBox(
                                    width: MediaQuery.sizeOf(context).width,
                                    child: ShrinkAnimationButton(
                                      defaultColor: CoconutColors.white,
                                      pressedColor: CoconutColors.gray350,
                                      onPressed: () {
                                        if (onDateChanged != null) {
                                          onDateChanged(temp);
                                        }
                                        Navigator.pop(context);
                                      },
                                      borderRadius: CoconutStyles.radius_200,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        child: Text(
                                          t.confirm,
                                          textAlign: TextAlign.center,
                                          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.black),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    CoconutLayout.spacing_200h,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return t.confirm;
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _selectedPeriodIndices = List.generate(presets.length, (index) => presets[index] == widget.initialPeriodPreset);
    _selectedAnalysisTransactionType = widget.initialAnalysisTransactionType;

    _startDate = getStartDateFromInitialPeriodPreset();
    _endDate = context.read<PreferenceProvider>().analysisPeriodRange.item2 ?? DateTime.now();
  }

  DateTime getStartDateFromInitialPeriodPreset() {
    if (_selectedPeriodIndices[0]) {
      return DateTime.now().subtract(const Duration(days: 30));
    } else if (_selectedPeriodIndices[1]) {
      return DateTime.now().subtract(const Duration(days: 60));
    } else if (_selectedPeriodIndices[2]) {
      return DateTime.now().subtract(const Duration(days: 90));
    } else {
      return context.read<PreferenceProvider>().analysisPeriodRange.item1 ?? DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: CoconutColors.black,
      body: SafeArea(
        bottom: true,
        child: Container(
          color: CoconutColors.black,
          child: Stack(
            children: [
              Container(
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
                    Text(
                      t.wallet_home_screen.analysis_period_bottom_sheet.period_for_analysis,
                      style: CoconutTypography.body1_16_Bold,
                    ),
                    CoconutLayout.spacing_300h,
                    MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
                      child: CoconutSegmentedControl(
                        labels: [
                          t.wallet_home_screen.analysis_period_bottom_sheet.days_30,
                          t.wallet_home_screen.analysis_period_bottom_sheet.days_60,
                          t.wallet_home_screen.analysis_period_bottom_sheet.days_90,
                          t.wallet_home_screen.analysis_period_bottom_sheet.custom,
                        ],
                        isSelected: _selectedPeriodIndices,
                        onPressed: (index) {
                          if (index == 3) {
                            _startDate = getStartDateFromInitialPeriodPreset();
                            _endDate = DateTime.now();
                          }
                          setState(() {
                            _selectedPeriodIndices = [index == 0, index == 1, index == 2, index == 3];
                          });
                        },
                      ),
                    ),
                    CoconutLayout.spacing_500h,
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child:
                          _selectedPeriodIndices[3]
                              ? Row(
                                children: [
                                  Expanded(
                                    child: CoconutButton(
                                      height: 50,
                                      onPressed:
                                          () => _showDateSpinner(
                                            isStart: true,
                                            onDateChanged: (d) => setState(() => _startDate = d),
                                          ),
                                      backgroundColor: CoconutColors.gray700,
                                      borderWidth: 1,
                                      buttonType: CoconutButtonType.outlined,
                                      foregroundColor: CoconutColors.black,
                                      textStyle: CoconutTypography.body2_14,
                                      text: _fmt(_startDate),
                                    ),
                                  ),
                                  CoconutLayout.spacing_200w,
                                  const Text('~'),
                                  CoconutLayout.spacing_200w,
                                  Expanded(
                                    child: CoconutButton(
                                      height: 50,
                                      onPressed:
                                          () => _showDateSpinner(
                                            isStart: false,
                                            onDateChanged: (d) => setState(() => _endDate = d),
                                          ),
                                      backgroundColor: CoconutColors.gray700,
                                      borderWidth: 1,
                                      buttonType: CoconutButtonType.outlined,
                                      foregroundColor: CoconutColors.black,
                                      textStyle: CoconutTypography.body2_14,
                                      text: _fmt(_endDate),
                                    ),
                                  ),
                                ],
                              )
                              : const SizedBox.shrink(),
                    ),
                    CoconutLayout.spacing_400h,
                    Text(
                      t.wallet_home_screen.analysis_period_bottom_sheet.transaction_type,
                      style: CoconutTypography.body1_16_Bold,
                    ),
                    CoconutLayout.spacing_300h,
                    MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
                      child: CoconutSegmentedControl(
                        labels: [t.all, t.send, t.receive],
                        isSelected: transactionTypes.map((type) => type == _selectedAnalysisTransactionType).toList(),
                        onPressed: (index) {
                          setState(() {
                            _selectedAnalysisTransactionType = transactionTypes[index];
                          });
                          // 외부 콜백 호출 제거: 확인 버튼에서만 적용
                        },
                      ),
                    ),
                  ],
                ),
              ),
              FixedBottomButton(
                onButtonClicked: () {
                  final selectedIndex =
                      _selectedPeriodIndices.indexWhere((e) => e) == -1
                          ? 0
                          : _selectedPeriodIndices.indexWhere((e) => e);
                  if (selectedIndex == 3) {
                    context.read<PreferenceProvider>().setAnalysisPeriodRange(_startDate!, _endDate ?? DateTime.now());
                  }
                  widget.onSelected(presets[selectedIndex]);

                  widget.onTransactionTypeSelected(_selectedAnalysisTransactionType);
                  Navigator.pop(context);
                },
                backgroundColor: CoconutColors.white,
                isActive:
                    (() {
                      final selectedIndex =
                          _selectedPeriodIndices.indexWhere((e) => e) == -1
                              ? 0
                              : _selectedPeriodIndices.indexWhere((e) => e);
                      final int initialIndex =
                          widget.initialPeriodPreset == 0 ? 3 : presets.indexOf(widget.initialPeriodPreset);
                      bool changedDays;
                      if (selectedIndex == 3 && initialIndex != 3) {
                        changedDays = true;
                      }
                      if (selectedIndex == 3) {
                        final initialRange = context.read<PreferenceProvider>().analysisPeriodRange;
                        final DateTime? initialStart = initialRange.item1;
                        final DateTime? initialEnd = initialRange.item2;

                        DateTime? dOnly(DateTime? d) => d == null ? null : DateTime(d.year, d.month, d.day);

                        changedDays = dOnly(_startDate) != dOnly(initialStart) || dOnly(_endDate) != dOnly(initialEnd);
                      } else {
                        changedDays = selectedIndex != initialIndex;
                      }
                      final bool changedType =
                          _selectedAnalysisTransactionType != widget.initialAnalysisTransactionType;
                      return changedDays || changedType;
                    })(),
                text: t.confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
