import 'dart:async';

import 'package:coconut_wallet/services/security/hot_wallet_lifecycle_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('동시에 요청된 핫월렛 생명주기 작업을 순서대로 실행한다', () async {
    final lock = HotWalletLifecycleLock();
    final firstGate = Completer<void>();
    final events = <String>[];

    final first = lock.synchronized(() async {
      events.add('first-start');
      await firstGate.future;
      events.add('first-end');
    });
    final second = lock.synchronized(() async {
      events.add('second-start');
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['first-start']);

    firstGate.complete();
    await Future.wait([first, second]);
    expect(events, ['first-start', 'first-end', 'second-start']);
  });

  test('잠금 내부에서 같은 잠금을 다시 사용해도 교착되지 않는다', () async {
    final lock = HotWalletLifecycleLock();

    final result = await lock.synchronized(() {
      return lock.synchronized(() async => 7);
    });

    expect(result, 7);
  });

  test('앞선 작업이 실패해도 다음 작업을 실행한다', () async {
    final lock = HotWalletLifecycleLock();

    await expectLater(lock.synchronized<void>(() async => throw StateError('failed')), throwsStateError);
    expect(await lock.synchronized(() async => 'completed'), 'completed');
  });
}
