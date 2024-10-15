import 'package:coconut_wallet/widgets/animatedQR/animated_qr_data_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimatedQRDataHandler', () {
    test('splitData splits data correctly', () {
      final data = 'a' * 1000;
      final result = AnimatedQRDataHandler.splitData(data);

      expect(
          result.length, 4); // 총 1000글자이므로 300, 300, 300, 100으로 4조각이 되어야 합니다.
      expect(result[0], startsWith('ur:crypto-psbt/1-4/'));
      expect(result[1], startsWith('ur:crypto-psbt/2-4/'));
      expect(result[2], startsWith('ur:crypto-psbt/3-4/'));
      expect(result[3], startsWith('ur:crypto-psbt/4-4/'));
    });

    test('parseIndex parses index correctly', () {
      const data = 'ur:crypto-psbt/2-4/someData';
      final result = AnimatedQRDataHandler.parseIndex(data);

      expect(result, 2);
    });

    test('parseTotalCount parses total count correctly', () {
      const data = 'ur:crypto-psbt/2-4/someData';
      final result = AnimatedQRDataHandler.parseTotalCount(data);

      expect(result, 4);
    });

    test('validateData validates data correctly', () {
      final validData = [
        'ur:crypto-psbt/1-3/abc',
        'ur:crypto-psbt/2-3/def',
        'ur:crypto-psbt/3-3/ghi',
      ];
      final invalidData = [
        'ur:crypto-psbt/1-3/abc',
        'ur:crypto-psbt/3-3/ghi',
      ];
      final invalidPrefixData = [
        'ur:crypto-psbt/1-3/abc',
        'invalidPrefix/2-3/def',
        'ur:crypto-psbt/3-3/ghi',
      ];
      final invalidIndexData = [
        'ur:crypto-psbt/1-3/abc',
        'ur:crypto-psbt/3-3/def',
        'ur:crypto-psbt/2-3/ghi',
      ];
      final invalidLengthData = [
        'ur:crypto-psbt/1-3/abc',
        'ur:crypto-psbt/2-3/def',
        'ur:crypto-psbt/3-4/ghi',
      ];

      expect(AnimatedQRDataHandler.validateData(validData), true);
      expect(AnimatedQRDataHandler.validateData(invalidData), false);
      expect(AnimatedQRDataHandler.validateData(invalidPrefixData), false);
      expect(AnimatedQRDataHandler.validateData(invalidIndexData), false);
      expect(AnimatedQRDataHandler.validateData(invalidLengthData), false);
    });

    test('joinData joins data correctly', () {
      final data = [
        "ur:crypto-psbt/1-13/cHNidP8BAP1dAwIAAAAUyB0lINRUQ+G/KjN9sQ9SbSJp1Kxjn94bG9KS5zlgI9wAAAAAAP/////tx0F3vKxX2KhcCOKGgz86nt7Bmo3NxIZ8SPcjW+GbbQAAAAAA//////5nPQm4RCtE2+Plz+USTwav4myL5DrV+2rXAD9HeVs4AAAAAAD//////mc9CbhEK0Tb4+XP5RJPBq/ibIvkOtX7atcAP0d5WzgBAAAAAP////9K+l3f/A7WIjB3SsUwGZ2fGBCbfMXux01nP8cT2BB/IAAAAAAA/////xHt0SZ8",
        "ur:crypto-psbt/2-13/Hi6wdpJ7lcETHDqkwnshVCPk2vaGKlnayxvgAAAAAAD/////tWQ8Sc6hNqnnEnQVeZq9cINGxfZeHYQK3Ddo2f6MycgAAAAAAP////+1ZDxJzqE2qecSdBV5mr1wg0bF9l4dhArcN2jZ/ozJyAEAAAAA/////woAnUjbsyg3zDz2DGLv66ZLJ3ug/EvrxOpdVT2TbIp6AAAAAAD/////weXy28Bw2cCVeVDQ2Ky/JFC+Mq9+l/A9yBqW4hADkCUBAAAAAP////+AKyI6VnuitiuTzfzWll+98Yk6IYzaaIub",
        "ur:crypto-psbt/3-13/AtNoYGW5tQAAAAAA/////6ayLc1rbgjTbf3FcRZ4cp78lOuWp4GxUOmIVLgQmhiZAAAAAAD/////HYPtR72HNo9yX8nI46bem9jaUzj8fajtiJDWrqPFYRMAAAAAAP////9/8OJeyTCqchnZUluWUifll5h7CW9fJ5iZdTzUQIhJFgAAAAAA/////xWGQjxnPeVL+VMBTFg4L0i/NnkUq8O+zwgFDrXI4rlbAAAAAAD/////r1/yMNZxLtnoi9HuvvuGve3468VRT5uiF2/+aJI+vjwBAAAAAP////9cD/x+",
        "ur:crypto-psbt/4-13/LQNs4xv2rEuAyvgu/P3rdiI/rRTTLSKt8xQXMQEAAAAA/////+jJVzcnFTU+IIyL75KtBpU7tStKSvxG4ZRaapsbDebyAAAAAAD/////aMh8kwv91O/dmF9CnvuE/ZQQ3pw+846/BJE9ud5cNQoAAAAAAP////+bcHG2eQTRh3y3173Ao1dsyYITWFUIM1nlfJqgiQ27FAAAAAAA/////wG4iZkjAAAAABYAFIgXr3U6BlD/myCp6uCU+BZdTeNpAAAAACIBAm0hp6VpqUas8D18IbNRzhqh2rd02945w0my",
        "ur:crypto-psbt/5-13/Utd8WbxLEPja/p1UAACAAQAAgAAAAIAAAQEfkeD1BQAAAAAWABSMBnuVXwevyktpQaTAvyHb5YDUjSIGA3Ix8vStrqisxsvAE+Dk2OyARj351CYboYfkyla2ziQQGLkosiZUAACAAQAAgAAAAIAAAAAAHgAAAAABAR9AQg8AAAAAABYAFHC6Uc+BHeIObZcddmzHWdEYhdwUIgYDqmwHjUMfjtUr7gp5G+Vrl3aQqHoX/9DaiujM0fBRctoYuSiyJlQAAIABAACAAAAAgAAAAAAcAAAAAAEBH4CEHgAAAAAA",
        "ur:crypto-psbt/6-13/FgAUohlE9oz4OdxkNRXbfLg1LTYuCiYiBgOAVpP7WYC5DMCbKM6f9OYznKwWmPKPYK6A8IsHM5SeWBi5KLImVAAAgAEAAIAAAACAAAAAAB0AAAAAAQEf8tPVBQAAAAAWABSShX7lO94UZiX4m3EyyvmxGegAZyIGAohqEZbs6FJUPGpZfr09R6mKfj2bK4QeyghZ4bag6WLIGLkosiZUAACAAQAAgAAAAIABAAAACQAAAAABAR8IUgAAAAAAABYAFGwCivF/ZQm78R4xHdSHDOlWUcspIgYCz68+lMLkpmBP",
        "ur:crypto-psbt/7-13/Q75yEKTubMzrqpkcapDWJu1xhAJMdAMYuSiyJlQAAIABAACAAAAAgAAAAAAbAAAAAAEBHwhSAAAAAAAAFgAUsRwWAmOu1wl7Na5j5mkqfhkQ8YQiBgNOOrB24Ezfux8VYG9xxSCUnnBFu1PMvpGMy8Jcwe0HJxi5KLImVAAAgAEAAIAAAACAAAAAABoAAAAAAQEfgIQeAAAAAAAWABTTLBPHU2DJ3HhvhT4HZVu9eLTHZSIGAzcORj9Fe2dzT1/SxqwXkeSW1aAJnrnrrD5uRYZ2N3E9GLkosiZUAACAAQAA",
        "ur:crypto-psbt/8-13/gAAAAIAAAAAAGQAAAAABAR9HrdcFAAAAABYAFBpz020sGJ3vu9C2FoSZg7cTZJKbIgYCgtHt+3NhOz6OtzdTpm1iVPOnebad8NV7lxiOFSl9QWIYuSiyJlQAAIABAACAAAAAgAEAAAAHAAAAAAEBH6CGAQAAAAAAFgAUMxEa8pYjGfusgpFhm0JlwUskaUEiBgKZ1Xtu1cJc6yQFUw8iAxmZpBI4sE3wwXqVTxdlDNlU0Ri5KLImVAAAgAEAAIAAAACAAAAAABQAAAAAAQEfMp7mBQAAAAAWABRJR35TtHzY",
        "ur:crypto-psbt/9-13/pDhZER1MVvEpPr/1yyIGA1/yDrHQ8ZIROeR6qG5qvnb0NE3SL72G1B+p1ghtOMnZGLkosiZUAACAAQAAgAAAAIABAAAABgAAAAABAR8IUgAAAAAAABYAFFDlkGR0PsbyZeRkKCQHmqAwBI94IgYDy1QQgEA2UUnJsh+l8yRD20Fut6Qahjx8ojP+9sPXL5EYuSiyJlQAAIABAACAAAAAgAAAAAAMAAAAAAEBHwhSAAAAAAAAFgAUuMxR3t5O+uk+UopkMsgCkuhWuugiBgLxNzWp4oLBV6tvgwmECwKj5D0j",
        "ur:crypto-psbt/10-13/7daSQlRxV/mjpm6ZARi5KLImVAAAgAEAAIAAAACAAAAAAAsAAAAAAQEfAAk9AAAAAAAWABSy87aqI6qVRKIPA+5aj5+xUCOopiIGA9tpP0kK5QWJDZAC88bGlKo8dqBIBUOkoGu3d5sMyqX/GLkosiZUAACAAQAAgAAAAIAAAAAACAAAAAABAR8IUgAAAAAAABYAFDXAmXxLL0fuNh8+Kg1ll43SOy7mIgYD/LLCUeqc9b35QCBucdWMyaQ/+zSinFEzh4sieBdu5LQYuSiyJlQAAIABAACAAAAAgAAAAAAJ",
        "ur:crypto-psbt/11-13/AAAAAAEBH6CGAQAAAAAAFgAUcnhD6Zv12Mxe5WQ4KjB6lCQ9CtYiBgNw3KHNeEbc/L0fhQJdpEwr0SPBwo092xocu8XeRUJZlhi5KLImVAAAgAEAAIAAAACAAAAAAAYAAAAAAQEfVta4BQAAAAAWABRhbGXmtxe3TrHuMpr8/L/3tBdcoiIGAthr2FNMHGT/e4q7UCl//vehLdtcBLajNKEOvbjrQ1qiGLkosiZUAACAAQAAgAAAAIABAAAABAAAAAABAR/k1rgFAAAAABYAFFXoHmirJ1JQD3mdhi9OXZgv",
        "ur:crypto-psbt/12-13/edzGIgYDJxX0K4g/JN93suMbwUqpLNay8qgCmk0JfIGNeAUBChAYuSiyJlQAAIABAACAAAAAgAEAAAADAAAAAAEBH0BCDwAAAAAAFgAUdxM1rh+X0juRPoy36u4t3nbKip8iBgM1BgbSCG3tHeEa0m4UYd4yFkpIqAlBhyWjCUjl8/hqOBi5KLImVAAAgAEAAIAAAACAAAAAAAUAAAAAAQEfCFIAAAAAAAAWABSLEliuRrbsXz9P7gzhRGQqO+kIwSIGA5/RFiFTJNTspw8VjPM10xUkxmct4tSR2qWeF6ST",
        "ur:crypto-psbt/13-13/+ps9GLkosiZUAACAAQAAgAAAAIAAAAAAAwAAAAABAR8IUgAAAAAAABYAFPnBdgnwTj0wy+1etREA+ifpIRS+IgYCVzZZX1jSx0jecoBlr9fFQvJv5PY9jqyA0Z1boELChGkYuSiyJlQAAIABAACAAAAAgAAAAAACAAAAAAEDBLiJmSMBBBcWABSIF691OgZQ/5sgqerglPgWXU3jaQAA"
      ];
      final result = AnimatedQRDataHandler.joinData(data);

      expect(result,
          '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');
    });

    test('joinData throws error for invalid data', () {
      final data = [
        'ur:crypto-psbt/1-3/abc',
        'ur:crypto-psbt/2-3/def',
        'ur:crypto-psbt/3-4/ghi',
      ];

      expect(
          () => AnimatedQRDataHandler.joinData(data), throwsA(isA<String>()));
    });
  });
}
