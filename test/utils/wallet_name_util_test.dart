import 'package:coconut_wallet/utils/wallet_name_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletNameUtil.findAvailableDefaultName', () {
    String findName(List<String> existingNames) {
      return WalletNameUtil.findAvailableDefaultName(
        existingNames: existingNames,
        firstName: '내 지갑',
        numberedName: (number) => '내 지갑 $number',
      );
    }

    test('기본 이름이 비어 있으면 번호 없는 이름을 반환한다', () {
      expect(findName([]), '내 지갑');
    });

    test('연속된 이름이 있으면 다음 번호를 반환한다', () {
      expect(findName(['내 지갑', '내 지갑 2', '내 지갑 3']), '내 지갑 4');
    });

    test('중간 번호가 비어 있으면 가장 작은 빈 번호를 재사용한다', () {
      expect(findName(['내 지갑', '내 지갑 3']), '내 지갑 2');
    });
  });
}
