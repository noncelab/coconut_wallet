import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/services/network/socket/socket_factory.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// 테스트 전용으로 생성한 self-signed 인증서/개인키
// 실제 서비스와 무관한 더미 값이며 이 테스트가 로컬 TLS 서버를 띄우기 위한 용도로만 사용된다.
const _testCertPem = '''
-----BEGIN CERTIFICATE-----
MIICuDCCAaACCQDKf4EcMbQWHjANBgkqhkiG9w0BAQsFADAeMRwwGgYDVQQDDBNj
b2NvbnV0LXdhbGxldC10ZXN0MB4XDTI2MDkwMjA0MjU0MFoXDTM2MDgzMDA0MjU0
MFowHjEcMBoGA1UEAwwTY29jb251dC13YWxsZXQtdGVzdDCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAK6aS3MG3GHswFOaekhYbO/BQ7qxWuNLoakDE6GJ
imuF/3r5EvLEJ5pIJwKEeWVlIUtJ9lg4UC/6+NvVo+lUdmuWXDuFf8wRaFqEImGZ
/7ZDfpxBNq+SqbBr4xc5zBJTJsUGeO6Ktj0CaKldYzFFHfYkNZt5SdlXGwtSV305
rUZU0nLbK15bqCtlOmsfbYgGt0zgjYp5OWEDCxYOtZPo8snK/nqQYkGu/B2kvlyj
WEAwhu77L49XFHdUIp6spThH88SlksuXeNvk6Ai212dcQiv/cYPaTSsNOoxUoiSW
BraB+Kakd79IaJ4fk5ejScAaIUF7tWeKgdpQExfrMETj4gECAwEAATANBgkqhkiG
9w0BAQsFAAOCAQEAZUghJY/jDaxt5WNyBz9vH46PpNX+q6vnPpJVTFo1v/BjFwcI
BxICS0b27aNadVT1+MKEAAZybnG5peNovbVarkapS37j/PvgCHmfMDVur9hzbtMf
E48lb4o+PHfIbAgiZlcx5LtjUOJ+vPeC76xs0B4B468RIzjaOWpuInw+S0jVQ1KJ
4HKO/hxdIT1hE9j0XaO7sxP+mArrmjDQM04i0H2tKEN8RGl389Xk/hAwQ74exKJJ
d2dma7t/xgNYHvc5L7G2FtTOTgtfEj9KB8bZO9g6tIr8K/nELyHS1PSHhTtNPslx
tGmpEszTsabuDV8S/5xcd1cjrZkfF0LNls+4Xg==
-----END CERTIFICATE-----
''';

const _testKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCumktzBtxh7MBT
mnpIWGzvwUO6sVrjS6GpAxOhiYprhf96+RLyxCeaSCcChHllZSFLSfZYOFAv+vjb
1aPpVHZrllw7hX/MEWhahCJhmf+2Q36cQTavkqmwa+MXOcwSUybFBnjuirY9Amip
XWMxRR32JDWbeUnZVxsLUld9Oa1GVNJy2yteW6grZTprH22IBrdM4I2KeTlhAwsW
DrWT6PLJyv56kGJBrvwdpL5co1hAMIbu+y+PVxR3VCKerKU4R/PEpZLLl3jb5OgI
ttdnXEIr/3GD2k0rDTqMVKIklga2gfimpHe/SGieH5OXo0nAGiFBe7VnioHaUBMX
6zBE4+IBAgMBAAECggEBAIxHAGkY0QSHvnksuiPXjyYMosqiZQAKKoZsJ2B37VK3
pGt7IwMSHzMv1s+J+TJCTr57XMTB8YKq4zdTbE4xArcrZUyY0/Ty42EdmbXKkQwx
K86EAliKv3QzKY7ma5MpZROUQKJ9pS5c+hNgKSpTel/f9YXEq1VHSz4MWKgOJ61B
csNxE3mw6pX48Op9LQlXVZt3V1GtgceMsCSdTmi392YWMzHIHhXIROzgbna0mHHf
jrxQvRyHseFEJN66OLnaTKmbs00SomqZxzT8G68VC4m0xg3gdV/gGU3CAVZBtA/I
NXxBU/oJT8rwP5OpSKmmNF3ahBhiTfF48sjuI2RH1HECgYEA2M0SqXDO4AHGDPpZ
uW7hfJHzxrpHD6haP+mVW3FxIWtj/BEW6H+cnPstLOLKdN1NJvGjzZtDIQSOpMl3
PR/rSf/6GKdUCcRRqPCGQxNL0KcUFLFQxWiHc0uvO0nc8XoTur1Zw01RfZWdePEV
tJwlLNfubiLpkpY5VkhOW3p0bSUCgYEAziwDwuoytis1h/vdUhZLYwXQm2ttMgZ/
f0Qxku7CNMmABK7C/DOlmFSrqcVUbnPQGBX3FVdcgUJTfvTjnFKYIgVkK9DK5HDR
Dur57pEKR723S97IPA08JaKAo7sAwd/VBg8ayxrzz+Wm9eijaVa9xoxv/CZ8ros4
gMZ8qtlToK0CgYAaHgJMhTl2xN/t+k7Kxu/FCPQcEZ6z5S0SG/qRLIZbZ0uBNzHS
SmU8iAm2KZAIKgy8T0nTYAvjM2BXu6lwpKK8pGilharbDlpkBq218OImPapun7nC
Pkhq/Egc1VYXhQRRb7QbkfnqLhbtVeWuf0z/LPgdLnmC3jQED+vYm1ThPQKBgC+9
8YEJSoT0rIi4wh9oGjzr88qJrdePuaZ23CPyNfaTUpnC/lP4gbgsozPFBjAtkVqC
e5zthfZIrZ0QiESCu8flB7U9vD36Ae86anXcEE1cmT1wcV22kt8EKlW/0AUVF/c3
ODUgIKVbwLXhETYrZ/a6PpRdNTIV+xeW3veRK9RhAoGBAI+j/WGw6MDMO1ZAw/+v
WHFLbJcXvmjanwPJk9lyVfZ9aeXzSpI9fzlGN6WP9Y+NwOesNZSu+FTfwTnTCcqh
ms4xAhAP9sBWXTOoFZbeWzpGxmwM6vbKkpbn0GBEWbeK2Q8luIc6fIR/OzCe2w0m
skkV/ZeWgrUuYrt1s7cbaQ8u
-----END PRIVATE KEY-----
''';

/// PEM 텍스트 안의 DER(base64) 바이트를 프로덕션 코드와 무관하게 직접 추출한다.
/// CertificateUtil을 거치지 않고 "기대값"을 독립적으로 계산하기 위함이다.
List<int> _derBytesFromPem(String pem) {
  final base64Body = pem.split('\n').where((line) => line.isNotEmpty && !line.startsWith('-----')).join();
  return base64Decode(base64Body);
}

void main() {
  group('DefaultSocketFactory 인증서 핀닝 테스트', () {
    late SecureServerSocket server;
    late String expectedFingerprint;

    setUpAll(() async {
      final context =
          SecurityContext()
            ..useCertificateChainBytes(utf8.encode(_testCertPem))
            ..usePrivateKeyBytes(utf8.encode(_testKeyPem));

      server = await SecureServerSocket.bind(InternetAddress.loopbackIPv4, 0, context);
      // 일부 테스트 케이스는 클라이언트가 핸드셰이크를 의도적으로 거부하므로,
      // 서버 쪽에서도 핸드셰이크 실패가 스트림 에러로 발생할 수 있다 - 무시한다.
      server.listen((socket) {
        socket.close();
      }, onError: (_) {});

      expectedFingerprint =
          sha256
              .convert(_derBytesFromPem(_testCertPem))
              .bytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
    });

    tearDownAll(() async {
      await server.close();
    });

    test('pinnedFingerprint 없이 self-signed 서버에 연결하면 거부된다', () async {
      final factory = DefaultSocketFactory();

      expect(() => factory.createSecureSocket('localhost', server.port), throwsA(isA<HandshakeException>()));
    });

    test('잘못된 pinnedFingerprint로는 연결이 거부된다', () async {
      final factory = DefaultSocketFactory();

      expect(
        () => factory.createSecureSocket(
          'localhost',
          server.port,
          pinnedFingerprint:
              'AA:BB:CC:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00',
        ),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('정확한 pinnedFingerprint로는 연결이 허용된다', () async {
      final factory = DefaultSocketFactory();

      final socket = await factory.createSecureSocket('localhost', server.port, pinnedFingerprint: expectedFingerprint);

      expect(socket, isNotNull);
      await socket.close();
    });

    test('peekCertificate는 신뢰 여부와 무관하게 서버 인증서를 반환한다', () async {
      final factory = DefaultSocketFactory();

      final cert = await factory.peekCertificate('localhost', server.port);

      expect(cert, isNotNull);
    });
  });
}
