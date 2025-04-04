import 'package:coconut_wallet/repository/realm/wallet_data_manager_cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WalletDataManagerCryptography should encrypt text correctly', () async {
    // 테스트에 필요한 값들 설정
    const hashedPin = 'hashedPinValue'; // 테스트용 핀 값
    const plainText = 'test message'; // 암호화할 평문 메시지
    const iterations = 100; // 적절한 반복 횟수 설정

    final cipher = WalletDataManagerCryptography(nonce: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    await cipher.initialize(iterations: iterations, hashedPin: hashedPin);

    final encrypted = await cipher.encrypt(plainText);

    // 암호화된 결과는 base64로 인코딩된 문자열이므로, 그 값이 비어 있지 않음을 확인
    expect(encrypted, isNotEmpty);

    final decrypted = await cipher.decrypt(encrypted);
    expect(decrypted, plainText);
  });
}
