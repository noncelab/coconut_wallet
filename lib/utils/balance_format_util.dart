import 'dart:math';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:decimal/decimal.dart';

class UnitUtil {
  static double convertSatoshiToBitcoin(int satoshi) {
    return double.parse(convertSatoshiToBitcoinString(satoshi));
  }

  static String convertSatoshiToBitcoinString(int satoshi) {
    return (satoshi / 100000000.0).toStringAsFixed(8);
  }

  /// 부동 소숫점 연산 시 오차가 발생할 수 있으므로 Decimal이용
  static int convertBitcoinToSatoshi(double bitcoin) {
    return (Decimal.parse(bitcoin.toString()) * Decimal.parse('100000000')).toDouble().toInt();
  }
}

class BalanceFormatUtil {
  /// 사용자 친화적 형식의 비트코인 잔액 보이기
  /// balance_format_util_test.dart 참고
  static String formatSatoshiToReadableBitcoin(int satoshi, {bool forceEightDecimals = false}) {
    double toBitcoin = UnitUtil.convertSatoshiToBitcoin(satoshi);

    String bitcoinString;
    if (toBitcoin % 1 == 0) {
      bitcoinString = forceEightDecimals ? toBitcoin.toStringAsFixed(8) : toBitcoin.toInt().toString();
    } else {
      bitcoinString = toBitcoin.toStringAsFixed(8);
      if (!forceEightDecimals) {
        bitcoinString = bitcoinString.replaceFirst(RegExp(r'0+$'), '');
      }
    }

    // Split the integer and decimal parts
    List<String> parts = bitcoinString.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    final integerPartFormatted = integerPart == '-0' ? '-0' : int.parse(integerPart).toThousandsSeparatedString();

    String decimalPartGrouped = '';
    if (decimalPart.isNotEmpty) {
      if (decimalPart.length <= 4) {
        decimalPartGrouped = decimalPart;
      } else {
        decimalPart = decimalPart.padRight(8, '0');
        // Group the decimal part into blocks of 4 digits
        decimalPartGrouped = RegExp(r'.{1,4}').allMatches(decimalPart).map((match) => match.group(0)).join(' ');
      }
    }

    if (integerPartFormatted == '0' && decimalPartGrouped == '') {
      return '0';
    }

    return decimalPartGrouped.isNotEmpty ? '$integerPartFormatted.$decimalPartGrouped' : integerPartFormatted;
  }
}

class FakeBalanceUtil {
  /// 가짜 잔액을 지갑 개수만큼 랜덤하게 분배하는 유틸리티 함수
  ///
  /// [fakeBalance] 총 가짜 잔액 (BitcoinUnit에 따라 단위 결정)
  /// [walletCount] 지갑 개수
  /// [unit] 비트코인 단위 (btc 또는 sats)
  ///
  /// Returns: 각 지갑에 할당될 사토시 배열 (0도 허용)
  static List<int> distributeFakeBalance(double fakeBalance, int walletCount, BitcoinUnit unit) {
    if (fakeBalance <= 0 || walletCount <= 0) {
      return List.filled(walletCount, 0);
    }

    // BitcoinUnit에 따라 사토시로 변환
    int fakeBalanceSats;
    if (unit == BitcoinUnit.btc) {
      fakeBalanceSats = UnitUtil.convertBitcoinToSatoshi(fakeBalance);
    } else {
      fakeBalanceSats = fakeBalance.toInt();
    }

    final random = Random();

    // 랜덤 가중치 생성
    final List<int> weights = _generateRandomWeights(walletCount, random);
    final int weightSum = weights.reduce((a, b) => a + b);

    final List<int> splits = [];

    // 가중치에 비례하여 분배
    for (int i = 0; i < walletCount; i++) {
      final int share = (fakeBalanceSats * weights[i] / weightSum).floor();
      splits.add(share);
    }

    // 보정: 분할의 총합이 fakeBalanceSats와 다를 수 있으므로 마지막 지갑에 차이분 추가
    final int currentSum = splits.reduce((a, b) => a + b);
    final int diff = fakeBalanceSats - currentSum;
    splits[splits.length - 1] += diff;

    return splits;
  }

  static List<int> _generateRandomWeights(int walletCount, Random random) {
    // 1. 균등 분배 (20% 확률)
    if (random.nextDouble() < 0.2) {
      return List.filled(walletCount, 100);
    }

    // 2. 지수 분포 (30% 확률)
    if (random.nextDouble() < 0.5) {
      return List.generate(walletCount, (_) {
        // 지수 분포로 가중치 생성 (1~1000)
        final exponential = -log(random.nextDouble()) * 50;
        return (exponential + 1).toInt().clamp(1, 1000);
      });
    }

    // 3. 균등 분포 (50% 확률)
    return List.generate(walletCount, (_) => random.nextInt(200) + 1);
  }
}
