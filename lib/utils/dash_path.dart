import 'dart:ui';

/// [pattern]은 (그리기, 비우기) 길이 반복, null이면 원래 경로
Path dashPath(Path source, List<double>? pattern) {
  if (pattern == null || pattern.length < 2) return source;
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var draw = true;
    var index = 0;
    while (distance < metric.length) {
      final length = pattern[index % pattern.length];
      if (draw) result.addPath(metric.extractPath(distance, distance + length), Offset.zero);
      distance += length;
      draw = !draw;
      index++;
    }
  }
  return result;
}
