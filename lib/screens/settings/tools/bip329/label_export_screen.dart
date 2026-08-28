import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/label/label_result.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/label_export_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_tween_button.dart';
import 'package:coconut_wallet/widgets/card/file_list_item_card.dart';
import 'package:coconut_wallet/widgets/card/label_result_card.dart';
import 'package:coconut_wallet/widgets/label_export_widgets.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:coconut_wallet/widgets/size_reporting_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

enum LabelExportStep { selection, exporting, success, error }

class LabelExportScreen extends StatefulWidget {
  final int? initialSelectedWalletId;

  const LabelExportScreen({super.key, this.initialSelectedWalletId});

  @override
  State<LabelExportScreen> createState() => _LabelExportScreenState();
}

class _LabelExportScreenState extends State<LabelExportScreen> {
  final Set<int> _selectedWalletIds = {};
  final Set<int> _selectedFileIndices = {};
  bool _isCreateFileSelected = true;
  LabelExportStep _step = LabelExportStep.selection;
  File? _exportedFile;
  List<LabelExportResult> _exportResults = [];
  int _currentPage = 0;
  double _successCardHeight = 160;

  late final LabelExportViewModel _exportViewModel;
  late Future<List<File>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _exportViewModel = LabelExportViewModel(walletProvider: context.read<WalletProvider>());
    if (widget.initialSelectedWalletId != null &&
        _exportViewModel.hasExportableLabelsForWallet(widget.initialSelectedWalletId!)) {
      _selectedWalletIds.add(widget.initialSelectedWalletId!);
    }
    _filesFuture = _exportViewModel.getImportableLabelFiles();
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final preferenceProvider = context.watch<PreferenceProvider>();

    List<WalletItemBase> wallets;
    if (widget.initialSelectedWalletId != null) {
      wallets = walletProvider.walletItemList.where((w) => w.id == widget.initialSelectedWalletId).toList();
    } else {
      final walletList = walletProvider.walletItemList.toList();
      final walletOrder = preferenceProvider.walletOrder;
      walletList.sort((a, b) => walletOrder.indexOf(a.id).compareTo(walletOrder.indexOf(b.id)));
      wallets = walletList;
    }

    final canPop = _step != LabelExportStep.exporting;

    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: CoconutAppBar.build(
          title: t.label_management_screen.export_title,
          context: context,
          isLeadingVisible: canPop,
        ),
        body: _buildBody(context, wallets),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<WalletItemBase> wallets) {
    return Stack(
      children: [
        if (_step == LabelExportStep.success)
          _buildContent(context, wallets)
        else
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
        _buildBottomButtonArea(),
      ],
    );
  }

  Widget _buildBottomButtonArea() {
    switch (_step) {
      case LabelExportStep.selection:
        if (_isCreateFileSelected) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(
              text: t.label_management_screen.export_title,
              isActive: _selectedWalletIds.isNotEmpty,
              onButtonClicked: _onExportButtonPressed,
            ),
          );
        } else {
          return FutureBuilder<List<File>>(
            future: _filesFuture,
            builder: (context, snapshot) {
              final noFiles = snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty;
              if (noFiles) return const SizedBox.shrink();

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
                  leftButtonClicked: _deleteSelectedFile,
                ),
              );
            },
          );
        }
      case LabelExportStep.success:
        return Align(
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
        );
      case LabelExportStep.error:
        return Align(
          alignment: Alignment.bottomCenter,
          child: FixedBottomButton(
            text: t.retry,
            isActive: true,
            onButtonClicked: () {
              setState(() => _step = LabelExportStep.selection);
            },
          ),
        );
      case LabelExportStep.exporting:
        return const SizedBox.shrink();
    }
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
                return const Center(child: CircularLoadingSpinner());
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
    final fullText = t.label_export_screen.no_file;
    final parts = fullText.split(RegExp(r'\[|\]'));

    Widget content;
    if (parts.length != 3) {
      content = Text(
        fullText,
        style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
        textAlign: TextAlign.center,
      );
    } else {
      content = RichText(
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
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [const SizedBox(height: 64), content],
    );
  }

  Widget _buildFileListView(BuildContext context, List<File> files) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.coconutColors.background,
            Colors.transparent,
            Colors.transparent,
            context.coconutColors.background,
          ],
          stops: const [0.0, 0.03, 0.97, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstOut,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 20, bottom: 125),
        itemCount: files.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final file = files[index];
          return FileListItemCard(
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
      ),
    );
  }

  Widget _buildWalletListView(BuildContext context, List<WalletItemBase> wallets) {
    if (wallets.isEmpty) {
      return _buildNoWalletsFound(context);
    }

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.coconutColors.background,
            Colors.transparent,
            Colors.transparent,
            context.coconutColors.background,
          ],
          stops: const [0.0, 0.03, 0.97, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstOut,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 20, bottom: 125),
        itemCount: wallets.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final wallet = wallets[index];
          final isLocked = widget.initialSelectedWalletId == wallet.id;
          final hasLabels = _exportViewModel.hasExportableLabelsForWallet(wallet.id);

          return _WalletListItemCard(
            title: wallet.name,
            isSelected: _selectedWalletIds.contains(wallet.id),
            isLocked: isLocked,
            isDisabled: !hasLabels,
            onTap: () {
              if (isLocked || !hasLabels) return;
              _toggleWalletSelection(wallet.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildNoWalletsFound(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 100),
        Text(
          t.label_export_screen.no_wallet,
          style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
          textAlign: TextAlign.center,
        ),
      ],
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
          if (widget.initialSelectedWalletId != null &&
              _exportViewModel.hasExportableLabelsForWallet(widget.initialSelectedWalletId!)) {
            _selectedWalletIds.add(widget.initialSelectedWalletId!);
          }
        });
      },
      selectedColor: context.coconutColors.segmentedControlSelected,
      segmentedControlContainerColor: context.coconutColors.segmentedControlBackground,
      selectedTextColor: context.coconutColors.segmentedControlSelectedText,
      unselectedTextColor: context.coconutColors.segmentedControlUnselectedText,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(t.label_export_screen.create_file)),
        FittedBox(fit: BoxFit.scaleDown, child: Text(t.label_export_screen.view_list)),
      ],
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
            children: [TextSpan(text: t.label_export_screen.info_tooltip)],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return LabelExportProgressCard(
      title: Text(
        t.label_export_screen.loading_title,
        style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
        textAlign: TextAlign.center,
        textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
      ),
      topSteps: [t.label_export_screen.result.step1, t.label_export_screen.result.step2],
      bottomSteps: [
        t.label_export_screen.result.step3,
        t.label_export_screen.result.step4,
        t.label_export_screen.result.step5,
        t.label_export_screen.result.step6,
      ],
    );
  }

  Widget _buildErrorCard() {
    return LabelExportErrorCard(
      title: Text(
        t.label_export_screen.error_title,
        style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.danger),
        textAlign: TextAlign.center,
        textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
      ),
    );
  }

  Future<void> _onExportButtonPressed() async {
    if (_selectedWalletIds.isEmpty || _step == LabelExportStep.exporting) return;

    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => _step = LabelExportStep.exporting);
    }

    final selectedWalletIds = _selectedWalletIds.toList();

    try {
      final result = await _exportViewModel.exportLabelsForWallets(selectedWalletIds);

      if (result.xFile != null) {
        if (mounted) {
          setState(() {
            _filesFuture = _exportViewModel.getImportableLabelFiles();
            _selectedFileIndices.clear();
          });
        }
        await Future.delayed(const Duration(milliseconds: 2500));

        final exportResults = _exportViewModel.buildExportResults(selectedWalletIds, result.xFile!);
        final exportedFile = File(result.xFile!.path);

        if (mounted) {
          setState(() {
            _step = LabelExportStep.success;
            _exportedFile = exportedFile;
            _exportResults = exportResults;
            _currentPage = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() => _step = LabelExportStep.selection);
        }
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
          t.label_export_screen.no_labels_to_share,
          style: CoconutTypography.body1_16,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: LabelExportSuccessCard(
            title: Text(
              t.label_export_screen.success_title,
              style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
              textAlign: TextAlign.center,
              textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2)),
            ),
            steps: [t.label_export_screen.result.step1, t.label_export_screen.result.step2],
            stepResults: [
              _exportResults.first.xFile?.name ?? '',
              DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
            ],
          ),
        ),
        CoconutLayout.spacing_300h,
        Offstage(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizeReportingWidget(
              onSizeChanged: (size) {
                if (!mounted || _successCardHeight == size.height) return;
                setState(() => _successCardHeight = size.height);
              },
              child: _buildSuccessBottomCard(_exportResults[_currentPage]),
            ),
          ),
        ),
        SizedBox(
          height: _successCardHeight,
          child: PageView.builder(
            itemCount: _exportResults.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder:
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildSuccessBottomCard(_exportResults[index]),
                ),
          ),
        ),
        if (_exportResults.length > 1) ...[const SizedBox(height: 14), _buildPageIndicator()],
      ],
    );
  }

  Widget _buildSuccessBottomCard(LabelExportResult result) {
    return LabelResultCard(
      steps: [
        t.label_export_screen.result.step3,
        t.label_export_screen.result.step4,
        t.label_export_screen.result.step5,
        t.label_export_screen.result.step6,
      ],
      stepResults: [
        result.wallet?.name ?? '',
        '${result.txMemoCount}${t.label_import_screen.widget.count_unit(n: result.txMemoCount)}',
        '${result.utxoTagCount}${t.label_import_screen.widget.count_unit(n: result.utxoTagCount)}',
        '${result.utxoLockCount}${t.label_import_screen.widget.count_unit(n: result.utxoLockCount)}',
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
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                _currentPage == index
                    ? context.coconutColors.primaryText
                    : context.coconutColors.secondaryText.withValues(alpha: 0.5),
          ),
        );
      }),
    );
  }

  Future<void> _shareFiles(List<File> files) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin =
        renderBox != null && renderBox.hasSize ? renderBox.localToGlobal(Offset.zero) & renderBox.size : null;
    await _exportViewModel.shareFiles(files, sharePositionOrigin: sharePositionOrigin);
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

    if (!mounted) return;

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
        await _exportViewModel.deleteFiles(filesToDelete);
        if (!mounted) return;
        CoconutToast.showToast(
          context: context,
          text: t.label_management_screen.file.delete_success,
          isVisibleIcon: true,
          iconPath: 'assets/svg/circle-info.svg',
          level: CoconutToastLevel.info,
        );
        _refreshFiles();
      } catch (e) {
        if (!mounted) return;
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
      _filesFuture = _exportViewModel.getImportableLabelFiles();
      _selectedFileIndices.clear();
    });
  }
}

class _WalletListItemCard extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLocked;
  final bool isDisabled;

  const _WalletListItemCard({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.isLocked = false,
    this.isDisabled = false,
  });

  @override
  State<_WalletListItemCard> createState() => _WalletListItemCardState();
}

class _WalletListItemCardState extends State<_WalletListItemCard> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool effectiveDisabled = widget.isDisabled || (widget.isLocked && widget.isSelected);
    final textColor = effectiveDisabled ? context.coconutColors.secondaryText : context.coconutColors.primaryText;

    final Color borderColor;
    if (widget.isSelected) {
      borderColor = context.coconutColors.primaryText;
    } else {
      borderColor = context.coconutColors.border.withValues(alpha: 0.7);
    }

    final double scale = (_isPressed && !effectiveDisabled) ? 0.96 : 1.0;

    return GestureDetector(
      onTapDown: effectiveDisabled ? null : _onTapDown,
      onTapUp: effectiveDisabled ? null : _onTapUp,
      onTapCancel: effectiveDisabled ? null : _onTapCancel,
      onTap: effectiveDisabled ? null : widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              CoconutCheckbox(
                isSelected: widget.isSelected,
                onChanged: (_) => widget.onTap(),
                width: 24,
                color: context.coconutColors.iconDefault,
                unSelectedColor: context.coconutColors.iconSubDefault,
                inactiveColor: context.coconutColors.iconDisabled,
                isDisabled: effectiveDisabled,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      widget.title,
                      style: CoconutTypography.body2_14.setColor(textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (widget.isDisabled) ...[
                      const SizedBox(width: 8),
                      Text(
                        t.label_export_screen.no_labels_to_export,
                        style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
