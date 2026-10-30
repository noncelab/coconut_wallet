import 'dart:io';

import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the process uses the requested timezone, including seasonal offsets', () {
    final offsets = [DateTime(2026, 1, 15).timeZoneOffset.inMinutes, DateTime(2026, 7, 15).timeZoneOffset.inMinutes];
    final expected =
        {
          'UTC': [0, 0],
          'Asia/Seoul': [540, 540],
          'Asia/Kathmandu': [345, 345],
          'America/New_York': [-300, -240],
        }[Platform.environment['TZ']];
    print('TZ=${Platform.environment['TZ']}, winter/summer offsets=$offsets');
    if (expected != null) expect(offsets, expected);
  });

  final cases = [
    (
      name: 'today',
      time: DateTime(2026, 10, 15, 13, 5),
      now: DateTime(2026, 10, 15, 18),
      text: '${t.home_widgets.today} 13:05',
    ),
    (
      name: 'same local day across UTC midnight',
      time: DateTime(2026, 10, 15, 0, 5),
      now: DateTime(2026, 10, 15, 23, 55),
      text: '${t.home_widgets.today} 00:05',
    ),
    (
      name: 'previous local day',
      time: DateTime(2026, 10, 14, 23, 55),
      now: DateTime(2026, 10, 15, 0, 5),
      text: '10/14 23:55',
    ),
    (
      name: 'previous local year',
      time: DateTime(2025, 12, 31, 23, 55),
      now: DateTime(2026, 1, 1, 0, 5),
      text: '12/31 23:55',
    ),
    (
      name: 'same month and day in another year',
      time: DateTime(2025, 10, 15, 9, 7),
      now: DateTime(2026, 10, 15, 18),
      text: '10/15 09:07',
    ),
    (
      name: 'before spring DST transition',
      time: DateTime(2026, 3, 8, 1, 30),
      now: DateTime(2026, 3, 8, 12),
      text: '${t.home_widgets.today} 01:30',
    ),
    (
      name: 'after spring DST transition',
      time: DateTime(2026, 3, 8, 3, 30),
      now: DateTime(2026, 3, 8, 12),
      text: '${t.home_widgets.today} 03:30',
    ),
  ];

  for (final sample in cases) {
    test('${sample.name}: UTC and local time/now preserve local display', () {
      for (final time in [sample.time, sample.time.toUtc()]) {
        for (final now in [sample.now, sample.now.toUtc()]) {
          expect(
            formatHomeDateTime(time, now),
            sample.text,
            reason: 'time.isUtc=${time.isUtc}, now.isUtc=${now.isUtc}',
          );
        }
      }
    });
  }

  if (Platform.environment['TZ'] == 'America/New_York') {
    test('both repeated fall DST hours display their local wall time', () {
      final now = DateTime(2026, 11, 1, 12);
      final first = DateTime.utc(2026, 11, 1, 5, 30);
      final second = DateTime.utc(2026, 11, 1, 6, 30);
      expect(first.toLocal().timeZoneOffset, const Duration(hours: -4));
      expect(second.toLocal().timeZoneOffset, const Duration(hours: -5));
      expect(formatHomeDateTime(first, now), '${t.home_widgets.today} 01:30');
      expect(formatHomeDateTime(second, now), '${t.home_widgets.today} 01:30');
    });
  }
}
