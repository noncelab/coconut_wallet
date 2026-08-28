import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/label/label_result.dart';
import 'package:coconut_wallet/providers/view_model/settings/label_import_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/file_list_item_card.dart';
import 'package:coconut_wallet/widgets/card/option_card.dart';
import 'package:coconut_wallet/widgets/label_import_widgets.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

enum LabelImportStep { fileSelection, optionSelection, loading, success, error, noLabelsToApply }

class LabelImportScreen extends StatefulWidget {
  final int? walletId;
  final bool importMemosFromOtherWalletsFixed;

  const LabelImportScreen({super.key, this.walletId, this.importMemosFromOtherWalletsFixed = false});

  @override
  State<LabelImportScreen> createState() => _LabelImportScreenState();
}

class _LabelImportScreenState extends State<LabelImportScreen> {
  late final LabelImportViewModel _importViewModel;
  late Future<List<File>> _filesFuture;

  LabelImportStep _step = LabelImportStep.fileSelection;
  int? _selectedItemIndex;
  String? _fileName;
  List<LabelImportResult> _importResults = [];
  int _currentPage = 0;
  bool _deleteFileOnSuccess = true;
  bool _overwriteMemo = false;
  late bool _importMemosFromOtherWallets;
  bool _isAddButtonPressed = false;
  bool _isDeleteFileOptionPressed = false;

  @override
  void initState() {
    super.initState();
    _importViewModel = LabelImportViewModel(walletProvider: context.read<WalletProvider>());
    _importMemosFromOtherWallets = widget.importMemosFromOtherWalletsFixed;
    _filesFuture = _importViewModel.getImportableLabelFiles();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = _step != LabelImportStep.loading;

    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: CoconutAppBar.build(
          title: t.label_management_screen.import_title,
          context: context,
          isLeadingVisible: canPop,
        ),
        body: FutureBuilder<List<File>>(
          future: _filesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularLoadingSpinner());
            }
            return _buildMainLayout(context, snapshot);
          },
        ),
      ),
    );
  }

  Widget _buildMainLayout(BuildContext context, AsyncSnapshot<List<File>> snapshot) {
    final bool noFiles = snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty;

    return Stack(children: [_buildStepContent(context, snapshot, noFiles), _buildBottomButtonArea(snapshot.data)]);
  }

  Widget _buildStepContent(BuildContext context, AsyncSnapshot<List<File>> snapshot, bool noFiles) {
    if (_step == LabelImportStep.success) {
      return _buildSuccessView(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: <Widget>[
          if (_step == LabelImportStep.fileSelection) _buildInfoTooltip(context),
          Expanded(child: _buildContent(context, snapshot, noFiles)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AsyncSnapshot<List<File>> snapshot, bool noFiles) {
    switch (_step) {
      case LabelImportStep.fileSelection:
        return noFiles ? _buildNoFilesFound(context) : _buildFileListView(context, snapshot.data!);
      case LabelImportStep.optionSelection:
        return _buildOptionSelectionView();
      case LabelImportStep.loading:
        return Center(child: _buildLoadingCard());
      case LabelImportStep.success:
        return _buildSuccessView(context);
      case LabelImportStep.error:
        return Center(child: _buildErrorCard(context));
      case LabelImportStep.noLabelsToApply:
        return Center(child: _buildNoLabelsToApplyView());
    }
  }

  Widget _buildBottomButtonArea(List<File>? files) {
    String? buttonText;
    bool isActive = true;
    VoidCallback? onPressed;

    switch (_step) {
      case LabelImportStep.fileSelection:
        if (files == null || files.isEmpty) return const SizedBox.shrink();
        buttonText = t.label_management_screen.file.select_button;
        isActive = _selectedItemIndex != null;
        onPressed = () => _onSelectButtonPressed(files);
        break;
      case LabelImportStep.optionSelection:
        buttonText = t.label_management_screen.file.apply;
        onPressed = _onApplyButtonPressed;
        break;
      case LabelImportStep.error:
        buttonText = t.retry;
        onPressed = () => setState(() => _step = LabelImportStep.fileSelection);
        break;
      case LabelImportStep.success:
        buttonText = t.complete;
        onPressed = () async {
          if (_deleteFileOnSuccess && _selectedItemIndex != null) {
            final fileList = await _filesFuture;
            await _importViewModel.deleteFile(fileList[_selectedItemIndex!]);
          }
          if (mounted) Navigator.of(context).pop();
        };
        break;
      case LabelImportStep.noLabelsToApply:
        buttonText = t.complete;
        onPressed = () => Navigator.of(context).pop();
        break;
      case LabelImportStep.loading:
        return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: FixedBottomButton(text: buttonText, isActive: isActive, onButtonClicked: onPressed),
    );
  }

  Widget _buildNoFilesFound(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(top: 20.0), child: Column(children: [_buildAddFileButton(context)]));
  }

  Widget _buildFileListView(BuildContext context, List<File> files) {
    final backgroundColor = context.coconutColors.background;

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.only(top: 20, bottom: 110),
          itemCount: files.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == files.length) {
              return _buildAddFileButton(context);
            }
            final file = files[index];
            return FileListItemCard(
              file: file,
              isSelected: _selectedItemIndex == index,
              onTap: () {
                setState(() {
                  _selectedItemIndex = (_selectedItemIndex == index) ? null : index;
                });
              },
            );
          },
        ),
        _buildListFade(backgroundColor, isTop: true),
        _buildListFade(backgroundColor, isTop: false),
      ],
    );
  }

  Widget _buildListFade(Color backgroundColor, {required bool isTop}) {
    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 90,
      left: 0,
      right: 0,
      height: 20,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors:
                  isTop
                      ? [backgroundColor, backgroundColor.withValues(alpha: 0)]
                      : [backgroundColor.withValues(alpha: 0), backgroundColor],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddFileButton(BuildContext context) {
    return GestureDetector(
      onTap: _addExternalFile,
      onTapDown: (_) => setState(() => _isAddButtonPressed = true),
      onTapUp: (_) => setState(() => _isAddButtonPressed = false),
      onTapCancel: () => setState(() => _isAddButtonPressed = false),
      child: AnimatedScale(
        scale: _isAddButtonPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: context.coconutColors.border.withValues(alpha: 0.7),
            strokeWidth: 1.0,
            dashWidth: 8.0,
            gapWidth: 4.0,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 27),
            decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  'assets/svg/plus.svg',
                  width: 14,
                  colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
                ),
                const SizedBox(width: 12),
                Text(
                  t.label_management_screen.file.select,
                  style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTooltip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: CoconutToolTip(
        backgroundColor: context.coconutColors.surface,
        borderColor: context.coconutColors.surface,
        icon: SvgPicture.asset(
          'assets/svg/circle-info.svg',
          width: 20,
          colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
        ),
        tooltipType: CoconutTooltipType.fixed,
        richText: RichText(
          text: TextSpan(
            style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
            children: [TextSpan(text: t.label_management_screen.tooltip.import)],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionSelectionView() {
    return ImportOptionCard(
      title: Column(
        children: [
          Text(
            t.label_import_screen.option_selection.title,
            style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
            textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
          ),
          Text(
            _fileName ?? '',
            style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
            textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          CoconutLayout.spacing_100h,
          RichText(
            textAlign: TextAlign.center,
            textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
            text: TextSpan(
              style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
              children: [
                TextSpan(text: t.label_import_screen.option_selection.description_1),
                const TextSpan(text: '\n'),
                TextSpan(
                  text: t.label_import_screen.option_selection.description_2,
                  style: CoconutTypography.body3_12_Bold,
                ),
              ],
            ),
          ),
        ],
      ),
      buttons: [
        OptionCard(
          title: t.label_import_screen.option_selection.add_memo_to_existing.title,
          subtitle: [TextSpan(text: t.label_import_screen.option_selection.add_memo_to_existing.subtitle)],
          isSelected: _overwriteMemo,
          onTap: () {
            setState(() {
              _overwriteMemo = !_overwriteMemo;
            });
          },
        ),
        OptionCard(
          title: t.label_import_screen.option_selection.import_memos_from_other_wallets.title,
          subtitle: [TextSpan(text: t.label_import_screen.option_selection.import_memos_from_other_wallets.subtitle)],
          isSelected: _importMemosFromOtherWallets,
          isEnabled: !widget.importMemosFromOtherWalletsFixed,
          onTap: () {
            setState(() {
              _importMemosFromOtherWallets = !_importMemosFromOtherWallets;
            });
          },
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return ImportLabelProgressCard(
      title: RichText(
        textAlign: TextAlign.center,
        textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
        text: TextSpan(
          style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
          children: [
            TextSpan(text: t.label_import_screen.loading_title),
            const TextSpan(text: '\n'),
            TextSpan(text: _fileName, style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText)),
          ],
        ),
      ),
      steps: [
        t.label_import_screen.result.step1,
        t.label_import_screen.result.step2,
        t.label_import_screen.result.step3,
        t.label_import_screen.result.step4,
      ],
      showSkeleton: true,
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Column(
      children: [
        CoconutLayout.spacing_600h,
        LabelImportSuccessCard(
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: RichText(
              textAlign: TextAlign.center,
              textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
              text: TextSpan(
                style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
                children: [
                  TextSpan(text: t.label_import_screen.success_title),
                  const TextSpan(text: '\n'),
                  TextSpan(
                    text: _fileName,
                    style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                  ),
                ],
              ),
            ),
          ),
          importResults: _importResults,
          currentPage: _currentPage,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: _buildDeleteFileCheckbox()),
      ],
    );
  }

  Widget _buildDeleteFileCheckbox() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isDeleteFileOptionPressed = true),
      onTapCancel: () => setState(() => _isDeleteFileOptionPressed = false),
      onTap: () {
        setState(() {
          _isDeleteFileOptionPressed = false;
          _deleteFileOnSuccess = !_deleteFileOnSuccess;
        });
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CoconutLayout.spacing_100w,
          IgnorePointer(
            child: CoconutCheckbox(
              isSelected: _deleteFileOnSuccess,
              onChanged: (_) {},
              width: 16,
              unSelectedColor: context.coconutColors.iconSubDefault,
              color:
                  _isDeleteFileOptionPressed ? context.coconutColors.iconSubDefault : context.coconutColors.iconDefault,
            ),
          ),
          CoconutLayout.spacing_200w,
          Expanded(
            child: Text(
              t.label_import_screen.delete_file,
              style: CoconutTypography.body3_12.setColor(
                _isDeleteFileOptionPressed ? context.coconutColors.tertiaryText : context.coconutColors.primaryText,
              ),
              textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLabelsToApplyView() {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 90),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/svg/circle-check.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.iconDisabled, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_1000h,
          RichText(
            textAlign: TextAlign.center,
            textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
            text: TextSpan(
              style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
              children: [
                TextSpan(text: t.label_import_screen.no_applied_memo),
                const TextSpan(text: '\n'),
                TextSpan(
                  text: _fileName,
                  style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return ImportLabelErrorCard(
      title: RichText(
        textAlign: TextAlign.center,
        textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
        text: TextSpan(
          style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.danger),
          children: [
            TextSpan(text: t.label_import_screen.error_title),
            const TextSpan(text: '\n'),
            TextSpan(text: _fileName, style: CoconutTypography.body1_16.setColor(context.coconutColors.danger)),
          ],
        ),
      ),
    );
  }

  void _onSelectButtonPressed(List<File> files) {
    if (_selectedItemIndex == null) return;

    final selectedFile = files[_selectedItemIndex!];
    final fileName = p.basename(selectedFile.path);

    if (mounted) {
      setState(() {
        _step = LabelImportStep.optionSelection;
        _fileName = fileName;
      });
    }
  }

  Future<void> _onApplyButtonPressed() async {
    if (_selectedItemIndex == null) return;

    final files = await _filesFuture;
    final selectedFile = files[_selectedItemIndex!];

    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _step = LabelImportStep.loading);

    try {
      await Future.delayed(const Duration(milliseconds: 2500));
      final result =
          widget.walletId != null && !_importMemosFromOtherWallets
              ? await _importViewModel.importLabelsForWallet(
                widget.walletId!,
                selectedFile.path,
                overwriteMemo: _overwriteMemo,
              )
              : await _importViewModel.importLabelsForAllWallets(selectedFile.path, overwriteMemo: _overwriteMemo);
      if (mounted) {
        if (result.isEmpty) {
          setState(() => _step = LabelImportStep.noLabelsToApply);
        } else {
          setState(() {
            _step = LabelImportStep.success;
            _importResults = result;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _step = LabelImportStep.error);
    }
  }

  void _refreshFiles() {
    setState(() {
      _filesFuture = _importViewModel.getImportableLabelFiles();
      _selectedItemIndex = null;
    });
  }

  Future<void> _addExternalFile() async {
    try {
      final addedFile = await _importViewModel.pickAndSaveExternalLabelFile();
      if (addedFile != null && mounted) {
        _refreshFiles();
      }
    } catch (e) {
      if (mounted) {
        CoconutToast.showToast(
          context: context,
          text: t.label_management_screen.file.invalid_file_type,
          isVisibleIcon: true,
          iconPath: 'assets/svg/triangle-warning.svg',
        );
      }
    }
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;
  final BorderRadius borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 5.0,
    this.gapWidth = 3.0,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final path = Path();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = borderRadius.toRRect(rect);

    final rrectPath = Path()..addRRect(rrect);
    for (final metric in rrectPath.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double start = distance;
        final double end = (distance + dashWidth).clamp(0.0, metric.length);
        path.addPath(metric.extractPath(start, end), Offset.zero);
        distance += dashWidth + gapWidth;
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.gapWidth != gapWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
