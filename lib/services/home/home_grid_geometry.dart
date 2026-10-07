import 'dart:ui' show Offset, Rect, Size;

import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';

class HomeGridGeometry {
  final double cellExtent;
  final double gap;

  const HomeGridGeometry({required this.cellExtent, required this.gap});

  static double extent(int units, double cellExtent, double gap) => units * cellExtent + (units - 1) * gap;

  double get _pitch => cellExtent + gap;

  Size sizeOf(HomeSpan span) => Size(extent(span.width, cellExtent, gap), extent(span.height, cellExtent, gap));

  Offset originOf(HomeGridPosition position) => Offset(position.column * _pitch, position.row * _pitch);

  Rect rectOf(HomeGridPosition position, HomeSpan span) => originOf(position) & sizeOf(span);

  HomeGridPosition snap(Offset local, HomeSpan span) {
    final rawColumn = local.dx / _pitch;
    final maxColumn = HomeGridLayout.columns - span.width;
    final column =
        span == HomeSpan.small
            ? ((rawColumn / 2).round() * 2).clamp(0, maxColumn)
            : rawColumn.round().clamp(0, maxColumn);
    final row = (local.dy / _pitch).round();
    return HomeGridPosition(column, row < 0 ? 0 : row);
  }

  HomeGridPosition dropPosition(HomeGridLayout layout, HomeItem dragged, Offset local) {
    final snapped = snap(local, dragged.span);
    if (dragged.span != HomeSpan.wide) return snapped;
    final others = layout.configuration.items.where((item) => item.id != dragged.id).toList();
    if (layout.wideDropKeepsSnappedRow(others, snapped.row)) return snapped;
    final preview = local & sizeOf(dragged.span);
    int? touchedRow;
    for (final item in others) {
      final position = layout.positionOf(item.id);
      if (position == null) continue;
      final rect = rectOf(position, item.span);
      final touches =
          preview.left <= rect.right &&
          preview.right >= rect.left &&
          preview.top <= rect.bottom &&
          preview.bottom >= rect.top;
      if (touches && (touchedRow == null || position.row < touchedRow)) touchedRow = position.row;
    }
    return touchedRow == null ? snapped : HomeGridLayout.anchorForSpan(HomeGridPosition(0, touchedRow), dragged.span);
  }
}
