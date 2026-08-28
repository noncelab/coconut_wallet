import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/label/label_result.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/card/label_result_card.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:coconut_wallet/widgets/size_reporting_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class LabelImportSuccessCard extends StatefulWidget {
  final Widget title;
  final List<LabelImportResult> importResults;
  final ValueChanged<int> onPageChanged;
  final int currentPage;

  const LabelImportSuccessCard({
    super.key,
    required this.title,
    required this.importResults,
    required this.onPageChanged,
    required this.currentPage,
  });

  @override
  State<LabelImportSuccessCard> createState() => _LabelImportSuccessCardState();
}

class _LabelImportSuccessCardState extends State<LabelImportSuccessCard> {
  double _successCardHeight = 150;

  String _formatCount(int count) => '$count${t.label_import_file_picker_screen.widget.count_unit(n: count)}';

  Widget _buildSuccessCard(BuildContext context, LabelImportResult importResult) {
    return LabelResultCard(
      steps: [
        t.label_import_file_picker_screen.result.step1,
        t.label_import_file_picker_screen.result.step2,
        t.label_import_file_picker_screen.result.step3,
        t.label_import_file_picker_screen.result.step4,
      ],
      stepResults: [
        importResult.wallet?.name ?? '',
        _formatCount(importResult.txMemoCount),
        _formatCount(importResult.utxoTagCount),
        _formatCount(importResult.utxoLockCount),
      ],
      showSkeleton: false,
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.importResults.length, (index) {
        return Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                widget.currentPage == index
                    ? context.coconutColors.primaryText
                    : context.coconutColors.secondaryText.withValues(alpha: 0.5),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/svg/circle-check.svg',
          colorFilter: ColorFilter.mode(context.coconutColors.textHighlight, BlendMode.srcIn),
          height: 48,
          width: 48,
        ),
        CoconutLayout.spacing_1000h,
        widget.title,
        CoconutLayout.spacing_500h,
        Offstage(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizeReportingWidget(
              onSizeChanged: (size) {
                if (!mounted || _successCardHeight == size.height) return;
                setState(() => _successCardHeight = size.height);
              },
              child: _buildSuccessCard(context, widget.importResults[widget.currentPage]),
            ),
          ),
        ),
        SizedBox(
          height: _successCardHeight,
          child: PageView.builder(
            itemCount: widget.importResults.length,
            onPageChanged: widget.onPageChanged,
            itemBuilder:
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildSuccessCard(context, widget.importResults[index]),
                ),
          ),
        ),
        if (widget.importResults.length > 1) ...[
          const SizedBox(height: 14),
          _buildPageIndicator(),
          const SizedBox(height: 13),
        ] else ...[
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class ImportLabelErrorCard extends StatelessWidget {
  final Widget title;

  const ImportLabelErrorCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/svg/circle-warning.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_1000h,
          title,
          CoconutLayout.spacing_500h,
        ],
      ),
    );
  }
}

class ImportLabelProgressCard extends StatelessWidget {
  final Widget title;
  final List<Object> steps;
  final bool showSkeleton;
  final bool isProgressing;

  const ImportLabelProgressCard({
    super.key,
    required this.title,
    required this.steps,
    this.showSkeleton = false,
    this.isProgressing = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(width: 48, height: 48, child: isProgressing ? const CircularLoadingSpinner() : null),
          CoconutLayout.spacing_1000h,
          title,
          CoconutLayout.spacing_500h,
          LabelResultCard(steps: steps, showSkeleton: showSkeleton),
        ],
      ),
    );
  }
}

class ImportOptionCard extends StatelessWidget {
  final Widget title;
  final List<Widget> buttons;

  const ImportOptionCard({super.key, required this.title, required this.buttons});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const CircularLoadingSpinner(),
          CoconutLayout.spacing_1000h,
          title,
          CoconutLayout.spacing_500h,
          ButtonGroup(buttons: buttons),
        ],
      ),
    );
  }
}
