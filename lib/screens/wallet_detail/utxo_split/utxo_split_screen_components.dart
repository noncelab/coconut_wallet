part of 'utxo_split_screen.dart';

class _HeaderTitleErrorText extends StatelessWidget {
  const _HeaderTitleErrorText();

  @override
  Widget build(BuildContext context) {
    return Selector<
      UtxoSplitViewModel,
      ({
        String? headerTitleErrorMessage,
        UtxoSplitMethod? selectedMethod,
        bool showSplitResultBox,
        int manualSplitItemsLength,
      })
    >(
      selector:
          (_, vm) => (
            headerTitleErrorMessage: vm.headerTitleErrorMessage,
            selectedMethod: vm.selectedMethod,
            showSplitResultBox: vm.showSplitResultBox,
            manualSplitItemsLength: vm.manualSplitItems.length,
          ),
      builder: (context, data, _) {
        final headerTitleErrorMessage = data.headerTitleErrorMessage;
        final selectedMethod = data.selectedMethod;
        final vmShowSplitResultBox = data.showSplitResultBox;
        final vm = context.read<UtxoSplitViewModel>();
        final focusNodes = [
          vm.amountFocusNode,
          vm.splitCountFocusNode,
          ...vm.manualSplitItems.expand((item) => [item.amountFocusNode, item.countFocusNode]),
        ];

        return AnimatedBuilder(
          animation: Listenable.merge(focusNodes),
          builder: (context, _) {
            final isFocused = focusNodes.any((node) => node.hasFocus);

            if (headerTitleErrorMessage == null || headerTitleErrorMessage.isEmpty) {
              double height = 20;
              if (selectedMethod == UtxoSplitMethod.manually) {
                final isResultBoxActuallyVisible = vmShowSplitResultBox && !isFocused;
                height = isResultBoxActuallyVisible ? 16 : 24;
              }
              return SizedBox(height: height);
            }

            return Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  headerTitleErrorMessage,
                  style: CoconutTypography.caption_10.setColor(CoconutColors.hotPink).copyWith(height: 1.0),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SplitResultContent extends StatefulWidget {
  final bool showSkeletonResultBox;
  final bool usePreview;
  final UtxoSplitResult? splitResult;
  final String? splitOutputText;
  final String splitSummaryTitle;

  const _SplitResultContent({
    super.key,
    required this.showSkeletonResultBox,
    required this.usePreview,
    required this.splitResult,
    required this.splitOutputText,
    required this.splitSummaryTitle,
  });

  @override
  State<_SplitResultContent> createState() => _SplitResultContentState();
}

class _SplitResultContentState extends State<_SplitResultContent> with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;
  int _lastLineCount = 2;
  String _lastTitle = '';

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    if (widget.splitOutputText != null) {
      _lastLineCount = widget.splitOutputText!.split('\n').length;
    }
    if (widget.splitSummaryTitle.isNotEmpty) {
      _lastTitle = widget.splitSummaryTitle;
    }
  }

  @override
  void didUpdateWidget(covariant _SplitResultContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.splitOutputText != null) {
      _lastLineCount = widget.splitOutputText!.split('\n').length;
    }
    if (widget.splitSummaryTitle.isNotEmpty) {
      _lastTitle = widget.splitSummaryTitle;
    }
    final isPreparing = widget.showSkeletonResultBox;
    final isReady = widget.splitResult != null || widget.usePreview;
    final isDone = isReady && !isPreparing;

    if (isDone) {
      _lottieController.stop();
      _lottieController.value = 1;
    } else if (isPreparing && !_lottieController.isAnimating) {
      _lottieController.repeat(period: _lottieController.duration ?? const Duration(seconds: 1));
    } else if (!isPreparing && !isReady) {
      _lottieController.stop();
      _lottieController.reset();
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPreparing = widget.showSkeletonResultBox;
    final isReady = widget.splitResult != null || widget.usePreview;
    final isDone = isReady && !isPreparing;

    if (!isPreparing && !isReady) {
      return const SizedBox.shrink();
    }

    return FixedTextScale(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSummaryCard(
            lottieController: _lottieController,
            onLottieLoaded: (composition) {
              _lottieController.duration = composition.duration;
              if (isDone) {
                _lottieController.value = 1;
              } else if (isPreparing && !_lottieController.isAnimating) {
                _lottieController.repeat(period: _lottieController.duration ?? composition.duration);
              } else if (!isPreparing) {
                _lottieController.reset();
              }
            },
            child:
                isDone
                    ? const _SplitResultReadyContent(key: ValueKey('split-ready'))
                    : _SplitResultSkeletonContent(
                      key: const ValueKey('split-skeleton'),
                      lineCount: _lastLineCount,
                      titleText: _lastTitle,
                    ),
          ),
          Visibility(
            visible: widget.usePreview,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CoconutLayout.spacing_200h,
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    t.split_utxo_screen.expected_result.above_is_expected,
                    style: CoconutTypography.caption_10.setColor(CoconutColors.gray400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitResultReadyContent extends StatelessWidget {
  const _SplitResultReadyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<UtxoSplitViewModel, ({String splitSummaryTitle, String? splitOutputText, String previewFeeText})>(
      selector:
          (_, vm) => (
            splitSummaryTitle: vm.splitSummaryTitle,
            splitOutputText: vm.splitOutputText,
            previewFeeText: vm.feePickerDisplayText,
          ),
      builder: (context, data, _) {
        final splitSummaryTitle = data.splitSummaryTitle.replaceAllMapped(
          RegExp(r'(\S+)'),
          (match) => match[0]!.split('').join('\u200D'),
        );
        final splitOutputText = data.splitOutputText;
        final previewFeeText = data.previewFeeText;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(splitSummaryTitle, style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white)),
            CoconutLayout.spacing_200h,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.split_utxo_screen.expected_result.new_utxos,
                  style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
                ),
                Expanded(
                  child: Text(
                    splitOutputText ?? '-',
                    style: CoconutTypography.body1_16.setColor(CoconutColors.white),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            CoconutLayout.spacing_100h,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.split_utxo_screen.expected_result.fee,
                  style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
                ),
                Text(previewFeeText, style: CoconutTypography.body1_16.setColor(CoconutColors.white)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SplitResultSkeletonContent extends StatelessWidget {
  final int lineCount;
  final String titleText;

  const _SplitResultSkeletonContent({super.key, required this.lineCount, required this.titleText});

  @override
  Widget build(BuildContext context) {
    int displayLineCount = lineCount;
    if (displayLineCount > 10) displayLineCount = 10;
    if (displayLineCount < 1) displayLineCount = 1;

    final dummyTitle = titleText.isNotEmpty ? titleText : ' ';
    final dummyOutput = List.generate(displayLineCount, (index) => '0').join('\n');

    return Shimmer.fromColors(
      baseColor: CoconutColors.gray700,
      highlightColor: CoconutColors.gray600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Text(dummyTitle, style: CoconutTypography.body1_16_Bold.copyWith(color: Colors.transparent)),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int titleLines = 1;
                    final span = TextSpan(text: dummyTitle, style: CoconutTypography.body1_16_Bold);
                    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
                    tp.layout(maxWidth: constraints.maxWidth);
                    titleLines = tp.computeLineMetrics().length;
                    if (titleLines < 1) titleLines = 1;

                    return Column(
                      mainAxisAlignment: titleLines > 1 ? MainAxisAlignment.spaceAround : MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(titleLines, (index) {
                        return Container(
                          width:
                              index == titleLines - 1 && titleLines > 1 ? constraints.maxWidth * 0.6 : double.infinity,
                          height: 18,
                          decoration: BoxDecoration(color: CoconutColors.white, borderRadius: BorderRadius.circular(4)),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_200h,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Text(
                    t.split_utxo_screen.expected_result.new_utxos,
                    style: CoconutTypography.body2_14.copyWith(color: Colors.transparent),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(color: CoconutColors.white, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        dummyOutput,
                        style: CoconutTypography.body1_16.copyWith(color: Colors.transparent),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment:
                            displayLineCount > 1 ? MainAxisAlignment.spaceAround : MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(displayLineCount, (index) {
                          return Container(
                            width: MediaQuery.sizeOf(context).width / 2,
                            height: 18,
                            decoration: BoxDecoration(
                              color: CoconutColors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_100h,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Stack(
                children: [
                  Text(
                    t.split_utxo_screen.expected_result.fee,
                    style: CoconutTypography.body2_14.copyWith(color: Colors.transparent),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(color: CoconutColors.white, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ],
              ),
              Stack(
                children: [
                  Text('0', style: CoconutTypography.body1_16.copyWith(color: Colors.transparent)),
                  Container(width: 92),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 92,
                        height: 18,
                        decoration: BoxDecoration(color: CoconutColors.white, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.radius = 8.0,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final path =
        Path()
          ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));
    final dashedPath = Path();

    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        dashedPath.addPath(measurePath.extractPath(distance, distance + dashWidth), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ManualSplitListItem extends StatefulWidget {
  final int index;
  final ManualSplitItem item;
  final UtxoSplitViewModel viewModel;
  final bool isDeleteButtonVisible;
  final ValueChanged<bool> onDeleteButtonVisibilityChanged;

  const _ManualSplitListItem({
    super.key,
    required this.index,
    required this.item,
    required this.viewModel,
    required this.isDeleteButtonVisible,
    required this.onDeleteButtonVisibilityChanged,
  });

  @override
  State<_ManualSplitListItem> createState() => _ManualSplitListItemState();
}

class _ManualSplitListItemState extends State<_ManualSplitListItem> with TickerProviderStateMixin {
  late AnimationController _swipeController;
  late AnimationController _entranceController;
  late AnimationController _deleteController;
  final double _actionWidth = 60.0;
  bool _isDeleting = false;
  bool _isDeleteButtonVisible = false;

  void _handleFocusChanged() {
    Logger.log('-->handleFocusChanged');
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _isDeleteButtonVisible = widget.isDeleteButtonVisible;
    _swipeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _deleteController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    widget.item.countFocusNode.addListener(_handleFocusChanged);
    _entranceController.forward();
  }

  void setDeleteButtonVisible(bool isVisible) {
    if (_isDeleteButtonVisible == isVisible) return;

    setState(() {
      _isDeleteButtonVisible = isVisible;
    });
    widget.onDeleteButtonVisibilityChanged(isVisible);

    if (!isVisible) {
      widget.item.amountFocusNode.unfocus();
      widget.item.countFocusNode.unfocus();
      _swipeController.reverse();
      return;
    }

    widget.item.amountFocusNode.unfocus();
    widget.item.countFocusNode.unfocus();
    _swipeController.forward();
  }

  @override
  void didUpdateWidget(covariant _ManualSplitListItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDeleteButtonVisible != oldWidget.isDeleteButtonVisible) {
      _isDeleteButtonVisible = widget.isDeleteButtonVisible;
      if (_isDeleteButtonVisible) {
        _swipeController.forward();
      } else {
        _swipeController.reverse();
      }
    }

    if (widget.viewModel.manualSplitItems.length <= 1 && _swipeController.value > 0) {
      if (_isDeleteButtonVisible) {
        widget.onDeleteButtonVisibilityChanged(false);
        _isDeleteButtonVisible = false;
      }
      _swipeController.reverse();
    }
  }

  @override
  void dispose() {
    widget.item.amountFocusNode.removeListener(_handleFocusChanged);
    widget.item.countFocusNode.removeListener(_handleFocusChanged);
    _swipeController.dispose();
    _entranceController.dispose();
    _deleteController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.viewModel.manualSplitItems.length <= 1 || _isDeleting) return;

    final delta = details.primaryDelta;
    if (delta == null) return;

    if (delta >= 0) {
      return;
    }

    if (!_isDeleteButtonVisible) {
      setDeleteButtonVisible(true);
    }

    _swipeController.value = (_swipeController.value - (delta / _actionWidth)).clamp(0.0, 1.0);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.viewModel.manualSplitItems.length <= 1 || _isDeleting) return;
    if (_swipeController.value > 0.5 || details.primaryVelocity! < -500) {
      _swipeController.forward();
    } else {
      _swipeController.reverse();
    }
  }

  bool _isManualSplitDecrementButtonActive() {
    final countText = widget.viewModel.manualSplitItems[widget.index].countController.text;
    final count = num.tryParse(countText);
    final isActive = !_isDeleteButtonVisible && count != null && count > 1;

    return isActive;
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _entranceController,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-1.0, 0.0),
              ).animate(CurvedAnimation(parent: _deleteController, curve: Curves.easeIn)),
              child: GestureDetector(
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    AnimatedBuilder(
                      animation: _swipeController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(-_swipeController.value * _actionWidth, 0),
                          child: child,
                        );
                      },
                      child: Container(
                        color: CoconutColors.black,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: CoconutTextField(
                                enabled: !_isDeleteButtonVisible,
                                controller: widget.item.amountController,
                                focusNode: widget.item.amountFocusNode,
                                style: CoconutTextFieldStyle.underline,
                                fontSize: 18,
                                activeColor: CoconutColors.white,
                                placeholderColor: CoconutColors.gray500,
                                errorColor: CoconutColors.hotPink,
                                onChanged: (_) {},
                                onEditingComplete: () => widget.item.amountFocusNode.unfocus(),
                                textInputAction: TextInputAction.done,
                                textInputType: const TextInputType.numberWithOptions(decimal: true),
                                textInputFormatter: [
                                  _DecimalTextInputFormatter(
                                    decimalRange: widget.viewModel.currentUnit.isBtcUnit ? 8 : 0,
                                  ),
                                ],
                                placeholderText: widget.viewModel.currentUnit.isBtcUnit ? '0.00' : '0',
                                maxLines: 1,
                                padding: const EdgeInsets.only(left: 4, right: 4, top: 4, bottom: 4),
                                unfocusOnTapOutside: true,
                                suffix: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    widget.viewModel.currentUnit.symbol,
                                    style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: widget.item.countController,
                              builder: (context, value, _) {
                                return _SplitCountStepButton(
                                  icon: Icons.remove,
                                  isActive: _isManualSplitDecrementButtonActive(),
                                  onTap: () {
                                    widget.viewModel.decrementManualSplitCount(widget.index);
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 60,
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: widget.item.countController,
                                builder: (context, value, _) {
                                  final inputText = value.text;
                                  final hasFocus = widget.item.countFocusNode.hasFocus;
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CoconutTextField(
                                        height: 40,
                                        fontHeight: 1,
                                        borderRadius: 8,
                                        enabled: !_isDeleteButtonVisible,
                                        controller: widget.item.countController,
                                        focusNode: widget.item.countFocusNode,
                                        textAlign: TextAlign.center,
                                        backgroundColor: hasFocus ? CoconutColors.gray800 : Colors.transparent,
                                        activeColor: CoconutColors.white,
                                        placeholderColor: CoconutColors.gray500,
                                        fontSize: 24,
                                        isVisibleBorder: false,
                                        onChanged: (_) {},
                                        onEditingComplete: () => widget.item.countFocusNode.unfocus(),
                                        textInputAction: TextInputAction.done,
                                        textInputType: TextInputType.number,
                                        textInputFormatter: [FilteringTextInputFormatter.digitsOnly],
                                        maxLines: 1,
                                        unfocusOnTapOutside: true,
                                        padding: EdgeInsets.zero,
                                        placeholderText: '',
                                      ),
                                      if (inputText.isEmpty && !hasFocus)
                                        IgnorePointer(
                                          child: Text(
                                            '1',
                                            style: CoconutTypography.heading3_21_NumberBold.copyWith(
                                              color: CoconutColors.gray500,
                                              fontSize: 24,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            _SplitCountStepButton(
                              icon: Icons.add,
                              isActive: !_isDeleteButtonVisible,
                              onTap: () {
                                widget.viewModel.incrementManualSplitCount(widget.index);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.viewModel.manualSplitItems.length > 1)
                      Positioned(
                        right: 0,
                        child: AnimatedBuilder(
                          animation: _swipeController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_actionWidth * (1 - _swipeController.value), 0),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CoconutLayout.spacing_300w,
                              TapRegion(
                                onTapOutside: (_) {
                                  if (!_isDeleteButtonVisible || _isDeleting) return;
                                  setDeleteButtonVisible(false);
                                },
                                child: RippleEffect(
                                  onTap: () async {
                                    if (_isDeleting) return;
                                    setState(() => _isDeleting = true);

                                    await _deleteController.forward();
                                    if (!mounted) return;

                                    await _entranceController.reverse();
                                    if (!mounted) return;

                                    final currentIndex = widget.viewModel.manualSplitItems.indexOf(widget.item);
                                    if (currentIndex != -1) {
                                      widget.viewModel.removeManualSplitItem(currentIndex);
                                    }
                                  },
                                  borderRadius: 12,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: CoconutColors.hotPink,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: SvgPicture.asset(
                                      'assets/svg/trash.svg',
                                      width: 20,
                                      height: 20,
                                      colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DecimalTextInputFormatter extends TextInputFormatter {
  final int decimalRange;

  _DecimalTextInputFormatter({required this.decimalRange});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;

    if (text.isEmpty) return newValue;

    if (decimalRange == 0 && text.contains('.')) {
      return oldValue;
    }

    if (text.startsWith('.')) {
      text = '0$text';
      return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: newValue.selection.end + 1));
    }

    if (text.length > 1 && text.startsWith('0') && !text.startsWith('0.')) {
      return oldValue;
    }

    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return oldValue;
    }

    if (text.contains('.')) {
      if (text.split('.')[1].length > decimalRange) {
        return oldValue;
      }
    }

    return newValue;
  }
}

class _SplitCountStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _SplitCountStepButton({required this.icon, required this.onTap, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    return RippleEffect(
      onTap: isActive ? onTap : null,
      borderRadius: 24,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? CoconutColors.gray800 : CoconutColors.gray850,
          shape: BoxShape.circle,
          border: Border.all(color: isActive ? CoconutColors.gray300 : CoconutColors.gray700),
        ),
        child: Icon(icon, color: isActive ? CoconutColors.white : CoconutColors.gray500),
      ),
    );
  }
}
