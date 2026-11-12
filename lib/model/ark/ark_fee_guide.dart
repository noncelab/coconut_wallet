import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;

/// 수수료율 구간(ppm), 만료까지 남은 블록에 따라 달라지면 최솟값과 최댓값이 다름
class ArkFeeRate {
  const ArkFeeRate({required this.minPpm, required this.maxPpm, this.minFeeSats = 0, this.baseFeeSats = 0});

  factory ArkFeeRate.flat(int ppm, {int minFeeSats = 0, int baseFeeSats = 0}) =>
      ArkFeeRate(minPpm: ppm, maxPpm: ppm, minFeeSats: minFeeSats, baseFeeSats: baseFeeSats);

  factory ArkFeeRate.fromTable(List<bark.PpmExpiryFeeEntry> table, {int minFeeSats = 0, int baseFeeSats = 0}) {
    final ppms = table.map((entry) => entry.ppm);
    return ArkFeeRate(
      minPpm: ppms.isEmpty ? 0 : ppms.reduce((a, b) => a < b ? a : b),
      maxPpm: ppms.isEmpty ? 0 : ppms.reduce((a, b) => a > b ? a : b),
      minFeeSats: minFeeSats,
      baseFeeSats: baseFeeSats,
    );
  }

  final int minPpm;
  final int maxPpm;
  final int minFeeSats;
  final int baseFeeSats;

  /// `0.2~0.5`, `0` 형태의 퍼센트 숫자
  String get percentText {
    final min = _percent(minPpm);
    final max = _percent(maxPpm);
    return min == max ? min : '$min~$max';
  }

  static String _percent(int ppm) {
    final text = (ppm / 10000).toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

/// 아크 서버 수수료표를 동작별로 정리한 것
class ArkFeeGuide {
  const ArkFeeGuide({
    required this.lightningReceive,
    required this.lightningSend,
    required this.board,
    required this.offboard,
    required this.refresh,
  });

  factory ArkFeeGuide.fromSchedule(bark.FeeSchedule schedule) => ArkFeeGuide(
    lightningReceive: ArkFeeRate.flat(
      schedule.lightningReceive.ppm,
      baseFeeSats: schedule.lightningReceive.baseFeeSats,
    ),
    lightningSend: ArkFeeRate.fromTable(
      schedule.lightningSend.ppmExpiryTable,
      minFeeSats: schedule.lightningSend.minFeeSats,
      baseFeeSats: schedule.lightningSend.baseFeeSats,
    ),
    board: ArkFeeRate.flat(
      schedule.board.ppm,
      minFeeSats: schedule.board.minFeeSats,
      baseFeeSats: schedule.board.baseFeeSats,
    ),
    offboard: ArkFeeRate.fromTable(schedule.offboard.ppmExpiryTable, baseFeeSats: schedule.offboard.baseFeeSats),
    refresh: ArkFeeRate.fromTable(schedule.refresh.ppmExpiryTable, baseFeeSats: schedule.refresh.baseFeeSats),
  );

  /// 아크 주소 간 송금은 bark 수수료표에 항목이 없음(서버 수수료 없음)
  static const arkPayment = ArkFeeRate(minPpm: 0, maxPpm: 0);

  final ArkFeeRate lightningReceive;
  final ArkFeeRate lightningSend;
  final ArkFeeRate board;
  final ArkFeeRate offboard;
  final ArkFeeRate refresh;
}
