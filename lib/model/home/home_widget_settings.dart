import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:collection/collection.dart';

enum HomeWidgetPeriod {
  week(7),
  month(30),
  threeMonths(90),
  year(365),

  /// 첫 거래부터 지금까지
  /// 일수는 지갑마다 달라서 쓰는 곳에서 정한다. 호들 인사이트에서만 쓴다.
  all(0);

  final int days;

  const HomeWidgetPeriod(this.days);

  /// 위젯 설정에서 고를 수 있는 기간
  static const widgetPeriods = [week, month, threeMonths, year];
}

/// 통화 설정 방삭
/// [single]은 하나만, [multiple]은 [HomeWidgetSettingsSpec.maxCurrencies]개까지 고른다.
enum HomeWidgetCurrencyMode { none, single, multiple }

/// 위젯 정의가 지원하는 설정 항목
class HomeWidgetSettingsSpec {
  final bool wallets;
  final HomeWidgetCurrencyMode currencies;
  final int maxCurrencies;
  final bool period;

  /// 고를 수 있는 기간
  /// 법정화폐 추이처럼 과거 시세가 짧은 위젯은 일부만 연다.
  final List<HomeWidgetPeriod> periods;
  final bool fakeBalance;

  /// 지갑별 목표 수량 입력
  /// 값은 위젯이 아니라 지갑에 저장한다.
  final bool goals;

  /// 고를 수 있는 위젯 크기
  /// 고른 크기는 [HomeItem.span]에 저장한다.
  final List<HomeSpan> sizes;

  const HomeWidgetSettingsSpec({
    this.wallets = false,
    this.currencies = HomeWidgetCurrencyMode.none,
    this.maxCurrencies = 1,
    this.period = false,
    this.periods = HomeWidgetPeriod.widgetPeriods,
    this.fakeBalance = false,
    this.goals = false,
    this.sizes = const [],
  });

  bool get isEmpty =>
      !wallets && currencies == HomeWidgetCurrencyMode.none && !period && !fakeBalance && !goals && sizes.isEmpty;
}

/// 홈에 놓인 위젯 하나의 설정값
/// [HomeItem.configuration]에 저장한다. 값이 없으면 기본값(전체 지갑, 앱 기본 통화, 1주)을 쓴다.
class HomeWidgetSettings {
  static const _walletIdsKey = 'walletIds';
  static const _fiatsKey = 'fiats';
  static const _periodKey = 'period';

  /// null이면 전체 지갑
  final List<int>? walletIds;
  final List<FiatCode>? fiats;
  final HomeWidgetPeriod? period;

  /// 고른 위젯 크기
  /// 설정값이 아니라 [HomeItem.span]으로 저장하므로 [toConfiguration]에는 넣지 않는다.
  final HomeSpan? span;

  const HomeWidgetSettings({this.walletIds, this.fiats, this.period, this.span});

  factory HomeWidgetSettings.fromConfiguration(Map<String, Object?> configuration) {
    final walletIds = configuration[_walletIdsKey];
    final fiats = configuration[_fiatsKey];
    final period = configuration[_periodKey];
    final parsedFiats =
        fiats is List
            ? fiats.map((code) => FiatCode.values.firstWhereOrNull((fiat) => fiat.code == code)).nonNulls.toList()
            : null;
    return HomeWidgetSettings(
      walletIds: walletIds is List ? walletIds.whereType<int>().toList() : null,
      fiats: parsedFiats == null || parsedFiats.isEmpty ? null : parsedFiats,
      period: HomeWidgetPeriod.values.firstWhereOrNull((value) => value.name == period),
    );
  }

  Map<String, Object?> toConfiguration() => {
    if (walletIds != null) _walletIdsKey: walletIds,
    if (fiats != null) _fiatsKey: [for (final fiat in fiats!) fiat.code],
    if (period != null) _periodKey: period!.name,
  };

  int get days => (period ?? HomeWidgetPeriod.week).days;

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetSettings &&
      const ListEquality<int>().equals(other.walletIds, walletIds) &&
      const ListEquality<FiatCode>().equals(other.fiats, fiats) &&
      other.period == period &&
      other.span == span;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(walletIds ?? const []), Object.hashAll(fiats ?? const []), period, span);
}
