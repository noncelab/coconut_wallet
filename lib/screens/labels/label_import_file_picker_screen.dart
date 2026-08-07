import 'dart:io';
import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/core/bip/329/label_jsonl_manager.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/label_import_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

enum LabelImportStep { fileSelection, loading, success, error }

class LabelImportFilePickerScreen extends StatefulWidget {
  final ValueChanged<String> onFileSelected;

  const LabelImportFilePickerScreen({super.key, required this.onFileSelected});

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

  @override
  void initState() {
    super.initState();
    _filesFuture = LabelJsonLManager().getImportableLabelFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.coconutColors.background,
          appBar: CoconutAppBar.build(title: t.label_management_screen.import_title, context: context),
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
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<List<File>> snapshot) {
    final bool noFiles = snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty;

    return Stack(
      children: [
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
              text: t.label_management_screen.file.apply,
              isActive: _selectedItemIndex != null,
              onButtonClicked: () => _onApplyButtonPressed(snapshot.data!),
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
      ],
    );
  }

  Widget _buildContent(BuildContext context, AsyncSnapshot<List<File>> snapshot, bool noFiles) {
    switch (_step) {
      case LabelImportStep.fileSelection:
        return noFiles ? _buildNoFilesFound(context) : _buildFileListView(context, snapshot.data!);
      case LabelImportStep.loading:
        return Center(child: _buildLoadingCard());
      case LabelImportStep.success:
        return _buildSuccessView(context);
      case LabelImportStep.error:
        return Center(child: _buildErrorCard(context));
    }
  }

  Widget _buildNoFilesFound(BuildContext context) {
    return GestureDetector(
      onTap: _addExternalFile,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.coconutColors.secondaryText.withOpacity(0.1),
              ),
              child: SvgPicture.asset(
                'assets/svg/file.svg',
                width: 40,
                height: 40,
                colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
              ),
            ),
            CoconutLayout.spacing_400h,
            Text(
              t.label_management_screen.file.not_found,
              style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileListView(BuildContext context, List<File> files) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 20, bottom: 90),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 27),
          decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SvgPicture.asset(
                'assets/svg/plus.svg',
                width: 12,
                colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              Text(
                t.label_management_screen.file.select,
                style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
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

  Widget _buildSuccessView(BuildContext context) {
    if (_importResults.isEmpty) {
      return Center(
        child: Text(
          t.label_import_file_picker_screen.no_applied_memo,
          style: CoconutTypography.body1_16,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/svg/circle-check.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.textHighlight, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_200h,
          RichText(
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
          CoconutLayout.spacing_400h,
          Column(
            children: [
              SizedBox(
                height: 125,
                child: PageView.builder(
                  itemCount: _importResults.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return _buildSuccessCard(context, _importResults[index]);
                  },
                ),
              ),
              if (_importResults.length > 1) _buildPageIndicator(),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _deleteFileOnSuccess = !_deleteFileOnSuccess;
                  });
                },
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

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_importResults.length, (index) {
        return Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                _currentPage == index
                    ? context.coconutColors.primaryText
                    : context.coconutColors.secondaryText.withOpacity(0.5),
          ),
        );
      }),
    );
  }

  void _onApplyButtonPressed(List<File> files) async {
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
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _step = LabelImportStep.loading;
        _fileName = fileName;
      });
      try {
        await Future.delayed(const Duration(milliseconds: 2500));
        final result = await LabelJsonLManager().importLabelsForAllWallets(
          context.read<WalletProvider>(),
          selectedFile.path,
        );
        if (mounted) {
          setState(() {
            _step = LabelImportStep.success;
            _importResults = result;
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _step = LabelImportStep.error;
        });
      }
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

  String _formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    final size = (bytes / pow(1024, i));
    return '${size.toStringAsFixed(size > 10 || i == 0 ? 0 : decimals)} ${suffixes[i]}';
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

class FileListItemCard extends StatelessWidget {
  final File file;
  final bool isSelected;
  final VoidCallback onTap;

  const FileListItemCard({super.key, required this.file, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(file.path);
    final modifiedDate = DateFormat('yy-MM-dd HH:mm').format(file.lastModifiedSync());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: context.coconutColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? context.coconutColors.primaryText : Colors.transparent, width: 1),
        ),
        child: Row(
          children: [
            isSelected
                ? SvgPicture.asset(
                  'assets/svg/square_check.svg',
                  width: 24,
                  colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                )
                : SvgPicture.asset(
                  'assets/svg/square.svg',
                  width: 24,
                  colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName, style: CoconutTypography.body1_16, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _LabelImportFilePickerScreenState()._formatBytes(file.lengthSync()),
                        style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                      ),
                      Text(' • ', style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
                      Text(
                        modifiedDate,
                        style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
