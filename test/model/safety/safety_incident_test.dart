import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final detectedAt = DateTime(2026, 10, 20, 9);
  final now = DateTime(2026, 10, 20, 10);
  final detected = SafetyIncident(walletId: 1, txid: 'abc', detectedAt: detectedAt);

  test('id is walletId:txid', () {
    expect(detected.id, '1:abc');
  });

  group('transitions', () {
    test('detected → recognized', () {
      final recognized = detected.recognize(now);
      expect(recognized.state, IncidentState.recognized);
      expect(recognized.resolvedAt, now);
    });

    test('detected → responding → recognized | completed', () {
      final responding = detected.respond(IncidentResponseMode.premium);
      expect(responding.state, IncidentState.responding);
      expect(responding.responseMode, IncidentResponseMode.premium);
      expect(responding.recognize(now).state, IncidentState.recognized);
      final completed = responding.complete(now);
      expect(completed.state, IncidentState.completed);
      expect(completed.resolvedAt, now);
      expect(completed.responseMode, IncidentResponseMode.premium);
    });

    test('responding → responding switches only the mode (Free guide then Premium, or Premium expired)', () {
      final free = detected.respond(IncidentResponseMode.free).withGuideStep(2, assistStartedAt: now);
      final premium = free.respond(IncidentResponseMode.premium);
      expect(premium.state, IncidentState.responding);
      expect(premium.responseMode, IncidentResponseMode.premium);
      expect((premium.guideStep, premium.assistStartedAt, premium.detectedAt), (2, now, detectedAt));
      expect(premium.respond(IncidentResponseMode.free).responseMode, IncidentResponseMode.free);
    });

    test('invalid transitions throw StateError', () {
      final recognized = detected.recognize(now);
      final responding = detected.respond(IncidentResponseMode.free);
      final completed = responding.complete(now);
      expect(() => detected.complete(now), throwsStateError);
      expect(() => recognized.respond(IncidentResponseMode.free), throwsStateError);
      expect(() => recognized.recognize(now), throwsStateError);
      expect(() => recognized.complete(now), throwsStateError);
      expect(() => completed.recognize(now), throwsStateError);
      expect(() => completed.respond(IncidentResponseMode.free), throwsStateError);
      expect(() => completed.complete(now), throwsStateError);
    });
  });

  test('critical only while open and the tx is pending or confirmed; disappeared tx is info', () {
    expect(detected.isCritical, isTrue);
    expect(detected.withTxState(IncidentTxState.confirmed).isCritical, isTrue);
    expect(detected.respond(IncidentResponseMode.free).isCritical, isTrue);
    for (final gone in [IncidentTxState.replaced, IncidentTxState.dropped]) {
      final info = detected.withTxState(gone);
      expect(info.isCritical, isFalse);
      expect(info.isInfo, isTrue);
      // 다시 나타나면 위급
      expect(info.withTxState(IncidentTxState.pending).isCritical, isTrue);
    }
    final recognized = detected.recognize(now);
    expect(recognized.isOpen, isFalse);
    expect(recognized.isCritical, isFalse);
    expect(recognized.isInfo, isFalse);
  });

  test('withGuideStep keeps the first assist start time unless given', () {
    final started = detected.withGuideStep(2, assistStartedAt: now);
    expect(started.guideStep, 2);
    expect(started.withGuideStep(3).assistStartedAt, now);
  });

  test('JSON round trip', () {
    final incident = detected
        .respond(IncidentResponseMode.premium)
        .withTxState(IncidentTxState.replaced)
        .withGuideStep(1, assistStartedAt: now);
    expect(SafetyIncident.fromJson(incident.toJson()), incident);
    expect(SafetyIncident.fromJson(detected.toJson()), detected);
  });

  test('unknown state name throws (state loader falls back to initial)', () {
    expect(() => SafetyIncident.fromJson({...detected.toJson(), 'state': 'hacked'}), throwsArgumentError);
  });
}
