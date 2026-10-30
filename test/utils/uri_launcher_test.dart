import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExternalLinkDestination', () {
    test('every value is a short snake_case category, not a URL', () {
      for (final destination in ExternalLinkDestination.values) {
        expect(destination.value, matches(RegExp(r'^[a-z][a-z_]*$')), reason: destination.name);
      }
    });

    test('values are unique', () {
      final values = ExternalLinkDestination.values.map((destination) => destination.value).toList();
      expect(values.toSet(), hasLength(values.length));
    });
  });
}
