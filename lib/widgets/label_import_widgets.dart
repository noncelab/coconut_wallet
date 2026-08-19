import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/model/label/label_result.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';

class ImportLabelSuccessCard extends StatefulWidget {
  final Widget title;
  final List<LabelImportResult> importResults;
  final ValueChanged<int> onPageChanged;
  final int currentPage;

  const ImportLabelSuccessCard({
    super.key,
    required this.title,
    required this.importResults,
    required this.onPageChanged,
    required this.currentPage,
  });

  @override
  State<ImportLabelSuccessCard> createState() => _ImportLabelSuccessCardState();
}

class _ImportLabelSuccessCardState extends State<ImportLabelSuccessCard> {
  double _successCardHeight = 150;

  Widget _buildSuccessCard(BuildContext context, LabelImportResult importResult) {
    return ImportLabelInstructionToolTip(
      steps: [
        t.label_import_file_picker_screen.instruction_tooltip.step1,
        t.label_import_file_picker_screen.instruction_tooltip.step2,
        t.label_import_file_picker_screen.instruction_tooltip.step3,
        t.label_import_file_picker_screen.instruction_tooltip.step4,
      ],
      stepResults: [
        importResult.wallet?.name ?? '',
        importResult.txMemoCount,
        importResult.utxoTagCount,
        importResult.utxoLockCount,
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
                    : context.coconutColors.secondaryText.withOpacity(0.5),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
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
            child: _SizeReportingWidget(
              onSizeChanged: (size) {
                if (!mounted || _successCardHeight == size.height) return;
                setState(() => _successCardHeight = size.height);
              },
              child: _buildSuccessCard(context, widget.importResults[widget.currentPage]),
            ),
          ),
          SizedBox(
            height: _successCardHeight,
            child: PageView.builder(
              itemCount: widget.importResults.length,
              onPageChanged: widget.onPageChanged,
              itemBuilder: (context, index) => _buildSuccessCard(context, widget.importResults[index]),
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
      ),
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

class _SizeReportingWidget extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onSizeChanged;

  const _SizeReportingWidget({required this.onSizeChanged, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _SizeReportingRenderObject(onSizeChanged);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _SizeReportingRenderObject renderObject) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _SizeReportingRenderObject extends RenderProxyBox {
  _SizeReportingRenderObject(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;
  Size? _reportedSize;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reportedSize) return;
    _reportedSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSizeChanged(size));
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
          SizedBox(
            width: 48,
            height: 48,
            child: Transform.scale(
              scale: 0.8,
              child:
                  isProgressing
                      ? CircularProgressIndicator(color: context.coconutColors.loadingIndicatorColor, strokeWidth: 3)
                      : const SizedBox.shrink(),
            ),
          ),
          CoconutLayout.spacing_1000h,
          title,
          CoconutLayout.spacing_500h,
          ImportLabelInstructionToolTip(steps: steps, showSkeleton: showSkeleton),
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
          SizedBox(
            width: 48,
            height: 48,
            child: Transform.scale(
              scale: 0.8,
              child: CircularProgressIndicator(color: context.coconutColors.loadingIndicatorColor, strokeWidth: 3),
            ),
          ),
          CoconutLayout.spacing_1000h,
          title,
          CoconutLayout.spacing_500h,
          ButtonGroup(buttons: buttons),
        ],
      ),
    );
  }
}

class ImportLabelInstructionToolTip extends StatelessWidget {
  final List<Object> steps;
  final String? notice;
  final bool showSkeleton;
  final List<Object>? stepResults;

  const ImportLabelInstructionToolTip({
    super.key,
    required this.steps,
    this.notice,
    this.showSkeleton = false,
    this.stepResults,
  });

  @override
  Widget build(BuildContext context) {
    return CoconutToolTip(
      backgroundColor: context.coconutColors.surface,
      borderColor: context.coconutColors.surface,
      icon: const SizedBox.shrink(),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(
        text: TextSpan(
          style: CoconutTypography.body2_14,
          children: [
            if (notice != null) ...[
              TextSpan(
                text: notice,
                style: TextStyle(color: context.coconutColors.primaryText, fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '\n\n'),
            ],
            ...steps.asMap().entries.map((e) {
              final stepText = e.value as String;

              return WidgetSpan(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            stepText,
                            style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                          ),
                        ),
                        if (showSkeleton) ...[
                          const SizedBox(width: 8),
                          Shimmer.fromColors(
                            baseColor: context.coconutColors.surfaceSkeletonBase,
                            highlightColor: context.coconutColors.surfaceSkeletonHighlight,
                            child: Container(
                              width: 60,
                              height: 14,
                              decoration: BoxDecoration(
                                color: context.coconutColors.surfaceSkeletonBase,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                        if (!showSkeleton && stepResults != null && e.key < stepResults!.length) ...[
                          ...[
                            const SizedBox(width: 8),
                            Text(() {
                              final result = stepResults![e.key];
                              if (result is int) {
                                return '$result${t.label_import_file_picker_screen.widget.count_unit(n: result)}';
                              }
                              return result.toString();
                            }(), style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText)),
                          ],
                        ],
                      ],
                    ),
                    if (e.key < steps.length - 1) CoconutLayout.spacing_300h,
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
