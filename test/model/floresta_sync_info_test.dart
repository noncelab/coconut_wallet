import 'package:coconut_wallet/model/node/floresta_sync_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlorestaSyncInfo.fromRpc', () {
    test('최신 Floresta(Core-style 필드)를 파싱한다', () {
      final info = FlorestaSyncInfo.fromRpc({
        'blocks': 100,
        'headers': 120,
        'verificationprogress': 0.83,
        'initialblockdownload': true,
        'bestblockhash': 'abc',
        'time': 1700000000,
      });

      expect(info.blocks, 100);
      expect(info.headers, 120);
      expect(info.verificationProgress, closeTo(0.83, 1e-9));
      expect(info.initialBlockDownload, isTrue);
      expect(info.bestBlockHash, 'abc');
      expect(info.time, 1700000000);
      expect(info.isSynced, isFalse);
    });

    test('구버전 Floresta(v0.9.x: height/validated/ibd/progress)를 파싱한다', () {
      final info = FlorestaSyncInfo.fromRpc({
        'height': 110,
        'validated': 110,
        'ibd': false,
        'progress': 1.0,
        'best_block': 'def',
        'latest_block_time': 1700000001,
      });

      expect(info.blocks, 110);
      expect(info.headers, 110);
      expect(info.verificationProgress, 1.0);
      expect(info.initialBlockDownload, isFalse);
      expect(info.bestBlockHash, 'def');
      expect(info.time, 1700000001);
      expect(info.isSynced, isTrue);
    });

    test('빈 응답은 안전한 기본값으로 처리한다', () {
      final info = FlorestaSyncInfo.fromRpc(const {});
      expect(info.blocks, 0);
      expect(info.initialBlockDownload, isFalse);
      expect(info.isSynced, isFalse);
    });

    // ibd=false여도 새 블록을 따라가는 중이면 동기화 완료가 아니다.
    test('ibd=false + blocks < headers 는 isSynced가 아니다', () {
      final info = FlorestaSyncInfo.fromRpc({
        'blocks': 141,
        'headers': 148,
        'verificationprogress': 1.0,
        'initialblockdownload': false,
      });
      expect(info.isSynced, isFalse);
      expect(info.headers - info.blocks, 7);
    });
  });
}
