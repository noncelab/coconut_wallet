/// 애널리틱스 파라미터로 보내기 전에 원래 값을 전송용 문자열로 바꾼다.
///
/// 경과 시간처럼 사용자 행동을 정밀하게 드러낼 수 있는 값은 원래 값 대신 구간으로 묶어 보낸다.
/// GA4에 쌓인 뒤 구간 경계를 바꾸면 과거 데이터와 비교할 수 없으므로 경계를 바꿀 때는
/// test/analytics/analytics_test.dart를 함께 고친다.
class AnalyticsValueFormatter {
  /// 핫월렛 생성 시각부터 [now](기본값: 현재 시각)까지의 경과 시간을 구간으로 바꾼다.
  ///
  /// `lt1h`(1시간 미만) / `1to24h`(1시간 이상 24시간 미만) / `1to7d`(24시간 이상 7일 미만) / `gt7d`(7일 이상)
  static String sinceCreated(DateTime createdAt, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(createdAt);
    if (elapsed < const Duration(hours: 1)) return 'lt1h';
    if (elapsed < const Duration(hours: 24)) return '1to24h';
    if (elapsed < const Duration(days: 7)) return '1to7d';
    return 'gt7d';
  }
}
