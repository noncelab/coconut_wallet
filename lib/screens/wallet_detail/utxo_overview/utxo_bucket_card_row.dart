import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_bucket.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/utils/utxo_amount_format_util.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class UtxoBucketCardRow extends StatelessWidget {
  final UtxoBucket bucket;
  final int index;
  final BitcoinUnit currentUnit;
  final ValueListenable<int> activeIndexListenable;
  final bool isSelectionMode;
  final Set<String> selectedUtxoIds;
  final Set<String> reusedAddresses;
  final void Function(UtxoState) onTapUtxo;
  final void Function(UtxoState)? onLongPressUtxo;

  const UtxoBucketCardRow({
    super.key,
    required this.bucket,
    required this.index,
    required this.currentUnit,
    required this.activeIndexListenable,
    required this.isSelectionMode,
    required this.selectedUtxoIds,
    required this.reusedAddresses,
    required this.onTapUtxo,
    this.onLongPressUtxo,
  });

  static const double rowHeight = 210 + 24 + 4 + 4;

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
            builder: (_, active, __) => _Summary(bucket: bucket, currentUnit: currentUnit, isActive: active == index),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: activeIndexListenable,
              builder: (_, active, __) {
                return _CoinStack(
                  utxos: bucket.utxos,
                  currentUnit: currentUnit,
                  isExpanded: active == index,
                  isSelectionMode: isSelectionMode,
                  selectedUtxoIds: selectedUtxoIds,
                  reusedAddresses: reusedAddresses,
                  onTap: onTapUtxo,
                  onLongPress: onLongPressUtxo,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final UtxoBucket bucket;
  final BitcoinUnit currentUnit;
  final bool isActive;

  const _Summary({required this.bucket, required this.currentUnit, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final totalSats = bucket.utxos.fold<int>(0, (sum, u) => sum + u.amount);
    final isDustBucket = bucket.label == 'dust';
    final textColor = isActive ? CoconutColors.white : CoconutColors.gray500;
    return Align(
      alignment: Alignment.center,
      child: Text(
        '${bucket.utxos.length} coins • ${formatUtxoAmountForDisplay(totalSats, currentUnit, forceSats: isDustBucket)}',
        style: CoconutTypography.body2_14_NumberBold.setColor(textColor),
      ),
    );
  }
}

class _CoinStack extends StatefulWidget {
  final List<UtxoState> utxos;
  final BitcoinUnit currentUnit;
  final bool isExpanded;
  final bool isSelectionMode;
  final Set<String> selectedUtxoIds;
  final Set<String> reusedAddresses;
  final void Function(UtxoState) onTap;
  final void Function(UtxoState)? onLongPress;

  const _CoinStack({
    required this.utxos,
    required this.currentUnit,
    required this.isExpanded,
    required this.isSelectionMode,
    required this.selectedUtxoIds,
    required this.reusedAddresses,
    required this.onTap,
    this.onLongPress,
  });

  static const double coinSize = 132.0;

  @override
  State<_CoinStack> createState() => _CoinStackState();
}

class _CoinStackState extends State<_CoinStack> {
  double _scrollOffset = 0;

  static const double _coinSize = _CoinStack.coinSize;
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
                            color: CoconutColors.gray800,
                          ),
                          child: Text(
                            '+$extraCount',
                            style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white),
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
                          currentUnit: widget.currentUnit,
                          isAddressReused: widget.reusedAddresses.contains(widget.utxos[i].to),
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
  final BitcoinUnit currentUnit;
  final bool isAddressReused;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const UtxoCoinCard({
    super.key,
    required this.utxo,
    required this.size,
    this.compact = false,
    this.isFocused = true,
    this.isSelected = false,
    required this.currentUnit,
    this.isAddressReused = false,
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
    Color textColor,
    UtxoState utxo,
    BitcoinUnit currentUnit,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(size * 0.01),
            child: Opacity(
              opacity: isFocused ? 0.12 : 0.06,
              child: SvgPicture.asset(
                'assets/svg/bitcoin.svg',
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
                  formatUtxoAmountForDisplay(utxo.amount, currentUnit, forceSats: utxo.amount <= dustLimit),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (isLarge ? CoconutTypography.body1_16_NumberBold : CoconutTypography.body2_14_NumberBold)
                      .setColor(isFocused ? textColor : textColor.withValues(alpha: 0.55)),
                ),
              ),
              if (isLarge) ...[
                const SizedBox(height: 4),
                Text(
                  _formatDate(utxo.timestamp),
                  textAlign: TextAlign.center,
                  style: CoconutTypography.caption_10.setColor(
                    isFocused ? textColor : textColor.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    final y = (dt.year % 100).toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y.$m.$d $h:$min';
  }

  @override
  State<UtxoCoinCard> createState() => _UtxoCoinCardState();
}

class _UtxoCoinCardState extends State<UtxoCoinCard> {
  bool _isPressed = false;

  static const Duration _shrinkDuration = Duration(milliseconds: 100);

  @override
  Widget build(BuildContext context) {
    final isLarge = !widget.compact;
    final isBill = UtxoCoinCard.isBillShape(widget.utxo.amount);
    final cardWidth = isBill ? widget.size * 1.35 : widget.size;
    final cardHeight = isBill ? widget.size * 0.85 : widget.size;
    final tierTheme = context.watch<PreferenceProvider>().utxoTierTheme;
    final bucketCol = tierTheme.colorForSats(widget.utxo.amount);
    final bgColor = widget.isFocused ? bucketCol : Color.lerp(const Color(0xFF1A1A1A), bucketCol, 0.68)!;
    final fgColor = UtxoColorUtils.bestOn(bgColor);
    final textColor = fgColor;
    final iconColor = fgColor.withValues(alpha: 0.9);
    final shadowBlur = widget.isFocused ? 16.0 : 6.0;
    final coinBorder =
        widget.isAddressReused
            ? Border.all(color: CoconutColors.hotPink, width: 2)
            : (widget.isSelected ? Border.all(color: CoconutColors.gray150, width: 2) : null);

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
                color: bgColor,
                border: coinBorder,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
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
                        child: UtxoCoinCard._buildCardContent(
                          widget.size,
                          isLarge,
                          widget.isFocused,
                          iconColor,
                          textColor,
                          widget.utxo,
                          widget.currentUnit,
                        ),
                      )
                      : ClipOval(
                        child: UtxoCoinCard._buildCardContent(
                          widget.size,
                          isLarge,
                          widget.isFocused,
                          iconColor,
                          textColor,
                          widget.utxo,
                          widget.currentUnit,
                        ),
                      ),
            ),
            if (widget.isSelected)
              Positioned(
                top: isLarge ? 6 : 4,
                right: isLarge ? 6 : 4,
                child: Container(
                  padding: EdgeInsets.all(isLarge ? 6 : 4),
                  decoration: const BoxDecoration(color: CoconutColors.white, shape: BoxShape.circle),
                  child: SvgPicture.asset(
                    'assets/svg/check.svg',
                    width: isLarge ? 16 : 10,
                    height: isLarge ? 16 : 10,
                    colorFilter: const ColorFilter.mode(CoconutColors.black, BlendMode.srcIn),
                  ),
                ),
              ),
            if (widget.utxo.isLocked)
              Positioned(
                bottom: isLarge ? 4 : 2,
                right: isLarge ? 4 : 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: CoconutColors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: SvgPicture.asset(
                    'assets/svg/lock.svg',
                    width: isLarge ? 12 : 10,
                    height: isLarge ? 12 : 10,
                    colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                  ),
                ),
              ),
            if (widget.isAddressReused)
              Positioned(
                top: isLarge ? 5 : 2,
                left: isLarge ? 7 : 2,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
                  decoration: BoxDecoration(
                    color: CoconutColors.hotPink.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    'assets/svg/triangle-warning.svg',
                    width: isLarge ? 12 : 10,
                    height: isLarge ? 12 : 10,
                    colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                  ),
                ),
              ),
            if (widget.utxo.isPending)
              Positioned(
                bottom: isLarge ? 4 : 2,
                left: isLarge ? 4 : 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (widget.utxo.status == UtxoStatus.incoming ? CoconutColors.cyan : CoconutColors.primary)
                        .withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Lottie.asset(
                    widget.utxo.status == UtxoStatus.incoming
                        ? 'assets/lottie/arrow-down.json'
                        : 'assets/lottie/arrow-up.json',
                    width: isLarge ? 12 : 10,
                    height: isLarge ? 12 : 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return coin;
  }
}
