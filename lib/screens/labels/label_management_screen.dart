import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/core/bip/329/label_jsonl_manager.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class LabelManagementScreen extends StatefulWidget {
  final String importDescription;
  final String exportDescription;
  final ValueChanged<String> onImport;
  final VoidCallback onExport;

  const LabelManagementScreen({
    super.key,
    required this.importDescription,
    required this.exportDescription,
    required this.onImport,
    required this.onExport,
  });

  @override
  State<LabelManagementScreen> createState() => _LabelManagementScreenState();
}

class _LabelManagementScreenState extends State<LabelManagementScreen> {
  final GlobalKey _tooltipIconKey = GlobalKey();
  Size? _tooltipIconSize;
  Offset? _tooltipIconPosition;
  bool _isTooltipVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTooltipPosition();
    });
  }

  void _updateTooltipPosition() {
    final renderBox = _tooltipIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _tooltipIconPosition = renderBox.localToGlobal(Offset.zero);
        _tooltipIconSize = renderBox.size;
      });
    }
  }

  void _toggleTooltip() {
    setState(() {
      _isTooltipVisible = !_isTooltipVisible;
    });
  }

  void _removeTooltip() {
    if (_isTooltipVisible) {
      setState(() {
        _isTooltipVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _removeTooltip,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: context.coconutColors.background,
            appBar: CoconutAppBar.build(
              title: t.labels_management_screen.title,
              context: context,
              actionButtonList: [
                IconButton(
                  key: _tooltipIconKey,
                  icon: SvgPicture.asset(
                    'assets/svg/question-mark.svg',
                    colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                  ),
                  onPressed: _toggleTooltip,
                ),
              ],
            ),
            body: _buildMenuView(context),
          ),
          if (_isTooltipVisible && _tooltipIconPosition != null && _tooltipIconSize != null) _buildTooltip(context),
        ],
      ),
    );
  }

  Widget _buildMenuView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          _buildInfoTooltip(context),
          CoconutLayout.spacing_1000h,
          ButtonGroup(
            buttons: [
              SingleButton(
                title: t.wallet_info_screen.import_labels,
                onPressed: () => _navigateToImportFilePicker(context),
              ),
              SingleButton(
                title: t.wallet_info_screen.export_labels,
                onPressed:
                    () => _navigateToActionScreen(
                      context: context,
                      title: t.wallet_info_screen.export_labels,
                      description: widget.exportDescription,
                      iconPath: 'assets/svg/file.svg',
                      actionButtonText: t.export,
                      onAction: widget.onExport,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTooltip(BuildContext context) {
    return CoconutToolTip(
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
          children: [
            TextSpan(
              text: '${t.labels_management_screen.tooltip.title}\n',
              style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
            ),
            TextSpan(
              text: '${t.labels_management_screen.tooltip.description}\n\n',
              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
            ),
            TextSpan(
              text: '${t.labels_management_screen.tooltip.supported_title}\n',
              style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
            ),
            TextSpan(
              text: t.labels_management_screen.tooltip.supported_list,
              style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(BuildContext context) {
    return Positioned(
      top: _tooltipIconPosition!.dy + _tooltipIconSize!.height - 10,
      right: 18,
      child: GestureDetector(
        onTap: _removeTooltip,
        child: ClipPath(
          clipper: RightTriangleBubbleClipper(),
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.68,
            padding: const EdgeInsets.only(top: 28, left: 16, right: 16, bottom: 12),
            color: context.coconutColors.popoverBackground,
            child: Text(
              t.labels_management_screen.description,
              style: CoconutTypography.body3_12.copyWith(color: context.coconutColors.popoverText, height: 1.3),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToActionScreen({
    required BuildContext context,
    required String title,
    required String description,
    required String iconPath,
    required String actionButtonText,
    required VoidCallback onAction,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => _LabelManagementActionScreen(
              title: title,
              description: description,
              iconPath: iconPath,
              actionButtonText: actionButtonText,
              onAction: onAction,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(position: AnimationUtil.buildSlideInAnimation(animation), child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  void _navigateToImportFilePicker(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => _LabelImportFilePickerScreen(
              onFileSelected: (filePath) {
                widget.onImport(filePath);
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(position: AnimationUtil.buildSlideInAnimation(animation), child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }
}

class _LabelManagementActionScreen extends StatelessWidget {
  final String title;
  final String description;
  final String iconPath;
  final String actionButtonText;
  final VoidCallback onAction;

  const _LabelManagementActionScreen({
    required this.title,
    required this.description,
    required this.iconPath,
    required this.actionButtonText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(title: title, context: context),
      body: Stack(
        children: [
          _buildContentView(context),
          Align(
            alignment: Alignment.bottomCenter,
            child: FixedBottomButton(text: actionButtonText, onButtonClicked: onAction),
          ),
        ],
      ),
    );
  }

  Widget _buildContentView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CoconutToolTip(
            backgroundColor: context.coconutColors.surface,
            borderColor: context.coconutColors.surface,
            icon: SvgPicture.asset(
              'assets/svg/circle-info.svg',
              width: 20,
              colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
            ),
            tooltipType: CoconutTooltipType.fixed,
            richText: RichText(
              textAlign: TextAlign.start,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title\n\n',
                    style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                  ),
                  TextSpan(
                    text: description,
                    style: CoconutTypography.body1_16.setColor(context.coconutColors.secondaryText),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: context.coconutColors.primary.withOpacity(0.1)),
            child: SvgPicture.asset(
              iconPath,
              width: 40,
              height: 40,
              colorFilter: ColorFilter.mode(context.coconutColors.primary, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 150),
        ],
      ),
    );
  }
}

class _LabelImportFilePickerScreen extends StatefulWidget {
  final ValueChanged<String> onFileSelected;

  const _LabelImportFilePickerScreen({required this.onFileSelected});

  @override
  State<_LabelImportFilePickerScreen> createState() => _LabelImportFilePickerScreenState();
}

class _LabelImportFilePickerScreenState extends State<_LabelImportFilePickerScreen> {
  late Future<List<File>> _filesFuture;
  int _swipedItemIndex = -1;

  @override
  void initState() {
    super.initState();
    _filesFuture = LabelJsonLManager().getImportableLabelFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(title: t.wallet_info_screen.import_labels, context: context),
      body: FutureBuilder<List<File>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
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
                      colorFilter: ColorFilter.mode(context.coconutColors.primary, BlendMode.srcIn),
                    ),
                  ),
                  CoconutLayout.spacing_400h,
                  Text(
                    t.labels_management_screen.file.not_found,
                    style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                  ),
                ],
              ),
            );
          }

          final files = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: files.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final file = files[index];
              return _FileListItemCard(
                file: file,
                isSwiped: _swipedItemIndex == index,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onFileSelected(file.path);
                },
                onSwipeChanged: (isSwiped) {
                  setState(() {
                    if (isSwiped) {
                      _swipedItemIndex = index;
                    } else {
                      _swipedItemIndex = -1;
                    }
                  });
                },
                onDeleteTriggered: () {
                  setState(() {
                    _swipedItemIndex = index;
                  });
                  _deleteFile(file, index);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _deleteFile(File file, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: t.labels_management_screen.file.delete,
            description: t.labels_management_screen.file.delete_description(fileName: p.basename(file.path)),
            onTapRight: () => Navigator.of(dialogContext).pop(true),
            onTapLeft: () => Navigator.of(dialogContext).pop(false),
            rightButtonText: t.delete,
            rightButtonColor: context.coconutColors.danger,
            leftButtonText: t.cancel,
          ),
    );

    if (confirmed == true) {
      try {
        await file.delete();
        CoconutToast.showToast(
          context: context,
          text: t.labels_management_screen.file.delete_success,
          level: CoconutToastLevel.success,
        );
        _refreshFiles();
      } catch (e) {
        _resetSwipeState();
        CoconutToast.showToast(
          context: context,
          text: t.labels_management_screen.file.delete_failed,
          level: CoconutToastLevel.error,
        );
      }
    } else {
      _resetSwipeState();
    }
  }

  void _resetSwipeState() {
    setState(() {
      _swipedItemIndex = -1;
    });
  }

  void _refreshFiles() {
    setState(() {
      _filesFuture = LabelJsonLManager().getImportableLabelFiles();
      _swipedItemIndex = -1;
    });
  }
}

class _FileListItemCard extends StatefulWidget {
  final File file;
  final bool isSwiped;
  final VoidCallback onTap;
  final ValueChanged<bool> onSwipeChanged;
  final VoidCallback onDeleteTriggered;

  const _FileListItemCard({
    required this.file,
    required this.isSwiped,
    required this.onTap,
    required this.onSwipeChanged,
    required this.onDeleteTriggered,
  });

  @override
  State<_FileListItemCard> createState() => _FileListItemCardState();
}

class _FileListItemCardState extends State<_FileListItemCard> with SingleTickerProviderStateMixin {
  late double _dragOffset;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isAnimating = false;
  final double _swipeThreshold = 0.2;
  final double _swipeStopPosition = 0.25;

  @override
  void initState() {
    super.initState();
    _dragOffset = 0;
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _animation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_FileListItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSwiped != widget.isSwiped && !widget.isSwiped) {
      _animateToOriginalPosition();
    }
  }

  void _animationListener() {
    if (mounted) {
      setState(() {
        _dragOffset = _animation.value;
      });
    }
  }

  void _animateToOriginalPosition() {
    _isAnimating = true;
    _animation.removeListener(_animationListener);
    _animationController.stop();
    _animationController.reset();

    _animation = Tween<double>(
      begin: _dragOffset,
      end: 0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animation.addListener(_animationListener);
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _animation.removeListener(_animationListener);
        _isAnimating = false;
      }
    });
    _animationController.forward();
  }

  void _animateToDeletePosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    _isAnimating = true;
    _animation.removeListener(_animationListener);
    _animationController.stop();
    _animationController.reset();

    _animation = Tween<double>(
      begin: _dragOffset,
      end: -screenWidth * _swipeStopPosition,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animation.addListener(_animationListener);
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animation.removeListener(_animationListener);
        _isAnimating = false;
      }
    });
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fileName = p.basename(widget.file.path);
    final modifiedDate = DateFormat('yyyy-MM-dd HH:mm').format(widget.file.lastModifiedSync());

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: context.coconutColors.danger,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: SvgPicture.asset(
              'assets/svg/trash.svg',
              width: 24,
              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            if (_dragOffset != 0) {
              widget.onSwipeChanged(false);
            } else {
              widget.onTap();
            }
          },
          onHorizontalDragUpdate: (details) {
            if (_isAnimating) return;
            if (details.delta.dx < 0) {
              setState(() {
                _dragOffset = (_dragOffset + details.delta.dx).clamp(-screenWidth, 0);
              });
            } else if (details.delta.dx > 0 && _dragOffset < 0) {
              setState(() {
                _dragOffset = (_dragOffset + details.delta.dx).clamp(-screenWidth, 0);
              });
            }
          },
          onHorizontalDragEnd: (details) {
            if (_isAnimating) return;
            final swipeThresholdPx = screenWidth * _swipeThreshold;
            if (_dragOffset.abs() >= swipeThresholdPx) {
              widget.onDeleteTriggered();
              _animateToDeletePosition();
            } else {
              widget.onSwipeChanged(false);
              _animateToOriginalPosition();
            }
          },
          child: Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Material(
              color: context.coconutColors.surface,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/svg/file.svg',
                      width: 24,
                      colorFilter: ColorFilter.mode(context.coconutColors.primary, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: CoconutTypography.body1_16,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            modifiedDate,
                            style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
