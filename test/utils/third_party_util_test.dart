import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getNextThirdPartyWalletName', () {
    test('키스톤 지갑이 없을 때는 기본 이름을 반환', () {
      final result = getNextThirdPartyWalletName(WalletImportSource.keystone, []);
      expect(result, '키스톤');
    });

    test('키스톤 지갑이 하나 있을 때는 "키스톤 2"를 반환', () {
      final result = getNextThirdPartyWalletName(WalletImportSource.keystone, ['키스톤']);
      expect(result, '키스톤 2');
    });

    test('키스톤 지갑이 여러 개 있을 때는 사용 가능한 다음 번호를 반환', () {
      final result = getNextThirdPartyWalletName(WalletImportSource.keystone, ['키스톤', '키스톤 2', '키스톤 3']);
      expect(result, '키스톤 4');
    });

    test('번호가 순차적이지 않을 때도 사용 가능한 다음 번호를 반환', () {
      final result = getNextThirdPartyWalletName(WalletImportSource.keystone, ['키스톤', '키스톤 2', '키스톤 4']);
      expect(result, '키스톤 3');
    });

    test('사용자가 키스톤이 포함된 지갑 이름을 수정한 경우', () {
      final result = getNextThirdPartyWalletName(WalletImportSource.keystone, ['키스톤', '키스톤2', '키스톤 4']);
      expect(result, '키스톤 2');
    });

    test('사용자가 키스톤이 포함된 지갑 이름을 수정한 경우2', () {
      final result = getNextThirdPartyWalletName(WalletImportSource.keystone, [
        '키스톤',
        '키스톤 22',
        '키스톤 333',
        '키스톤 4444',
        '키스톤 (2)',
      ]);
      expect(result, '키스톤 2');
    });

    test('시드사이너 지갑이 없을 때는 기본 이름을 반환', () {
      final result = getNextThirdPartyWalletName(WalletImportSource.seedSigner, []);
      expect(result, '시드사이너');
    });

    test('시드사이너 지갑이 하나 있을 때는 "시드사이너 2"를 반환', () {
      final result = getNextThirdPartyWalletName(WalletImportSource.seedSigner, ['시드사이너']);
      expect(result, '시드사이너 2');
    });

    test('패스포트 모델 정보가 없으면 기본 이름을 반환', () {
      final result = getNextThirdPartyWalletName(WalletImportSource.passport, []);
      expect(result, '패스포트');
    });

    test('패스포트 프라임 모델이면 "패스포트 프라임"을 반환', () {
      final result = getNextThirdPartyWalletName(
        WalletImportSource.passport,
        [],
        passportModel: 'passport-prime',
      );
      expect(result, '패스포트 프라임');
    });

    test('패스포트 코어 모델이면 "패스포트 코어"를 반환', () {
      final result = getNextThirdPartyWalletName(
        WalletImportSource.passport,
        [],
        passportModel: 'passport-core',
      );
      expect(result, '패스포트 코어');
    });

    test('패스포트 프라임 지갑이 하나 있을 때는 "패스포트 프라임 2"를 반환', () {
      final result = getNextThirdPartyWalletName(
        WalletImportSource.passport,
        ['패스포트 프라임'],
        passportModel: 'passport-prime',
      );
      expect(result, '패스포트 프라임 2');
    });

    test('코코넛볼트를 입력하면 예외 발생', () {
      expect(() => getNextThirdPartyWalletName(WalletImportSource.coconutVault, []), throwsAssertionError);
    });
  });
}
