import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/home_edit_analytics.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Analytics extends AnalyticsService {
  _Analytics() : super(null, true);

  final List<({String name, Map<String, Object> parameters})> events = [];

  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {
    events.add((name: eventName, parameters: AnalyticsService.normalizeParameters(parameters)));
  }
}

void main() {
  test('leaving Edit Home logs one event with only whether it changed and whether a preset was applied', () {
    final analytics = _Analytics();

    analytics.logHomeEditCompleted(changed: true, presetApplied: false);

    expect(analytics.events.single.name, AnalyticsEventNames.homeEditCompleted);
    expect(analytics.events.single.parameters, {'changed': 'true', 'preset_applied': 'false'});
  });
}
