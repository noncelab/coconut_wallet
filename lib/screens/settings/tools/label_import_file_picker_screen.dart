import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/core/bip/329/label_jsonl_manager.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/file_list_item_card.dart';
import 'package:coconut_wallet/widgets/card/option_card.dart';
import 'package:coconut_wallet/widgets/label_import_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

enum LabelImportStep { fileSelection, optionSelection, loading, success, error, noLabelsToApply }

class LabelImportFilePickerScreen extends StatefulWidget {
  final int? walletId;
  final bool importMemosFromOtherWalletsFixed;

  const LabelImportFilePickerScreen({super.key, this.walletId, this.importMemosFromOtherWalletsFixed = false});

  @override
  State<LabelImportFilePickerScreen> createState() => _LabelImportFilePickerScreenState();
}

class _LabelImportFilePickerScreenState extends State<LabelImportFilePickerScreen> {
  late Future<List<File>> _filesFuture;
  LabelImportStep _step = LabelImportStep.fileSelection;
  int? _selectedItemIndex;
  String? _fileName;
  List<LabelImportResult> _importResults = [];
  int _currentPage = 0;
  bool _deleteFileOnSuccess = true;
  bool _addMemoToExisting = false;
  late bool _importMemosFromOtherWallets;

  @override
  void initState() {
    super.initState();
    _importMemosFromOtherWallets = widget.importMemosFromOtherWalletsFixed;
    _filesFuture = LabelJsonLManager().getImportableLabelFiles();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = _step != LabelImportStep.loading;
    return PopScope(
      canPop: canPop,
      child: Stack(
        children: [
          Scaffold(
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
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildBody(context, snapshot);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<List<File>> snapshot) {
    final bool noFiles = snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty;

    return Stack(
      children: [
        if (_step == LabelImportStep.success)
          _buildContent(context, snapshot, noFiles)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: <Widget>[
                if (_step == LabelImportStep.fileSelection) _buildInfoTooltip(context),
                Expanded(child: _buildContent(context, snapshot, noFiles)),
              ],
            ),
          ),
        if (_step == LabelImportStep.fileSelection && !noFiles)
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(
              text: t.label_management_screen.file.select_button,
              isActive: _selectedItemIndex != null,
              onButtonClicked: () => _onSelectButtonPressed(snapshot.data!),
            ),
          ),
        if (_step == LabelImportStep.optionSelection)
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(
              text: t.label_management_screen.file.apply,
              isActive: true,
              onButtonClicked: _onApplyButtonPressed,
            ),
          ),
        if (_step == LabelImportStep.error)
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(
              text: t.retry,
              isActive: true,
              onButtonClicked: () {
                setState(() {
                  _step = LabelImportStep.fileSelection;
                });
              },
            ),
          ),
        if (_step == LabelImportStep.success)
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(
              text: t.complete,
              isActive: true,
              onButtonClicked: () async {
                if (_deleteFileOnSuccess && _selectedItemIndex != null) {
                  final files = await _filesFuture;
                  final fileToDelete = files[_selectedItemIndex!];
                  await fileToDelete.delete();
                }
                Navigator.of(context).pop();
              },
            ),
          ),
        if (_step == LabelImportStep.noLabelsToApply)
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(
              text: t.complete,
              isActive: true,
              onButtonClicked: () {
                Navigator.of(context).pop();
              },
            ),
          ),
      ],
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
        return _buildNoLabelsToApplyView();
    }
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
          separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                  if (_selectedItemIndex == index) {
                    _selectedItemIndex = null;
                  } else {
                    _selectedItemIndex = index;
                  }
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
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: context.coconutColors.border,
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
    );
  }

  Widget _buildInfoTooltip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
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
            t.label_import_file_picker_screen.option_selection.title,
            style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
          ),
          Text(_fileName ?? '', style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText)),
          CoconutLayout.spacing_100h,
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
              children: [
                TextSpan(text: t.label_import_file_picker_screen.option_selection.description_1),
                const TextSpan(text: '\n'),
                TextSpan(
                  text: t.label_import_file_picker_screen.option_selection.description_2,
                  style: CoconutTypography.body3_12_Bold,
                ),
              ],
            ),
          ),
        ],
      ),
      buttons: [
        OptionCard(
          title: t.label_import_file_picker_screen.option_selection.add_memo_to_existing.title,
          subtitle: [TextSpan(text: t.label_import_file_picker_screen.option_selection.add_memo_to_existing.subtitle)],
          isSelected: _addMemoToExisting,
          onTap: () {
            setState(() {
              _addMemoToExisting = !_addMemoToExisting;
            });
          },
        ),
        OptionCard(
          title: t.label_import_file_picker_screen.option_selection.import_memos_from_other_wallets.title,
          subtitle: [
            TextSpan(text: t.label_import_file_picker_screen.option_selection.import_memos_from_other_wallets.subtitle),
          ],
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
        text: TextSpan(
          style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
          children: [
            TextSpan(text: t.label_import_file_picker_screen.loading_title),
            const TextSpan(text: '\n'),
            TextSpan(text: _fileName, style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText)),
          ],
        ),
      ),
      steps: [
        t.label_import_file_picker_screen.instruction_tooltip.step1,
        t.label_import_file_picker_screen.instruction_tooltip.step2,
        t.label_import_file_picker_screen.instruction_tooltip.step3,
        t.label_import_file_picker_screen.instruction_tooltip.step4,
      ],
      showSkeleton: true,
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Column(
      children: [
        CoconutLayout.spacing_600h,
        ImportLabelSuccessCard(
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
                children: [
                  TextSpan(text: t.label_import_file_picker_screen.success_title),
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
      onTap: () => setState(() => _deleteFileOnSuccess = !_deleteFileOnSuccess),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SvgPicture.asset(
            _deleteFileOnSuccess ? 'assets/svg/square_check.svg' : 'assets/svg/square.svg',
            width: 20,
            colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
          ),
          const SizedBox(width: 8),
          Text(
            t.label_import_file_picker_screen.delete_file,
            style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
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
          CoconutLayout.spacing_200h,
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
              children: [
                TextSpan(text: t.label_import_file_picker_screen.no_applied_memo),
                const TextSpan(text: '\n'),
                TextSpan(
                  text: _fileName,
                  style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_400h,
          Column(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _deleteFileOnSuccess = !_deleteFileOnSuccess;
                  });
                },
                child: const Row(mainAxisAlignment: MainAxisAlignment.start, children: [SizedBox(width: 8)]),
              ),
            ],
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
        text: TextSpan(
          style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.danger),
          children: [
            TextSpan(text: t.label_import_file_picker_screen.error_title),
            const TextSpan(text: '\n'),
            TextSpan(text: _fileName, style: CoconutTypography.body1_16.setColor(context.coconutColors.danger)),
          ],
        ),
      ),
    );
  }

  void _onSelectButtonPressed(List<File> files) async {
    if (_selectedItemIndex == null) return;

    final selectedFile = files[_selectedItemIndex!];
    final fileName = p.basename(selectedFile.path);

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: t.label_management_screen.file.apply,
            description: t.label_management_screen.file.apply_description(fileName: fileName),
            onTapRight: () => Navigator.of(dialogContext).pop(true),
            rightButtonText: t.confirm,
          ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _step = LabelImportStep.optionSelection;
        _fileName = fileName;
      });
    }
  }

  Future<void> _onApplyButtonPressed() async {
    if (_selectedItemIndex == null) return;

    final walletProvider = context.read<WalletProvider>();
    final files = await _filesFuture;
    final selectedFile = files[_selectedItemIndex!];

    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _step = LabelImportStep.loading);

    try {
      await Future.delayed(const Duration(milliseconds: 2500));
      final result =
          widget.walletId != null && !_importMemosFromOtherWallets
              ? await LabelJsonLManager().importLabelsForWallet(
                widget.walletId!,
                walletProvider,
                selectedFile.path,
                addMemoToExisting: _addMemoToExisting,
              )
              : await LabelJsonLManager().importLabelsForAllWallets(
                walletProvider,
                selectedFile.path,
                addMemoToExisting: _addMemoToExisting,
              );
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
      _filesFuture = LabelJsonLManager().getImportableLabelFiles();
      _selectedItemIndex = null;
    });
  }

  Future<void> _addExternalFile() async {
    try {
      final addedFile = await LabelJsonLManager().pickAndSaveExternalLabelFile();
      if (addedFile != null && mounted) {
        _refreshFiles();
      }
    } catch (e) {
      if (mounted) {
        CoconutToast.showToast(
          context: context,
          text: t.label_management_screen.file.invalid_file_type,
          level: CoconutToastLevel.error,
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
