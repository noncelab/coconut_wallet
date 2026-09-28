import 'dart:math';

import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/receive_analytics.dart';
import 'package:coconut_wallet/analytics/wallet_resync_analytics.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsService receive interaction', () {
    late DateTime now;
    late AnalyticsService analytics;

    setUp(() {
      now = DateTime.utc(2026, 9, 28);
      analytics = AnalyticsService(null, true, now: () => now, secureRandom: Random(7));
    });

    test('같은 지갑의 후속 이벤트는 30분 동안 같은 임시 ID로 연결한다', () {
      final interactionId = analytics.startReceiveInteraction(11);

      expect(interactionId, hasLength(22));
      expect(analytics.activeReceiveInteractionId(11), interactionId);
      expect(analytics.activeReceiveInteractionId(12), isNull);

      now = now.add(const Duration(minutes: 29, seconds: 59));
      expect(analytics.activeReceiveInteractionId(11), interactionId);
    });

    test('30분이 지나면 연결을 폐기한다', () {
      analytics.startReceiveInteraction(11);

      now = now.add(AnalyticsService.receiveInteractionTtl);

      expect(analytics.activeReceiveInteractionId(11), isNull);
    });

    test('같은 지갑에서 새 받기 화면을 열면 임시 ID를 교체한다', () {
      final first = analytics.startReceiveInteraction(11);
      final second = analytics.startReceiveInteraction(11);

      expect(second, isNot(first));
      expect(analytics.activeReceiveInteractionId(11), second);
    });

    test('받기 이벤트는 지갑 정보 없이 같은 임시 ID만 전송한다', () {
      final recording = _RecordingAnalyticsService(now: () => now);
      final interactionId = recording.startReceiveInteraction(11);

      recording.logReceiveQrShown(11);
      recording.logReceiveAddressCopied(11);
      recording.logReceiveDepositDetected(11);
      recording.logReceiveWalletSynced(11);

      expect(recording.events.map((event) => event.name), [
        AnalyticsEventNames.receiveQrShown,
        AnalyticsEventNames.receiveAddressCopied,
        AnalyticsEventNames.receiveDepositDetected,
        AnalyticsEventNames.receiveWalletSynced,
      ]);
      for (final event in recording.events) {
        expect(event.parameters, {'receive_interaction_id': interactionId});
        expect(event.parameters.keys, isNot(contains('wallet_id')));
        expect(event.parameters.keys, isNot(contains('address')));
        expect(event.parameters.keys, isNot(contains('txid')));
        expect(event.parameters.keys, isNot(contains('amount')));
      }
      expect(recording.activeReceiveInteractionId(11), isNull);
    });

    test('재동기화 로거는 시작, 성공, 실패 이벤트를 등록한다', () {
      final recording = _RecordingAnalyticsService(now: () => now);

      recording.logWalletResyncStarted();
      recording.logWalletResyncCompleted();
      recording.logWalletResyncFailed();

      expect(recording.events.map((event) => event.name), [
        AnalyticsEventNames.walletResyncStarted,
        AnalyticsEventNames.walletResyncCompleted,
        AnalyticsEventNames.walletResyncFailed,
      ]);
    });

    test('입금 감지 전 일반 동기화는 임시 ID를 폐기하지 않는다', () {
      final recording = _RecordingAnalyticsService(now: () => now);
      final interactionId = recording.startReceiveInteraction(11);

      recording.logReceiveWalletSynced(11);

      expect(recording.events, isEmpty);
      expect(recording.activeReceiveInteractionId(11), interactionId);

      recording.logReceiveDepositDetected(11);
      recording.logReceiveWalletSynced(11);

      expect(recording.events.map((event) => event.name), [
        AnalyticsEventNames.receiveDepositDetected,
        AnalyticsEventNames.receiveWalletSynced,
      ]);
      expect(recording.activeReceiveInteractionId(11), isNull);
    });
  });
}

class _RecordingAnalyticsService extends AnalyticsService {
  final List<({String name, Map<String, Object> parameters})> events = [];

  _RecordingAnalyticsService({required DateTime Function() now}) : super(null, true, now: now, secureRandom: Random(8));

  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {
    events.add((name: eventName, parameters: {...?parameters}));
  }
}
