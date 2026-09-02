import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:flutter_test/flutter_test.dart';

/// gap limit(kSubscriptionGapLimit=20) 트레일링 윈도우가 하한(usedIndex 초과) 없이 상한만 체크하던
/// 버그 재현 및 수정 검증. usedIndex보다 훨씬 낮은 인덱스의 미사용 주소가 "모니터링 중"으로 잘못
/// 표시되던 문제(라이브 테스트로 발견: usedIndex=207인데 index 32~37이 watched로 표시됨).
void main() {
  WalletAddress buildAddress({required int index, required bool isUsed, int total = 0, int unconfirmed = 0}) {
    return WalletAddress('address_$index', "m/0'/0/$index", index, false, isUsed, 0, unconfirmed, total);
  }

  group('isAddressWatched 테스트', () {
    test('usedIndex보다 훨씬 낮은 미사용 주소는 gap 윈도우 밖이므로 watched가 아니다', () {
      final address = buildAddress(index: 32, isUsed: false);
      expect(isAddressWatched(address, 207), isFalse);
    });

    test('usedIndex와 같은 인덱스가 미사용이면(이론상 발생하지 않지만) watched가 아니다', () {
      final address = buildAddress(index: 207, isUsed: false);
      expect(isAddressWatched(address, 207), isFalse);
    });

    test('usedIndex 바로 다음 인덱스(gap 윈도우 시작)는 watched다', () {
      final address = buildAddress(index: 208, isUsed: false);
      expect(isAddressWatched(address, 207), isTrue);
    });

    test('usedIndex + gapLimit 인덱스(gap 윈도우 끝)는 watched다', () {
      final address = buildAddress(index: 227, isUsed: false);
      expect(isAddressWatched(address, 207), isTrue);
    });

    test('usedIndex + gapLimit을 넘어선 미사용 주소는 watched가 아니다', () {
      final address = buildAddress(index: 228, isUsed: false);
      expect(isAddressWatched(address, 207), isFalse);
    });

    test('사용된 주소는 잔액이 있으면 인덱스와 무관하게 watched다', () {
      final address = buildAddress(index: 17, isUsed: true, total: 50000);
      expect(isAddressWatched(address, 207), isTrue);
    });

    test('사용된 주소는 잔액도 미확정도 없으면(dormant) watched가 아니다', () {
      final address = buildAddress(index: 17, isUsed: true, total: 0, unconfirmed: 0);
      expect(isAddressWatched(address, 207), isFalse);
    });
  });
}
