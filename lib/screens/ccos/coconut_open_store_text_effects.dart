import 'package:flutter/material.dart';

/// Shared typewriter-reveal helpers used by the open-store intro scenes
/// (idea scene, build scene) to progressively type out and highlight text.
String typewriterText(String source, Animation<double> animation, Interval interval) {
  final progress = interval.transform(animation.value);
  final visibleLength = (source.characters.length * progress).clamp(0, source.characters.length).round();
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
}) {
  if (highlightPhrases.isEmpty || visibleText.isEmpty) {
    return TextSpan(text: visibleText, style: baseStyle);
  }

  final sortedPhrases = highlightPhrases.toList()..sort((a, b) => b.length.compareTo(a.length));
  final spans = <TextSpan>[];
  var cursor = 0;

  while (cursor < visibleText.length) {
    final remaining = visibleText.substring(cursor);

    String? fullMatch;
    for (final phrase in sortedPhrases) {
      if (remaining.startsWith(phrase)) {
        fullMatch = phrase;
        break;
      }
    }
    if (fullMatch != null) {
      spans.add(TextSpan(text: fullMatch, style: highlightStyle));
      cursor += fullMatch.length;
      continue;
    }

    final isMidPhrase = sortedPhrases.any((phrase) => phrase.length > remaining.length && phrase.startsWith(remaining));
    if (isMidPhrase) {
      spans.add(TextSpan(text: remaining, style: highlightStyle));
      break;
    }

    var nextCursor = cursor + 1;
    while (nextCursor < visibleText.length) {
      final tail = visibleText.substring(nextCursor);
      final couldStartHighlight = sortedPhrases.any(
        (phrase) => tail.startsWith(phrase) || (phrase.length > tail.length && phrase.startsWith(tail)),
      );
      if (couldStartHighlight) break;
      nextCursor += 1;
    }
    spans.add(TextSpan(text: visibleText.substring(cursor, nextCursor), style: baseStyle));
    cursor = nextCursor;
  }

  return TextSpan(children: spans, style: baseStyle);
}
