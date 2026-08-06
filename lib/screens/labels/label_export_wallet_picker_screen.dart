import 'dart:io';
import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/core/bip/329/label_jsonl_manager.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_tween_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

class LabelExportWalletPickerScreen extends StatefulWidget {
  const LabelExportWalletPickerScreen({super.key});

  @override
  State<LabelExportWalletPickerScreen> createState() => _LabelExportWalletPickerScreenState();
}

class _LabelExportWalletPickerScreenState extends State<LabelExportWalletPickerScreen> {
  int? _selectedWalletId;
  int? _selectedFileIndex;
  bool _isExporting = false;
  bool _isCreateFileSelected = true;

  late Future<List<File>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = LabelJsonLManager().getImportableLabelFiles();
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final wallets = walletProvider.walletItemList;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.coconutColors.background,
          appBar: CoconutAppBar.build(title: t.label_management_screen.export_title, context: context),
          body: _buildBody(context, wallets),
        ),
        if (_isExporting)
          Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<WalletItemBase> wallets) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: <Widget>[
              _buildInfoTooltip(context),
              CoconutLayout.spacing_400h,
              _buildSegmentedControl(context),
              Expanded(child: _buildContent(context, wallets)),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child:
              _isCreateFileSelected
                  ? FixedBottomButton(
                    text: t.label_management_screen.export_title,
                    isActive: _selectedWalletId != null,
                    onButtonClicked: _onExportButtonPressed,
                  )
                  : FixedBottomTweenButton(
                    leftText: t.delete_label,
                    rightText: t.share,
                    isRightButtonActive: _selectedFileIndex != null,
                    rightButtonClicked: () async {
                      final files = await _filesFuture;
                      _shareFile(files[_selectedFileIndex!]);
                    },
                    leftButtonClicked: () {},
                  ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, List<WalletItemBase> wallets) {
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
  }

  Widget _buildNoFilesFound(BuildContext context) {
    return Center(
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
    );
  }

  Widget _buildFileListView(BuildContext context, List<File> files) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 20, bottom: 90),
      itemCount: files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileListItemCard(
          file: file,
          isSelected: _selectedFileIndex == index,
          onTap: () {
            setState(() => _selectedFileIndex = _selectedFileIndex == index ? null : index);
          },
          onShare: () => _shareFile(file),
        );
      },
    );
  }

  Widget _buildWalletListView(BuildContext context, List<WalletItemBase> wallets) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 20, bottom: 90),
      itemCount: wallets.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _WalletListItemCard(
            title: t.label_export_wallet_picker_screen.all_wallets,
            isSelected: _selectedWalletId == -1,
            onTap: () {
              setState(() {
                _selectedWalletId = _selectedWalletId == -1 ? null : -1;
              });
            },
          );
        }

        final wallet = wallets[index - 1];
        return _WalletListItemCard(
          title: wallet.name,
          isSelected: _selectedWalletId == wallet.id,
          onTap: () {
            setState(() {
              _selectedWalletId = _selectedWalletId == wallet.id ? null : wallet.id;
            });
          },
        );
      },
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    return CoconutSegmentedControl(
      isSelected: [_isCreateFileSelected, !_isCreateFileSelected],
      onPressed: (index) {
        setState(() {
          _isCreateFileSelected = index == 0;
          _selectedWalletId = null;
          _selectedFileIndex = null;
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

  Future<void> _onExportButtonPressed() async {
    if (_selectedWalletId == null || _isExporting) return;

    setState(() => _isExporting = true);

    final walletProvider = context.read<WalletProvider>();
    final labelManager = LabelJsonLManager();

    try {
      final xFile =
          _selectedWalletId == -1
              ? await labelManager.createLabelsJsonLFileForAllWallets(walletProvider)
              : await labelManager.createLabelsJsonLFile(_selectedWalletId!, walletProvider);

      if (xFile != null) {
        await labelManager.shareFile(xFile);
      } else {
        if (mounted) {
          CoconutToast.showToast(context: context, text: 'a', level: CoconutToastLevel.info);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _shareFile(File file) async {
    final labelManager = LabelJsonLManager();
    await labelManager.shareFile(labelManager.createXFileFromFile(file));
  }
}

class _WalletListItemCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _WalletListItemCard({required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                  Text(title, style: CoconutTypography.body2_14, maxLines: 1, overflow: TextOverflow.ellipsis),
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
  final VoidCallback onShare;
  final bool isSelected;

  const _FileListItemCard({required this.file, required this.onTap, required this.onShare, required this.isSelected});

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
            const SizedBox(width: 16),
            GestureDetector(
              onTap: onShare,
              child: SvgPicture.asset(
                'assets/svg/share.svg',
                width: 24,
                colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
