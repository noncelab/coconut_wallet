import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/floresta/floresta_descriptor_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// 명령어: flutter test test/services/floresta/floresta_descriptor_codec_test.dart
void main() {
  group('FlorestaDescriptorCodec.encode', () {
    setUp(() => NetworkType.setNetworkType(NetworkType.regtest));

    const tpub = "tpubDCgpPjaDSGcbRYeVVYdR5M5cBeUqx1TNdKFZsoGqiV5JoT7L6CZbwv7on5BznNT7631ri4uGew2brp5L2NXvindG2a4qvJw9oLXsfGeD7Mi";
    const vpub =
        "vpub5YefGAQhRdaBTA5QNe55TFZEWb6J5NyKFTcpxTRvcZZewxpAWfPPZM8hVdC3G4C2UrFLbYCHCWVTQ4MbC7rfEsomEHvh4xdwfvpB88X9Tyr";

    test('SLIP-132 vpub를 표준 tpub로 변환하고 체크섬을 제거한다', () {
      const vpubDescriptor = "wpkh([85888852/84'/1'/0']$vpub/0/*)#0fnxuu0y";
      const expected = "wpkh([85888852/84'/1'/0']$tpub/0/*)";

      expect(FlorestaDescriptorCodec.encode(vpubDescriptor), [expected]);
    });

    test('이미 표준 tpub인 디스크립터는 변경하지 않는다', () {
      const tpubDescriptor = "wpkh([85888852/84'/1'/0']$tpub/0/*)#abcdefgh";

      expect(FlorestaDescriptorCodec.encode(tpubDescriptor), [tpubDescriptor]);
    });

    test('multipath <0;1> 디스크립터를 단일 경로 2개로 분해한다', () {
      const vpubDescriptor = "wpkh([85888852/84'/1'/0']$vpub/<0;1>/*)#0fnxuu0y";
      final result = FlorestaDescriptorCodec.encode(vpubDescriptor);

      expect(result.length, 2);
      expect(result[0], "wpkh([85888852/84'/1'/0']$tpub/0/*)");
      expect(result[1], "wpkh([85888852/84'/1'/0']$tpub/1/*)");
    });
  });
}
