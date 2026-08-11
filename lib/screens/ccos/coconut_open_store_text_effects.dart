import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared typewriter-reveal helpers used by the open-store intro scenes
/// (idea scene, build scene) to progressively type out and highlight text.
const int kTypewriterMsPerCharacter = 50;
const double kTypewriterMsPerCharacterDouble = 50.0;

int typewriterDurationMs(String source) =>
    source.characters.length * kTypewriterMsPerCharacter;

Interval intervalFromMs(
  int startMs,
  int endMs,
  int totalMs, {
  Curve curve = Curves.linear,
}) {
  final safeTotalMs = totalMs <= 0 ? 1 : totalMs;
  return Interval(
    (startMs / safeTotalMs).clamp(0.0, 1.0),
    (endMs / safeTotalMs).clamp(0.0, 1.0),
    curve: curve,
  );
}

Interval typewriterIntervalFromMs(String source, int startMs, int totalMs) {
  return intervalFromMs(
    startMs,
    startMs + typewriterDurationMs(source),
    totalMs,
  );
}

String typewriterText(
  String source,
  Animation<double> animation,
  Interval interval,
) {
  final progress = interval.transform(animation.value);
  final visibleLength =
      (source.characters.length * progress)
          .clamp(0, source.characters.length)
          .round();
  return source.characters.take(visibleLength).toString();
}

TextSpan typewriterSpan({
  required String source,
  required Animation<double> animation,
  required Interval interval,
  required TextStyle baseStyle,
  required TextStyle highlightStyle,
  Set<String> highlightPhrases = const <String>{},
}) {
  final visibleText = typewriterText(source, animation, interval);
  return styledSpanFromVisibleText(
    visibleText: visibleText,
    sourceText: source,
    baseStyle: baseStyle,
    highlightStyle: highlightStyle,
    highlightPhrases: highlightPhrases,
  );
}

// Styles [visibleText] with [highlightPhrases] highlighted. A phrase that's only partially
// typed so far (its remaining, untyped tail extends past the end of [visibleText]) is still
// highlighted for the portion already visible, so the highlight grows in step with the
// typewriter reveal instead of popping in all at once only once the whole phrase is typed.
TextSpan styledSpanFromVisibleText({
  required String visibleText,
  required TextStyle baseStyle,
  required TextStyle highlightStyle,
  Set<String> highlightPhrases = const <String>{},
  String? sourceText,
}) {
  if (highlightPhrases.isEmpty || visibleText.isEmpty) {
    return TextSpan(text: visibleText, style: baseStyle);
  }

  final source = sourceText ?? visibleText;
  final highlightRanges = <({int start, int end})>[];
  for (final phrase in highlightPhrases) {
    if (phrase.isEmpty) continue;
    var start = source.indexOf(phrase);
    while (start != -1) {
      highlightRanges.add((start: start, end: start + phrase.length));
      start = source.indexOf(phrase, start + phrase.length);
    }
  }

  if (highlightRanges.isEmpty) {
    return TextSpan(text: visibleText, style: baseStyle);
  }

  highlightRanges.sort((a, b) => a.start.compareTo(b.start));
  final spans = <TextSpan>[];
  var cursor = 0;

  while (cursor < visibleText.length) {
    ({int start, int end})? range;
    for (final candidate in highlightRanges) {
      if (cursor >= candidate.start && cursor < candidate.end) {
        range = candidate;
        break;
      }
    }
    if (range != null) {
      final end = math.min(range.end, visibleText.length);
      spans.add(
        TextSpan(
          text: visibleText.substring(cursor, end),
          style: highlightStyle,
        ),
      );
      cursor = end;
      continue;
    }

    final nextHighlightStart = highlightRanges
        .where((range) => range.start > cursor)
        .map((range) => range.start)
        .fold<int>(visibleText.length, math.min);
    final nextCursor = math.min(nextHighlightStart, visibleText.length);
    spans.add(
      TextSpan(
        text: visibleText.substring(cursor, nextCursor),
        style: baseStyle,
      ),
    );
    cursor = nextCursor;
  }

  return TextSpan(children: spans, style: baseStyle);
}
