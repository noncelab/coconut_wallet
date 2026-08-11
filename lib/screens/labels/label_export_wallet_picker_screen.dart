import 'dart:io';
import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/core/bip/329/label_jsonl_manager.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_tween_button.dart';
import 'package:coconut_wallet/widgets/label_export_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

enum LabelExportStep { selection, exporting, success, error }

class LabelExportWalletPickerScreen extends StatefulWidget {
  final int? initialSelectedWalletId;

  const LabelExportWalletPickerScreen({super.key, this.initialSelectedWalletId});

  @override
  State<LabelExportWalletPickerScreen> createState() => _LabelExportWalletPickerScreenState();
}

class _LabelExportWalletPickerScreenState extends State<LabelExportWalletPickerScreen> {
  final Set<int> _selectedWalletIds = {};
  final Set<int> _selectedFileIndices = {};
  bool _isCreateFileSelected = true;
  LabelExportStep _step = LabelExportStep.selection;
  File? _exportedFile;
  List<LabelExportResult> _exportResults = [];
  int _currentPage = 0;

  late Future<List<File>> _filesFuture;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedWalletId != null) {
      _selectedWalletIds.add(widget.initialSelectedWalletId!);
    }
    _filesFuture = LabelJsonLManager().getImportableLabelFiles();
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    List<WalletItemBase> wallets;
    if (widget.initialSelectedWalletId != null) {
      wallets = walletProvider.walletItemList.where((w) => w.id == widget.initialSelectedWalletId).toList();
    } else {
      wallets = walletProvider.walletItemList;
    }

    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(title: t.label_management_screen.export_title, context: context),
      body: _buildBody(context, wallets),
    );
  }

  Widget _buildBody(BuildContext context, List<WalletItemBase> wallets) {
    final bool showBottomButtons = _step == LabelExportStep.selection && _isCreateFileSelected;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: <Widget>[
              if (_step == LabelExportStep.selection) ...[
                _buildInfoTooltip(context),
                CoconutLayout.spacing_400h,
                _buildSegmentedControl(context),
              ],
              Expanded(child: _buildContent(context, wallets)),
            ],
          ),
        ),
        if (showBottomButtons) ...[
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(
              text: t.label_management_screen.export_title,
              isActive: _selectedWalletIds.isNotEmpty,
              onButtonClicked: _onExportButtonPressed,
            ),
          ),
        ] else if (_step == LabelExportStep.selection && !_isCreateFileSelected) ...[
          FutureBuilder<List<File>>(
            future: _filesFuture,
            builder: (context, snapshot) {
              final noFiles = snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty;
              if (noFiles) {
                return const SizedBox.shrink();
              }
              return Align(
                alignment: Alignment.bottomCenter,
                child: FixedBottomTweenButton(
                  leftText: t.delete_label,
                  rightText: t.share,
                  leftButtonRatio: 0.3,
                  isLeftButtonActive: _selectedFileIndices.isNotEmpty,
                  isRightButtonActive: _selectedFileIndices.isNotEmpty,
                  rightButtonClicked: () async {
                    final files = await _filesFuture;
                    final selectedFiles = _selectedFileIndices.map((index) => files[index]).toList();
                    await _shareFiles(selectedFiles);
                  },
                  leftButtonClicked: () async {
                    await _deleteSelectedFile();
                  },
                ),
              );
            },
          ),
        ],
        if (_step == LabelExportStep.success)
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomTweenButton(
              leftText: t.complete,
              rightText: t.share,
              leftButtonRatio: 0.3,
              isRightButtonActive: true,
              leftButtonClicked: () {
                setState(() {
                  _step = LabelExportStep.selection;
                  _isCreateFileSelected = false;
                });
              },
              rightButtonClicked: () async {
                if (_exportedFile != null) await _shareFiles([_exportedFile!]);
              },
            ),
          ),
        if (_step == LabelExportStep.error)
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(
              text: t.retry,
              isActive: true,
              onButtonClicked: () {
                setState(() {
                  _step = LabelExportStep.selection;
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, List<WalletItemBase> wallets) {
    switch (_step) {
      case LabelExportStep.selection:
        if (_isCreateFileSelected) {
          return _buildWalletListView(context, wallets);
        } else {
          return FutureBuilder<List<File>>(
            future: _filesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final noFiles = snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty;
              if (noFiles) {
                return _buildNoFilesFound(context);
              }
              return _buildFileListView(context, snapshot.data!);
            },
          );
        }
      case LabelExportStep.exporting:
        return Center(child: _buildLoadingCard());
      case LabelExportStep.success:
        return _buildSuccessView();
      case LabelExportStep.error:
        return Center(child: _buildErrorCard());
    }
  }

  Widget _buildNoFilesFound(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        () {
          final fullText = t.label_export_wallet_picker_screen.no_file;
          final parts = fullText.split(RegExp(r'\[|\]'));

          if (parts.length != 3) {
            return Text(
              fullText,
              style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
              textAlign: TextAlign.center,
            );
          }

          return RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
              children: [
                TextSpan(text: parts[0]),
                TextSpan(text: '[${parts[1]}]', style: CoconutTypography.body1_16_Bold),
                TextSpan(text: parts[2]),
              ],
            ),
          );
        }(),
      ],
    );
  }

  Widget _buildFileListView(BuildContext context, List<File> files) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 20, bottom: 125),
      itemCount: files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileListItemCard(
          file: file,
          isSelected: _selectedFileIndices.contains(index),
          onTap: () {
            setState(() {
              if (_selectedFileIndices.contains(index)) {
                _selectedFileIndices.remove(index);
              } else {
                _selectedFileIndices.add(index);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildWalletListView(BuildContext context, List<WalletItemBase> wallets) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20, bottom: 125),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: wallets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final wallet = wallets[index];
              final isLocked = widget.initialSelectedWalletId == wallet.id;

              return _WalletListItemCard(
                title: wallet.name,
                isSelected: _selectedWalletIds.contains(wallet.id),
                isLocked: isLocked,
                onTap: () {
                  if (isLocked) return;
                  _toggleWalletSelection(wallet.id);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _toggleWalletSelection(int walletId) {
    setState(() {
      if (_selectedWalletIds.contains(walletId)) {
        _selectedWalletIds.remove(walletId);
      } else {
        _selectedWalletIds.add(walletId);
      }
    });
  }

  Widget _buildSegmentedControl(BuildContext context) {
    return CoconutSegmentedControl(
      isSelected: [_isCreateFileSelected, !_isCreateFileSelected],
      onPressed: (index) {
        setState(() {
          _isCreateFileSelected = index == 0;
          _selectedWalletIds.clear();
          _selectedFileIndices.clear();
          if (widget.initialSelectedWalletId != null) {
            _selectedWalletIds.add(widget.initialSelectedWalletId!);
          }
        });
      },
      selectedColor: context.coconutColors.segmentedControlSelected,
      segmentedControlContainerColor: context.coconutColors.segmentedControlBackground,
      selectedTextColor: context.coconutColors.segmentedControlSelectedText,
      unselectedTextColor: context.coconutColors.segmentedControlUnselectedText,
      children: [
        Text(t.label_export_wallet_picker_screen.create_file),
        Text(t.label_export_wallet_picker_screen.view_list),
      ],
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
            children: [TextSpan(text: t.label_export_wallet_picker_screen.info_tooltip)],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return ExportLabelProgressCard(
      title: Text(
        t.label_export_wallet_picker_screen.loading_title,
        style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
        textAlign: TextAlign.center,
      ),
      topSteps: [
        t.label_export_wallet_picker_screen.instruction_tooltip.step1,
        t.label_export_wallet_picker_screen.instruction_tooltip.step2,
      ],
      bottomSteps: [
        t.label_export_wallet_picker_screen.instruction_tooltip.step3,
        t.label_export_wallet_picker_screen.instruction_tooltip.step4,
        t.label_export_wallet_picker_screen.instruction_tooltip.step5,
        t.label_export_wallet_picker_screen.instruction_tooltip.step6,
      ],
    );
  }

  Widget _buildErrorCard() {
    return ExportLabelErrorCard(
      title: Text(
        t.label_export_wallet_picker_screen.error_title,
        style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.danger),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _onExportButtonPressed() async {
    if (_selectedWalletIds.isEmpty || _step == LabelExportStep.exporting) return;

    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _step = LabelExportStep.exporting);

    final walletProvider = context.read<WalletProvider>();
    final labelManager = LabelJsonLManager();

    try {
      final result = await labelManager.createLabelsJsonLFileForWallets(_selectedWalletIds.toList(), walletProvider);

      if (result.xFile != null) {
        setState(() {
          _filesFuture = LabelJsonLManager().getImportableLabelFiles();
          _selectedFileIndices.clear();
        });
        await Future.delayed(const Duration(milliseconds: 2500));

        final List<LabelExportResult> exportResults = [];

        for (final walletId in _selectedWalletIds) {
          final wallet = walletProvider.getWalletById(walletId);
          exportResults.add(
            LabelExportResult(
              xFile: result.xFile,
              wallet: wallet,
              txMemoCount: walletProvider.getAllTransactionMemos(walletId).where((m) => m.memo.isNotEmpty).length,
              utxoTagCount: walletProvider.getUtxoTags(walletId).fold(0, (sum, tag) => sum + tag.utxoIdList.length),
              utxoLockCount: walletProvider.getUtxoList(walletId).where((u) => u.status == UtxoStatus.locked).length,
            ),
          );
        }

        setState(() {
          _step = LabelExportStep.success;
          _exportedFile = File(result.xFile!.path);
          _exportResults = exportResults;
          _currentPage = 0;
        });
      } else {
        if (mounted) {
          CoconutToast.showToast(
            context: context,
            text: t.label_export_wallet_picker_screen.no_labels_to_export,
            level: CoconutToastLevel.info,
          );
        }
        setState(() => _step = LabelExportStep.selection);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _step = LabelExportStep.error);
      }
    }
  }

  Widget _buildSuccessView() {
    if (_exportResults.isEmpty) {
      return Center(
        child: Text(
          t.label_export_wallet_picker_screen.no_labels_to_export,
          style: CoconutTypography.body1_16,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          ExportLabelSuccessCard(
            title: Text(
              t.label_export_wallet_picker_screen.success_title,
              style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
              textAlign: TextAlign.center,
            ),
            steps: [
              t.label_export_wallet_picker_screen.instruction_tooltip.step1,
              t.label_export_wallet_picker_screen.instruction_tooltip.step2,
            ],
            stepResults: [
              _exportResults.first.xFile?.name ?? '',
              DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
            ],
          ),
          SizedBox(
            height: 150,
            child: PageView.builder(
              itemCount: _exportResults.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) => _buildSuccessBottomCard(_exportResults[index]),
            ),
          ),
          if (_exportResults.length > 1) _buildPageIndicator(),
        ],
      ),
    );
  }

  Widget _buildSuccessBottomCard(LabelExportResult result) {
    return ExportLabelInstructionToolTip(
      steps: [
        t.label_export_wallet_picker_screen.instruction_tooltip.step3,
        t.label_export_wallet_picker_screen.instruction_tooltip.step4,
        t.label_export_wallet_picker_screen.instruction_tooltip.step5,
        t.label_export_wallet_picker_screen.instruction_tooltip.step6,
      ],
      stepResults: [
        result.wallet?.name ?? '',
        '${result.txMemoCount}${t.label_import_file_picker_screen.widget.count_unit(n: result.txMemoCount)}',
        '${result.utxoTagCount}${t.label_import_file_picker_screen.widget.count_unit(n: result.utxoTagCount)}',
        '${result.utxoLockCount}${t.label_import_file_picker_screen.widget.count_unit(n: result.utxoLockCount)}',
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_exportResults.length, (index) {
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

  Future<void> _shareFiles(List<File> files) async {
    final labelManager = LabelJsonLManager();
    final xFiles = files.map((file) => labelManager.createXFileFromFile(file)).toList();
    final renderBox = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin =
        renderBox != null && renderBox.hasSize ? renderBox.localToGlobal(Offset.zero) & renderBox.size : null;
    await labelManager.shareFiles(xFiles, sharePositionOrigin: sharePositionOrigin);
  }

  Future<void> _deleteSelectedFile() async {
    if (_selectedFileIndices.isEmpty) return;

    final files = await _filesFuture;
    final filesToDelete = _selectedFileIndices.map((index) => files[index]).toList();
    final count = filesToDelete.length;
    final description =
        count == 1
            ? t.label_management_screen.file.delete_description(fileName: p.basename(filesToDelete.first.path))
            : t.label_management_screen.file.delete_multiple_description(count: count);

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: t.label_management_screen.file.delete,
            description: description,
            onTapRight: () => Navigator.of(dialogContext).pop(true),
            onTapLeft: () => Navigator.of(dialogContext).pop(false),
            rightButtonText: t.delete,
            rightButtonColor: context.coconutColors.danger,
            leftButtonText: t.cancel,
          ),
    );

    if (confirmed == true && mounted) {
      try {
        for (final file in filesToDelete) {
          await file.delete();
        }
        CoconutToast.showToast(
          context: context,
          text: t.label_management_screen.file.delete_success,
          isVisibleIcon: true,
          iconPath: 'assets/svg/circle-info.svg',
          level: CoconutToastLevel.info,
        );
        _refreshFiles();
      } catch (e) {
        CoconutToast.showToast(
          context: context,
          text: t.label_management_screen.file.delete_failed,
          level: CoconutToastLevel.error,
        );
      }
    }
  }

  void _refreshFiles() {
    setState(() {
      _filesFuture = LabelJsonLManager().getImportableLabelFiles();
      _selectedFileIndices.clear();
    });
  }
}

class _WalletListItemCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLocked;

  const _WalletListItemCard({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = isLocked && isSelected;
    final iconColor = isDisabled ? context.coconutColors.iconDisabled : context.coconutColors.iconDefault;
    final textColor = isDisabled ? context.coconutColors.secondaryText : context.coconutColors.primaryText;
    final Color borderColor;
    if (isDisabled) {
      borderColor = context.coconutColors.iconDisabled;
    } else if (isSelected) {
      borderColor = context.coconutColors.primaryText;
    } else {
      borderColor = context.coconutColors.border;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              isSelected ? 'assets/svg/square_check.svg' : 'assets/svg/square.svg',
              width: 24,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: CoconutTypography.body2_14.setColor(textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _FileListItemCard extends StatelessWidget {
  final File file;
  final VoidCallback onTap;
  final bool isSelected;

  const _FileListItemCard({required this.file, required this.onTap, required this.isSelected});

  String _formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return "0 B";
    if (bytes == 1) return "1 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    final size = (bytes / pow(1024, i));
    return '${size.toStringAsFixed(size > 10 || i == 0 ? 0 : decimals)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(file.path);
    final modifiedDate = DateFormat('yy-MM-dd HH:mm').format(file.lastModifiedSync());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: context.coconutColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? context.coconutColors.primaryText : Colors.transparent, width: 1),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              isSelected ? 'assets/svg/square_check.svg' : 'assets/svg/square.svg',
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
                        _formatBytes(file.lengthSync()),
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
