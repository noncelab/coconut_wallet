import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_bucket.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/utxo_amount_format_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/widgets/features/transaction/icon/pending_transaction_lottie_icon.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

class UtxoBucketCardRow extends StatelessWidget {
  final UtxoBucket bucket;
  final int index;
  final BitcoinUnit currentUnit;
  final int dustThreshold;
  final ValueListenable<int> activeIndexListenable;
  final ValueListenable<({int bucket, int card})?>? restoredStateListenable;
  final bool isSelectionMode;
  final Set<String> selectedUtxoIds;
  final Set<String> reusedAddresses;
  final Set<String> suspiciousUtxoIds;
  final void Function(UtxoState) onTapUtxo;
  final void Function(UtxoState)? onLongPressUtxo;
  final void Function(int)? setActiveIndex;

  const UtxoBucketCardRow({
    super.key,
    required this.bucket,
    required this.index,
    required this.currentUnit,
    required this.dustThreshold,
    required this.activeIndexListenable,
    this.restoredStateListenable,
    required this.isSelectionMode,
    required this.selectedUtxoIds,
    required this.reusedAddresses,
    required this.suspiciousUtxoIds,
    required this.onTapUtxo,
    this.onLongPressUtxo,
    this.setActiveIndex,
  });

  static const double rowHeight = 210 + 24 + 4 + 4;

  Widget _buildCoinStack() {
    if (restoredStateListenable != null) {
      return ValueListenableBuilder<({int bucket, int card})?>(
        valueListenable: restoredStateListenable!,
        builder: (_, restored, __) {
          final restoredMatch = restored != null && restored.bucket == index;
          final initialFocusedCardIndex = (restored != null && restored.bucket == index) ? restored.card : null;

          return ValueListenableBuilder<int>(
            valueListenable: activeIndexListenable,
            builder: (_, active, __) {
              final isExpanded = restoredMatch || active == index;
              final scrollOffset = restoredMatch ? initialFocusedCardIndex!.toDouble() : null;
              if (restoredMatch && active != index) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (activeIndexListenable.value != index) {
                    setActiveIndex!(index);
                  }
                });
              }

              return _CoinStack(
                utxos: bucket.utxos,
                currentUnit: currentUnit,
                dustThreshold: dustThreshold,
                isExpanded: isExpanded,
                isSelectionMode: isSelectionMode,
                selectedUtxoIds: selectedUtxoIds,
                reusedAddresses: reusedAddresses,
                suspiciousUtxoIds: suspiciousUtxoIds,
                initialScrollOffset: scrollOffset,
                onTap: onTapUtxo,
                onLongPress: onLongPressUtxo,
              );
            },
          );
        },
      );
    }
    return ValueListenableBuilder<int>(
      valueListenable: activeIndexListenable,
      builder: (_, active, __) {
        return _CoinStack(
          utxos: bucket.utxos,
          currentUnit: currentUnit,
          dustThreshold: dustThreshold,
          isExpanded: active == index,
          isSelectionMode: isSelectionMode,
          selectedUtxoIds: selectedUtxoIds,
          reusedAddresses: reusedAddresses,
          suspiciousUtxoIds: suspiciousUtxoIds,
          initialScrollOffset: null,
          onTap: onTapUtxo,
          onLongPress: onLongPressUtxo,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: rowHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: activeIndexListenable,
            builder:
                (_, active, __) => _Summary(
                  bucket: bucket,
                  currentUnit: currentUnit,
                  dustThreshold: dustThreshold,
                  isActive: active == index,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildCoinStack()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final UtxoBucket bucket;
  final BitcoinUnit currentUnit;
  final int dustThreshold;
  final bool isActive;

  const _Summary({
    required this.bucket,
    required this.currentUnit,
    required this.dustThreshold,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final totalSats = bucket.utxos.fold<int>(0, (sum, u) => sum + u.amount);
    final isDustBucket = bucket.label == 'dust';
    final textColor = isActive ? context.coconutColors.primaryText : context.coconutColors.mutedText;
    return Align(
      alignment: Alignment.center,
      child: Text(
        '${bucket.utxos.length} coins • ${formatUtxoAmountForDisplay(totalSats, currentUnit, dustThreshold: dustThreshold, forceSats: isDustBucket)}',
        style: CoconutTypography.body2_14_NumberBold.setColor(textColor),
      ),
    );
  }
}

class _CoinStack extends StatefulWidget {
  final List<UtxoState> utxos;
  final BitcoinUnit currentUnit;
  final int dustThreshold;
  final bool isExpanded;
  final bool isSelectionMode;
  final Set<String> selectedUtxoIds;
  final Set<String> reusedAddresses;
  final Set<String> suspiciousUtxoIds;
  final double? initialScrollOffset;
  final void Function(UtxoState) onTap;
  final void Function(UtxoState)? onLongPress;

  const _CoinStack({
    required this.utxos,
    required this.currentUnit,
    required this.dustThreshold,
    required this.isExpanded,
    required this.isSelectionMode,
    required this.selectedUtxoIds,
    required this.reusedAddresses,
    required this.suspiciousUtxoIds,
    this.initialScrollOffset,
    required this.onTap,
    this.onLongPress,
  });

  static const double coinSize = 132.0;

  @override
  State<_CoinStack> createState() => _CoinStackState();
}

class _CoinStackState extends State<_CoinStack> {
  late double _scrollOffset;

  static const double _coinSize = _CoinStack.coinSize;

  @override
  void initState() {
    super.initState();
    _scrollOffset = widget.initialScrollOffset ?? 0;
  }

  static const double _collapsedOverlap = 24.0;
  static const double _expandedOverlap = 55.0;
  static const double _leftOverlap = 20.0;
  static const int _maxCollapsed = 5;
  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeOutCubic;
  static const double _dragSensitivity = 0.015;
  static const double _focusedScale = 1.08;

  @override
  void didUpdateWidget(covariant _CoinStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isExpanded && oldWidget.isExpanded) {
      _scrollOffset = 0;
    } else if (widget.initialScrollOffset != null && widget.isExpanded) {
      _scrollOffset = widget.initialScrollOffset!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.utxos.length;
    final isExp = widget.isExpanded;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final centerX = (w - _coinSize) / 2;

        final previewCount = total.clamp(0, _maxCollapsed);
        final extraCount = total - previewCount;
        final showBadge = extraCount > 0 && !isExp;

        const badgeGap = 8.0;
        final badgeW = (extraCount > 0 && !isExp) ? 50.0 : 0.0;
        final firstCoinBillOffset =
            (!isExp && total > 0 && UtxoCoinCard.isBillShape(widget.utxos[0].amount)) ? _coinSize * 0.175 : 0.0;
        final collapsedBaseX = centerX - (showBadge ? badgeW + badgeGap + firstCoinBillOffset : 0);

        final currentIndex = _scrollOffset.round().clamp(0, total - 1);
        final List<int> visibleIndices;
        if (isExp) {
          final rightSpace = w - centerX - _coinSize;
          final maxAfter = (rightSpace / _expandedOverlap).floor().clamp(1, total);
          final afterCount = (total - currentIndex - 1).clamp(0, maxAfter + 1);
          final maxBefore = (centerX / _leftOverlap).floor().clamp(0, total);
          final beforeCount = (currentIndex).clamp(0, maxBefore + 1);
          final startIdx = (currentIndex - beforeCount).clamp(0, total - 1);
          final endIdx = (currentIndex + afterCount).clamp(0, total - 1);
          visibleIndices = [for (int i = startIdx; i <= endIdx; i++) i];
        } else {
          visibleIndices = [for (int i = 0; i < previewCount; i++) i];
        }

        double getLeft(int i) {
          if (isExp) {
            final pos = i - currentIndex;
            final overlap = pos <= 0 ? _leftOverlap : _expandedOverlap;
            return centerX + pos * overlap;
          }
          return centerX + i * _collapsedOverlap;
        }

        final renderOrder = List<int>.from(visibleIndices)..sort((a, b) {
          final da = (a - _scrollOffset).abs();
          final db = (b - _scrollOffset).abs();
          if (da != db) return db.compareTo(da);
          return a.compareTo(b);
        });

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate:
              isExp && total > 1
                  ? (details) {
                    final maxOffset = (total - 1).toDouble();
                    setState(() {
                      _scrollOffset = (_scrollOffset - details.delta.dx * _dragSensitivity).clamp(0.0, maxOffset);
                    });
                  }
                  : null,
          onHorizontalDragEnd: null,
          child: SizedBox(
            height: _coinSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (extraCount > 0)
                  AnimatedPositioned(
                    duration: _animDuration,
                    curve: _animCurve,
                    left: collapsedBaseX,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: _animDuration,
                        opacity: isExp ? 0.0 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: context.coconutColors.surfaceInfoChip,
                          ),
                          child: Text(
                            '+$extraCount',
                            style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.primaryText),
                          ),
                        ),
                      ),
                    ),
                  ),
                for (final i in renderOrder)
                  AnimatedPositioned(
                    key: ValueKey(i),
                    duration: _animDuration,
                    curve: _animCurve,
                    left: getLeft(i) - (UtxoCoinCard.isBillShape(widget.utxos[i].amount) ? _coinSize * 0.175 : 0),
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: AnimatedScale(
                        scale: (isExp && i == currentIndex) ? _focusedScale : 1.0,
                        duration: _animDuration,
                        curve: _animCurve,
                        child: UtxoCoinCard(
                          utxo: widget.utxos[i],
                          size: _coinSize,
                          compact: !isExp,
                          isFocused: isExp && i == currentIndex,
                          isSelected: widget.selectedUtxoIds.contains(widget.utxos[i].utxoId),
                          isSelectionMode: widget.isSelectionMode,
                          currentUnit: widget.currentUnit,
                          dustThreshold: widget.dustThreshold,
                          isAddressReused: widget.reusedAddresses.contains(widget.utxos[i].to),
                          isSuspiciousDust: widget.suspiciousUtxoIds.contains(widget.utxos[i].utxoId),
                          onTap: () => widget.onTap(widget.utxos[i]),
                          onLongPress: widget.onLongPress != null ? () => widget.onLongPress!(widget.utxos[i]) : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class UtxoCoinCard extends StatefulWidget {
  final UtxoState utxo;
  final double size;
  final bool compact;
  final bool isFocused;
  final bool isSelected;
  final bool isSelectionMode;
  final BitcoinUnit currentUnit;
  final int dustThreshold;
  final bool isAddressReused;
  final bool isSuspiciousDust;
  final bool showSelectedCheckIcon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const UtxoCoinCard({
    super.key,
    required this.utxo,
    required this.size,
    this.compact = false,
    this.isFocused = true,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.currentUnit,
    required this.dustThreshold,
    this.isAddressReused = false,
    this.isSuspiciousDust = false,
    this.showSelectedCheckIcon = true,
    required this.onTap,
    this.onLongPress,
  });

  static const int _billThreshold = 10_000_000; // 0.1 BTC
  static bool isBillShape(int sats) => sats >= _billThreshold;

  static Widget _buildCardContent(
    double size,
    bool isLarge,
    bool isFocused,
    Color iconColor,
    double unfocusedIconOpacity,
    Color amountTextColor,
    Color timestampTextColor,
    UtxoState utxo,
    BitcoinUnit currentUnit,
    int dustThreshold, {
    bool isSuspiciousDust = false,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(size * (isSuspiciousDust ? 0.25 : 0.2)),
            child: Opacity(
              opacity: isFocused ? 0.2 : unfocusedIconOpacity,
              child: SvgPicture.asset(
                isSuspiciousDust ? FeatureUtxoIconPath.dust : FeatureWalletIconPath.bitcoin,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatUtxoBalanceForTooltip(
                    utxo.amount,
                    currentUnit,
                    dustThreshold: dustThreshold,
                    isDustBucket: utxo.amount <= dustThreshold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (isLarge ? CoconutTypography.heading4_18_NumberBold : CoconutTypography.body1_16_NumberBold)
                      .setColor(amountTextColor.withValues(alpha: isFocused ? 1 : 0.4)),
                ),
              ),
              if (isLarge) ...[
                const SizedBox(height: 4),
                Text(
                  DateTimeUtil.formatTimestamp(utxo.timestamp).join(' '),
                  textAlign: TextAlign.center,
                  style: CoconutTypography.caption_10.setColor(
                    timestampTextColor.withValues(alpha: isFocused ? 1 : 0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  State<UtxoCoinCard> createState() => _UtxoCoinCardState();
}

/// tier 색상의 명도가 카드 표면과 비슷하면 워터마크(비트코인 아이콘/스트로크)가 안 보이므로,
/// 표면과의 명도 차이를 최소한도 이상으로 밀어내 어떤 tier 색이든 고르게 보이도록 한다.
Color _legibleTierColor(Color tierColor, Color surface) {
  const minLightnessGap = 0.28;
  final hsl = HSLColor.fromColor(tierColor);
  final surfaceLightness = HSLColor.fromColor(surface).lightness;
  final gap = hsl.lightness - surfaceLightness;
  if (gap.abs() >= minLightnessGap) return tierColor;
  final pushDown = surfaceLightness >= 0.5;
  final targetLightness =
      pushDown
          ? (surfaceLightness - minLightnessGap).clamp(0.0, 1.0)
          : (surfaceLightness + minLightnessGap).clamp(0.0, 1.0);
  return hsl.withLightness(targetLightness).toColor();
}

class _UtxoCoinCardState extends State<UtxoCoinCard> {
  bool _isPressed = false;

  static const Duration _shrinkDuration = Duration(milliseconds: 100);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final isLarge = !widget.compact;
    final isBill = UtxoCoinCard.isBillShape(widget.utxo.amount);
    final cardWidth = isBill ? widget.size * 1.35 : widget.size;
    final cardHeight = isBill ? widget.size * 0.85 : widget.size;
    final tierTheme = context.watch<PreferenceProvider>().utxoTierTheme;
    final rawBucketCol = tierTheme.colorForSats(widget.utxo.amount, dustThreshold: widget.dustThreshold);
    final bucketCol = _legibleTierColor(rawBucketCol, colors.utxoOverviewCoinSurface);
    final bgColor =
        widget.isFocused ? bucketCol : Color.lerp(colors.background, bucketCol, colors.utxoOverviewCoinTintStrength)!;
    final iconColor = bgColor;
    final shadowBlur = widget.isFocused ? 16.0 : 6.0;
    final innerStrokeColor =
        widget.isSuspiciousDust
            ? Colors.transparent
            : bgColor.withValues(alpha: widget.isFocused ? 0.2 : colors.utxoOverviewCoinInnerStrokeOpacity);
    final coinBorder =
        widget.isSuspiciousDust
            ? null
            : widget.isAddressReused
            ? Border.all(color: colors.danger, width: 2)
            : (widget.isSelected ? Border.all(color: colors.utxoOverviewSelectedCoinBorder, width: 2) : null);

    final coin = GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: _shrinkDuration,
        curve: Curves.easeInOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                shape: isBill ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isBill ? BorderRadius.circular(8) : null,
                color: isBill ? colors.utxoOverviewBillSurface : colors.utxoOverviewCoinSurface,
                border: coinBorder,
                boxShadow: [
                  BoxShadow(
                    color: colors.shadowDefault,
                    blurRadius: shadowBlur,
                    spreadRadius: widget.isFocused ? 2 : 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  isBill
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            UtxoCoinCard._buildCardContent(
                              widget.size,
                              isLarge,
                              widget.isFocused,
                              iconColor,
                              colors.utxoOverviewCoinIconOpacity,
                              colors.primaryText,
                              colors.mutedText,
                              widget.utxo,
                              widget.currentUnit,
                              widget.dustThreshold,
                              isSuspiciousDust: widget.isSuspiciousDust,
                            ),
                            // coin 테두리
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: innerStrokeColor, width: 4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      : ClipOval(
                        child: Stack(
                          children: [
                            UtxoCoinCard._buildCardContent(
                              widget.size,
                              isLarge,
                              widget.isFocused,
                              iconColor,
                              colors.utxoOverviewCoinIconOpacity,
                              colors.primaryText,
                              colors.mutedText,
                              widget.utxo,
                              widget.currentUnit,
                              widget.dustThreshold,
                              isSuspiciousDust: widget.isSuspiciousDust,
                            ),
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: innerStrokeColor, width: 4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
            ),
            if (widget.isSelectionMode && !widget.isSelected)
              Positioned.fill(
                child:
                    isBill
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(color: colors.utxoOverviewUnselectedOverlay.withValues(alpha: 0.3)),
                        )
                        : ClipOval(
                          child: Container(color: colors.utxoOverviewUnselectedOverlay.withValues(alpha: 0.3)),
                        ),
              ),
            if (widget.isSelected && widget.showSelectedCheckIcon)
              Positioned(
                top: isLarge ? 6 : 4,
                right: isLarge ? 6 : 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: colors.primaryText, shape: BoxShape.circle),
                  child: SvgPicture.asset(
                    CommonActionIconPath.check,
                    width: isLarge ? 16 : 8,
                    height: isLarge ? 16 : 8,
                    colorFilter: ColorFilter.mode(colors.background, BlendMode.srcIn),
                  ),
                ),
              ),
            if (widget.utxo.isLocked)
              Positioned(
                bottom: isLarge ? 4 : 2,
                right: isLarge ? 4 : 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: colors.primaryText.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: SvgPicture.asset(
                    CommonSecurityIconPath.lock,
                    width: isLarge ? 16 : 12,
                    height: isLarge ? 16 : 12,
                    colorFilter: ColorFilter.mode(colors.dimOverlay, BlendMode.srcIn),
                  ),
                ),
              ),
            if (widget.isAddressReused)
              Positioned(
                top: isLarge ? 8 : 4,
                left: isLarge ? 8 : 4,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
                  decoration: BoxDecoration(color: colors.danger.withValues(alpha: 0.8), shape: BoxShape.circle),
                  child: SvgPicture.asset(
                    CommonStateIconPath.triangleWarning,
                    width: isLarge ? 12 : 10,
                    height: isLarge ? 12 : 10,
                    colorFilter: ColorFilter.mode(colors.iconOnDanger, BlendMode.srcIn),
                  ),
                ),
              ),
            if (widget.utxo.isPending)
              Positioned(
                bottom: isLarge ? 8 : 4,
                left: isLarge ? 8 : 4,
                child: PendingTransactionLottieIcon(
                  isIncoming: widget.utxo.status == UtxoStatus.incoming,
                  size: isLarge ? 12 : 10,
                  padding: const EdgeInsets.all(6),
                ),
              ),
          ],
        ),
      ),
    );

    return coin;
  }
}
