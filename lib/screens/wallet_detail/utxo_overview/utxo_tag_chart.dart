import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_bucket_card_row.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_chart_bubble.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/utxo_amount_format_util.dart';
import 'package:flutter/material.dart';

String _truncateTagName(String name, int maxLen) {
  if (name.length <= maxLen) return name;
  return '${name.substring(0, maxLen)}...';
}

Color _pastelForTag(UtxoTag tag, [double blend = 0.20]) {
  final idx = tag.colorIndex.clamp(0, tagColorPalette.length - 1);
  final base = tagColorPalette[idx];
  return Color.lerp(base, CoconutColors.gray400, blend)!;
}

Color _colorForSegment(_TagSegment seg) {
  if (seg.isUntagged) return CoconutColors.gray800;
  return _pastelForTag(seg.tag!);
}

/// 도넛 차트 비선택 시 적용할 overlay 불투명도 (0=없음, 1=완전 덮음)
const double _overlayOpacity = 0.6;

/// 태그별 UTXO 금액을 원형(도넛) 차트로 표시
class UtxoTagChart extends StatelessWidget {
  final List<UtxoState> utxoList;
  final List<UtxoTag> utxoTagList;
  final BitcoinUnit currentUnit;
  final VoidCallback? onBalanceTap;

  const UtxoTagChart({
    super.key,
    required this.utxoList,
    required this.utxoTagList,
    required this.currentUnit,
    this.onBalanceTap,
  });

  /// 도넛 차트용: 각 태그별로 해당 태그가 적용된 모든 UTXO 집계 (multi-tag UTXO는 각 태그에 중복 집계)
  /// - segments[].count: 말풍선용, 해당 태그가 적용된 UTXO 개수
  /// - uniqueTaggedCount: 중앙 표시용, 태그 1개 이상 적용된 고유 UTXO 수
  /// - actualTotalSats: 잔액 표시용, 전체 UTXO 금액 합 (중복 제외)
  static ({List<_TagSegment> segments, int coinCount, int uniqueTaggedCount, int actualTotalSats})
  _computeTagSegmentsForDonut(List<UtxoState> utxos, List<UtxoTag> tags) {
    final confirmedUtxos = utxos.where((u) => u.status == UtxoStatus.unspent || u.status == UtxoStatus.locked).toList();
    final utxoAmountMap = {for (var u in confirmedUtxos) u.utxoId: u.amount};
    final actualTotalSats = confirmedUtxos.fold<int>(0, (s, u) => s + u.amount);

    final segments = <_TagSegment>[];
    final allTaggedUtxoIds = <String>{};

    for (final tag in tags) {
      final ids = tag.utxoIdList ?? [];
      var sats = 0;
      var count = 0;
      for (final id in ids) {
        allTaggedUtxoIds.add(id);
        final amount = utxoAmountMap[id];
        if (amount != null) {
          sats += amount;
          count += 1;
        }
      }
      if (sats > 0) {
        segments.add(_TagSegment(tag: tag, sats: sats, count: count));
      }
    }

    final untaggedUtxos = confirmedUtxos.where((u) => !allTaggedUtxoIds.contains(u.utxoId)).toList();
    final untaggedSats = untaggedUtxos.fold<int>(0, (s, u) => s + u.amount);
    final untaggedCount = untaggedUtxos.length;
    if (untaggedSats > 0 && untaggedCount > 0) {
      segments.add(_TagSegment(tag: null, sats: untaggedSats, count: untaggedCount));
    }

    return (
      segments: segments,
      coinCount: confirmedUtxos.length,
      uniqueTaggedCount: allTaggedUtxoIds.length,
      actualTotalSats: actualTotalSats,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _computeTagSegmentsForDonut(utxoList, utxoTagList);
    final segments = result.segments;
    final segmentTotalSats = segments.fold<int>(0, (s, seg) => s + seg.sats);

    if (segments.isEmpty || segmentTotalSats <= 0) {
      return _buildEmptyState(context);
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CoconutColors.black, Color(0xFF1D1D1D)],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.utxo_list_screen.total_balance,
              style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray400),
            ),
            GestureDetector(
              onTap: onBalanceTap,
              behavior: HitTestBehavior.opaque,
              child: Text(
                '${result.coinCount} coins • ${formatUtxoAmountForDisplay(result.actualTotalSats, currentUnit)}',
                style: CoconutTypography.heading4_18_NumberBold.setColor(CoconutColors.white),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: _DonutChart(
                segments: segments,
                segmentTotalSats: segmentTotalSats,
                uniqueTaggedCount: result.uniqueTaggedCount,
                totalCount: result.coinCount,
                currentUnit: currentUnit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CoconutColors.black, Color(0xFF1D1D1D)],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.label_off_outlined, size: 48, color: CoconutColors.gray600),
          const SizedBox(height: 16),
          Text(
            t.utxo_overview_screen.no_tag_applied,
            style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.gray400),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t.utxo_overview_screen.no_tag_applied_desc,
            style: CoconutTypography.body3_12.setColor(CoconutColors.gray500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TagSegment {
  final UtxoTag? tag;
  final int sats;
  final int count;

  const _TagSegment({required this.tag, required this.sats, required this.count});

  String get displayName => tag?.name ?? t.utxo_overview_screen.untagged;
  bool get isUntagged => tag == null;
}

class _DonutChart extends StatefulWidget {
  final List<_TagSegment> segments;
  final int segmentTotalSats;
  final int uniqueTaggedCount;
  final int totalCount;
  final BitcoinUnit currentUnit;

  const _DonutChart({
    required this.segments,
    required this.segmentTotalSats,
    required this.uniqueTaggedCount,
    required this.totalCount,
    required this.currentUnit,
  });

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart> {
  /// 선택된 태그 세그먼트 인덱스 (orderedSegments 기준). null이면 미선택
  int? _selectedIndex;
  Timer? _bubbleDismissTimer;

  static const double _size = 200.0;

  @override
  void dispose() {
    _bubbleDismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleBubbleDismiss(int? selectedIndex) {
    _bubbleDismissTimer?.cancel();
    if (selectedIndex != null) {
      _bubbleDismissTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _selectedIndex == selectedIndex) {
          setState(() => _selectedIndex = null);
        }
      });
    }
  }

  static const double _strokeWidth = 40.0;
  static const double _gap = 2.0;
  static const double _labelOffset = -8.0;

  int? _hitTestSegment(Offset localPosition) {
    final orderedSegments = _orderedSegmentsForDrawing(widget.segments);
    if (orderedSegments.isEmpty) return null;

    const radius = (_size - _strokeWidth) / 2;
    const center = Offset(_size / 2, _size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    const innerR = radius - _strokeWidth / 2;
    const outerR = radius + _strokeWidth / 2;
    if (dist < innerR || dist > outerR) return null;

    // atan2(dy,dx): right=0, down=pi/2. drawArc starts at -pi/2 (top), clockwise
    var angle = math.atan2(dy, dx);
    angle = (angle + math.pi / 2 + 2 * math.pi) % (2 * math.pi);

    final capAngle = math.asin((_strokeWidth / 2) / radius);

    var startAngle = 0.0;
    const gapAngle = _gap / radius;
    final candidates = <int>[];
    final midAngles = <double>[];

    for (var i = 0; i < orderedSegments.length; i++) {
      final seg = orderedSegments[i];
      final ratio = seg.sats / widget.segmentTotalSats;
      final sweepAngle = 2 * math.pi * ratio - (i < orderedSegments.length - 1 ? _gap / radius : 0);
      final midAngle = startAngle + sweepAngle / 2;
      final hitStart = i > 0 ? startAngle - gapAngle : startAngle;
      var hitEnd = seg.isUntagged ? startAngle + sweepAngle : startAngle + sweepAngle + gapAngle;
      if (!seg.isUntagged) {
        hitEnd += capAngle;
      }
      final hitStartWithCap = !seg.isUntagged && i > 0 ? math.max(0.0, hitStart - capAngle) : hitStart;
      final matches =
          (angle >= hitStartWithCap && angle < hitEnd) || (hitEnd > 2 * math.pi && angle < hitEnd - 2 * math.pi);
      if (matches && !seg.isUntagged) {
        candidates.add(i);
        midAngles.add(midAngle);
      }
      startAngle += sweepAngle + gapAngle;
    }

    if (candidates.isEmpty) return null;
    // cap 확장으로 겹치는 영역: 터치 각도와 가장 가까운 세그먼트 중심 선택
    var bestI = 0;
    var bestDist = _angularDistance(angle, midAngles[0]);
    for (var j = 1; j < candidates.length; j++) {
      final d = _angularDistance(angle, midAngles[j]);
      if (d < bestDist) {
        bestDist = d;
        bestI = j;
      }
    }
    return candidates[bestI];
  }

  static double _angularDistance(double a, double b) {
    var d = (a - b).abs();
    if (d > math.pi) d = 2 * math.pi - d;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final segments = widget.segments;
    if (segments.isEmpty) return const SizedBox.shrink();

    final orderedSegments = _orderedSegmentsForDrawing(segments);
    const radius = (_size - _strokeWidth) / 2;
    var startAngle = -math.pi / 2;

    const minVisibleRatio = 0.02;
    const labelYOffset = -16.0;
    final labelPositions = <_LabelPosition>[];
    for (var i = 0; i < orderedSegments.length; i++) {
      final seg = orderedSegments[i];
      final ratio = seg.sats / widget.segmentTotalSats;
      final sweepAngle = 2 * math.pi * ratio - (i < orderedSegments.length - 1 ? _gap / radius : 0);
      final midAngle = startAngle + sweepAngle / 2;
      const labelDist = radius + _strokeWidth / 2 + _labelOffset;
      final dx = _size / 2 + labelDist * math.cos(midAngle);
      final dy = _size / 2 + labelDist * math.sin(midAngle) + labelYOffset;
      const outerR = radius + _strokeWidth / 2;
      const arcRadius = outerR * 0.8;
      final arcCenterX = _size / 2 + arcRadius * math.cos(midAngle);
      final arcCenterY = _size / 2 + arcRadius * math.sin(midAngle);
      if (ratio >= minVisibleRatio && !seg.isUntagged) {
        labelPositions.add(
          _LabelPosition(seg: seg, dx: dx, dy: dy, arcCenterX: arcCenterX, arcCenterY: arcCenterY, index: i),
        );
      }
      startAngle += sweepAngle + _gap / radius;
    }

    _LabelPosition? selectedLp;
    if (_selectedIndex != null) {
      for (final lp in labelPositions) {
        if (lp.index == _selectedIndex) {
          selectedLp = lp;
          break;
        }
      }
    }

    const padding = 12.0;
    final stackW = _size + padding * 2;

    return SizedBox(
      width: stackW,
      height: stackW,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: padding,
            top: padding,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final hit = _hitTestSegment(details.localPosition);
                final newIndex = hit != null && hit == _selectedIndex ? null : hit;
                setState(() => _selectedIndex = newIndex);
                _scheduleBubbleDismiss(newIndex);
              },
              child: SizedBox(
                width: _size,
                height: _size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(_size, _size),
                      painter: _DonutChartPainter(
                        segments: segments,
                        totalSats: widget.segmentTotalSats,
                        strokeWidth: _strokeWidth,
                        gap: _gap,
                        selectedIndex: _selectedIndex,
                        overlayOpacity: _overlayOpacity,
                      ),
                    ),
                    IgnorePointer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.utxo_overview_screen.tagged,
                            style: CoconutTypography.caption_10.setColor(CoconutColors.gray500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.uniqueTaggedCount} / ${widget.totalCount}',
                            style: CoconutTypography.body1_16_NumberBold.setColor(CoconutColors.white),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selectedLp != null)
            Positioned(
              left: padding + selectedLp.arcCenterX - 60,
              top: padding + selectedLp.arcCenterY - (UtxoChartBubble.height + UtxoChartBubble.arrowHeight),
              width: 120,
              height: UtxoChartBubble.height + UtxoChartBubble.arrowHeight,
              child: IgnorePointer(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: UtxoChartBubble(
                      text: t.utxo_overview_screen.tag_bubble_with_count(
                        name: _truncateTagName(selectedLp.seg.displayName, 8),
                        count: selectedLp.seg.count,
                      ),
                      maxWidth: 120,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LabelPosition {
  final _TagSegment seg;
  final double dx;
  final double dy;

  /// 색칠된 도넛 세그먼트(호)의 중앙 - 말풍선 꼭지점이 가리킬 위치
  final double arcCenterX;
  final double arcCenterY;
  final int index;

  const _LabelPosition({
    required this.seg,
    required this.dx,
    required this.dy,
    required this.arcCenterX,
    required this.arcCenterY,
    required this.index,
  });
}

/// 도넛 차트의 미분류 세그먼트를 색상
const Color _untaggedInvisibleColor = Color(0xFF323232);

/// Painter와 라벨 위치 계산에서 동일한 순서 사용: 미분류 먼저, 태그 나중
List<_TagSegment> _orderedSegmentsForDrawing(List<_TagSegment> segments) => [
  ...segments.where((s) => s.isUntagged),
  ...segments.where((s) => !s.isUntagged),
];

const Color _overlayBlendColor = Color(0xFF1D1D1D);

class _DonutChartPainter extends CustomPainter {
  final List<_TagSegment> segments;
  final int totalSats;
  final double strokeWidth;
  final double gap;
  final int? selectedIndex;
  final double overlayOpacity;

  _DonutChartPainter({
    required this.segments,
    required this.totalSats,
    required this.strokeWidth,
    required this.gap,
    this.selectedIndex,
    this.overlayOpacity = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalSats <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    var startAngle = -math.pi / 2;

    final orderedSegments = _orderedSegmentsForDrawing(segments);

    for (var i = 0; i < orderedSegments.length; i++) {
      final seg = orderedSegments[i];
      final sweepAngle = 2 * math.pi * (seg.sats / totalSats) - (i < orderedSegments.length - 1 ? gap / radius : 0);

      var color = seg.isUntagged ? _untaggedInvisibleColor : _colorForSegment(seg);

      if (!seg.isUntagged && overlayOpacity > 0) {
        final isSelected = selectedIndex == i;
        if (isSelected) {
          color = _pastelForTag(seg.tag!, 0.0);
        } else {
          color = Color.lerp(color, _overlayBlendColor, overlayOpacity)!;
        }
      }

      final paint =
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round;

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + gap / radius;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      segments != oldDelegate.segments ||
      totalSats != oldDelegate.totalSats ||
      selectedIndex != oldDelegate.selectedIndex ||
      overlayOpacity != oldDelegate.overlayOpacity;
}

class _TagSectionChip extends StatelessWidget {
  final String name;
  final UtxoTag? tag;

  const _TagSectionChip({required this.name, this.tag});

  @override
  Widget build(BuildContext context) {
    if (tag != null) {
      final colorIndex = tag!.colorIndex.clamp(0, tagColorPalette.length - 1);
      final foregroundColor = tagColorPalette[colorIndex];
      return IntrinsicWidth(
        child: CoconutChip(
          minWidth: 44,
          color: CoconutColors.backgroundColorPaletteDark[colorIndex],
          borderColor: foregroundColor,
          label: '#$name',
          labelSize: 11,
          labelColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      );
    }
    return IntrinsicWidth(
      child: CoconutChip(
        minWidth: 44,
        color: CoconutColors.gray800,
        borderColor: CoconutColors.gray800,
        label: name,
        labelSize: 11,
        labelColor: CoconutColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}

/// 태그별 그리드 뷰: 제목(태그 칩), 접기/펼치기, 내용(그리드, unlock 먼저 lock 나중)
class UtxoTagGridSection extends StatefulWidget {
  final List<UtxoState> utxoList;
  final List<UtxoTag> utxoTagList;
  final BitcoinUnit currentUnit;
  final Set<String> selectedUtxoIds;
  final Set<String> reusedAddresses;
  final bool isSelectionMode;
  final void Function(UtxoState) onUtxoTap;
  final void Function(UtxoState)? onUtxoLongPress;

  const UtxoTagGridSection({
    super.key,
    required this.utxoList,
    required this.utxoTagList,
    required this.currentUnit,
    required this.selectedUtxoIds,
    required this.reusedAddresses,
    required this.isSelectionMode,
    required this.onUtxoTap,
    this.onUtxoLongPress,
  });

  @override
  State<UtxoTagGridSection> createState() => _UtxoTagGridSectionState();
}

class _UtxoTagGridSectionState extends State<UtxoTagGridSection> {
  static const double _gridMaxCoinExtent = 100.0;
  static const double _mainAxisSpacing = 6.0;
  static const double _crossAxisSpacing = 12.0;
  static const double _padding = 16.0;

  /// 섹션별 펼침 상태 (기본: 모두 펼침)
  late List<bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = [];
  }

  /// UTXO 정렬: 1. pending 2. unspent 3. locked 마지막, 동일 상태 내 큰 금액 순
  static void _sortUtxosForTagGrid(List<UtxoState> utxos) {
    int statusOrder(UtxoState u) {
      if (u.status == UtxoStatus.outgoing || u.status == UtxoStatus.incoming) return 0;
      if (u.status == UtxoStatus.unspent) return 1;
      return 2; // locked
    }

    utxos.sort((a, b) {
      final orderA = statusOrder(a);
      final orderB = statusOrder(b);
      if (orderA != orderB) return orderA.compareTo(orderB);
      return b.amount.compareTo(a.amount); // 금액 큰 순
    });
  }

  /// 단일 그룹: tag + utxos. 여러 태그 그룹: subGroups에 태그 조합별 (tags, utxos) 리스트
  List<
    ({
      UtxoTag? tag,
      List<UtxoState> utxos,
      bool isMultiTag,
      List<String>? multiTagNames,
      List<UtxoTag>? multiTags,
      List<({List<UtxoTag> tags, List<UtxoState> utxos})>? subGroups,
    })
  >
  _groupUtxosByTag() {
    final displayableUtxos =
        widget.utxoList
            .where(
              (u) =>
                  u.status == UtxoStatus.unspent ||
                  u.status == UtxoStatus.locked ||
                  u.status == UtxoStatus.outgoing ||
                  u.status == UtxoStatus.incoming,
            )
            .toList();
    final utxoMap = {for (var u in displayableUtxos) u.utxoId: u};

    // utxoId -> 태그 개수
    final tagCountByUtxo = <String, int>{};
    for (final tag in widget.utxoTagList) {
      for (final id in tag.utxoIdList ?? []) {
        tagCountByUtxo[id] = (tagCountByUtxo[id] ?? 0) + 1;
      }
    }

    final multiTaggedIds = tagCountByUtxo.entries.where((e) => e.value >= 2).map((e) => e.key).toSet();
    final singleTaggedIds = tagCountByUtxo.entries.where((e) => e.value == 1).map((e) => e.key).toSet();
    final allTaggedUtxoIds = tagCountByUtxo.keys.toSet();

    final result =
        <
          ({
            UtxoTag? tag,
            List<UtxoState> utxos,
            bool isMultiTag,
            List<String>? multiTagNames,
            List<UtxoTag>? multiTags,
            List<({List<UtxoTag> tags, List<UtxoState> utxos})>? subGroups,
          })
        >[];

    for (final tag in widget.utxoTagList) {
      final ids = List<String>.from(tag.utxoIdList ?? []);
      final utxos =
          ids.where((id) => singleTaggedIds.contains(id)).map((id) => utxoMap[id]).whereType<UtxoState>().toList();
      if (utxos.isNotEmpty) {
        _sortUtxosForTagGrid(utxos);
        result.add((tag: tag, utxos: utxos, isMultiTag: false, multiTagNames: null, multiTags: null, subGroups: null));
      }
    }

    final multiTagged = multiTaggedIds.map((id) => utxoMap[id]).whereType<UtxoState>().toList();
    if (multiTagged.isNotEmpty) {
      List<String> getTagNamesForUtxo(UtxoState u) {
        final tagsFromUtxo = u.tags;
        if (tagsFromUtxo != null && tagsFromUtxo.isNotEmpty) {
          return tagsFromUtxo.map((t) => t.name).toList()..sort();
        }
        return widget.utxoTagList.where((tag) => tag.utxoIdList?.contains(u.utxoId) == true).map((t) => t.name).toList()
          ..sort();
      }

      final groupByTagSet = <String, List<UtxoState>>{};
      for (final utxo in multiTagged) {
        final names = getTagNamesForUtxo(utxo);
        final key = names.join(',');
        groupByTagSet.putIfAbsent(key, () => []).add(utxo);
      }

      UtxoTag? findTag(String name) {
        for (final t in widget.utxoTagList) {
          if (t.name == name) return t;
        }
        return null;
      }

      final subGroups = <({List<UtxoTag> tags, List<UtxoState> utxos})>[];
      final allMultiTaggedUtxos = <UtxoState>[];
      for (final entry in groupByTagSet.entries) {
        final tagNames = entry.key.split(',');
        final utxos = entry.value;
        _sortUtxosForTagGrid(utxos);
        final multiTags = tagNames.map(findTag).whereType<UtxoTag>().toList();
        subGroups.add((tags: multiTags, utxos: utxos));
        allMultiTaggedUtxos.addAll(utxos);
      }
      result.add((
        tag: null,
        utxos: allMultiTaggedUtxos,
        isMultiTag: true,
        multiTagNames: null,
        multiTags: null,
        subGroups: subGroups,
      ));
    }

    final untagged = displayableUtxos.where((u) => !allTaggedUtxoIds.contains(u.utxoId)).toList();
    if (untagged.isNotEmpty) {
      _sortUtxosForTagGrid(untagged);
      result.add((
        tag: null,
        utxos: untagged,
        isMultiTag: false,
        multiTagNames: null,
        multiTags: null,
        subGroups: null,
      ));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupUtxosByTag();
    if (groups.isEmpty) return const SizedBox.shrink();

    if (_expanded.length != groups.length) {
      _expanded = List.generate(groups.length, (i) => i < _expanded.length ? _expanded[i] : true);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(_padding, 0, _padding, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            groups.asMap().entries.map((entry) {
              final index = entry.key;
              final g = entry.value;
              final isExpanded = index < _expanded.length && _expanded[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          if (index < _expanded.length) {
                            _expanded = List.from(_expanded);
                            _expanded[index] = !_expanded[index];
                          }
                        });
                      },
                      child: Row(
                        children: [
                          // 여러 태그: 미적용과 동일한 스타일의 단일 칩으로 표시 (overflow 방지)
                          if (g.isMultiTag)
                            _TagSectionChip(name: t.utxo_overview_screen.multi_tag, tag: null)
                          else
                            _TagSectionChip(name: g.tag?.name ?? t.utxo_overview_screen.untagged, tag: g.tag),
                          const SizedBox(width: 8),
                          Text(
                            '${g.utxos.length} coins',
                            style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500),
                          ),
                          const Spacer(),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              key: ValueKey(isExpanded),
                              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                              size: 24,
                              color: CoconutColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Builder(
                          builder: (context) {
                            final width = MediaQuery.of(context).size.width - 2 * _padding;
                            final crossAxisCount = (width / (_gridMaxCoinExtent + _crossAxisSpacing)).floor().clamp(
                              1,
                              10,
                            );
                            final cellSize = (width - (crossAxisCount - 1) * _crossAxisSpacing) / crossAxisCount;
                            final coinSize = cellSize * 0.9;

                            if (g.isMultiTag && (g.subGroups?.isNotEmpty ?? false)) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    g.subGroups!.map((sg) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children:
                                                    sg.tags
                                                        .map((tag) => _TagSectionChip(name: tag.name, tag: tag))
                                                        .toList(),
                                              ),
                                            ),
                                            Wrap(
                                              spacing: _crossAxisSpacing,
                                              runSpacing: _mainAxisSpacing,
                                              children:
                                                  sg.utxos.map((utxo) {
                                                    final isSelected = widget.selectedUtxoIds.contains(utxo.utxoId);
                                                    return SizedBox(
                                                      width: cellSize,
                                                      height: cellSize / 0.95,
                                                      child: Center(
                                                        child: UtxoCoinCard(
                                                          utxo: utxo,
                                                          size: coinSize,
                                                          compact: true,
                                                          isFocused: true,
                                                          isSelected: isSelected,
                                                          isSelectionMode: widget.isSelectionMode,
                                                          currentUnit: widget.currentUnit,
                                                          isAddressReused: widget.reusedAddresses.contains(utxo.to),
                                                          onTap: () => widget.onUtxoTap(utxo),
                                                          onLongPress:
                                                              widget.onUtxoLongPress != null
                                                                  ? () => widget.onUtxoLongPress!(utxo)
                                                                  : null,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              );
                            }

                            return Wrap(
                              spacing: _crossAxisSpacing,
                              runSpacing: _mainAxisSpacing,
                              children:
                                  g.utxos.map((utxo) {
                                    final isSelected = widget.selectedUtxoIds.contains(utxo.utxoId);
                                    return SizedBox(
                                      width: cellSize,
                                      height: cellSize / 0.95,
                                      child: Center(
                                        child: UtxoCoinCard(
                                          utxo: utxo,
                                          size: coinSize,
                                          compact: true,
                                          isFocused: true,
                                          isSelected: isSelected,
                                          isSelectionMode: widget.isSelectionMode,
                                          currentUnit: widget.currentUnit,
                                          isAddressReused: widget.reusedAddresses.contains(utxo.to),
                                          onTap: () => widget.onUtxoTap(utxo),
                                          onLongPress:
                                              widget.onUtxoLongPress != null
                                                  ? () => widget.onUtxoLongPress!(utxo)
                                                  : null,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            );
                          },
                        ),
                      ),
                      crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}
