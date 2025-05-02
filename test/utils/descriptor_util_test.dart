import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:flutter_test/flutter_test.dart';

/// 명령어: flutter test test/utils/descriptor_util_test.dart
void main() {
  group('DescriptorUtil', () {
    group('getDescriptorFunction', () {
      test('wpkh 함수 추출', () {
        const descriptor =
            'wpkh([76223a6f/84"/0"/0"]tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)#n9g32cn0';
        expect(DescriptorUtil.getDescriptorFunction(descriptor), 'wpkh');
      });

      test('sh 함수 추출', () {
        const descriptor =
            'sh(wpkh([76223a6f/84"/0"/0"]tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*))';
        expect(DescriptorUtil.getDescriptorFunction(descriptor), 'sh');
      });

      test('wsh 함수 추출', () {
        const descriptor = 'wsh(multi(2,[76223a6f/84"/0"/0"]tpub1,[76223a6f/84"/0"/0"]tpub2))';
        expect(DescriptorUtil.getDescriptorFunction(descriptor), 'wsh');
      });

      test('함수가 없는 디스크립터는 null 반환', () {
        const descriptor =
            '[76223a6f/84"/0"/0"]tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*';
        expect(DescriptorUtil.getDescriptorFunction(descriptor), null);
      });

      test('지원하지 않는 함수는 null 반환', () {
        const descriptor =
            'unknown([76223a6f/84"/0"/0"]tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)';
        expect(DescriptorUtil.getDescriptorFunction(descriptor), null);
      });

      test('잘못된 형식의 디스크립터는 null 반환', () {
        const descriptor = 'invalid-descriptor';
        expect(DescriptorUtil.getDescriptorFunction(descriptor), null);
      });
    });

    group('extractPurpose', () {
      test('올바른 디스크립터에서 purpose를 추출', () {
        const descriptor =
            'wpkh([76223a6f/84\'/0\'/0\']tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)#n9g32cn0';
        expect(DescriptorUtil.extractPurpose(descriptor), '84');
      });

      test('purpose가 없는 디스크립터는 예외 발생', () {
        const descriptor =
            'wpkh([76223a6f]tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)#n9g32cn0';
        expect(() => DescriptorUtil.extractPurpose(descriptor), throwsException);
      });

      test('잘못된 형식의 디스크립터는 예외 발생', () {
        const descriptor = 'invalid-descriptor';
        expect(() => DescriptorUtil.extractPurpose(descriptor), throwsException);
      });
    });

    group('validatePurpose', () {
      test('올바른 purpose는 예외를 발생시키지 않음', () {
        expect(() => DescriptorUtil.validatePurpose('84'), returnsNormally);
      });

      test('잘못된 purpose는 예외 발생', () {
        expect(() => DescriptorUtil.validatePurpose('44'), throwsException);
      });
    });

    group('hasDescriptorChecksum', () {
      test('체크섬이 있는 디스크립터 확인', () {
        const descriptor =
            'wpkh([76223a6f/84\'/0\'/0\']tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)#n9g32cn0';
        expect(DescriptorUtil.hasDescriptorChecksum(descriptor), true);
      });

      test('체크섬이 없는 디스크립터 확인', () {
        const descriptor =
            'wpkh([76223a6f/84\'/0\'/0\']tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)';
        expect(DescriptorUtil.hasDescriptorChecksum(descriptor), false);
      });

      test('잘못된 체크섬 형식 확인', () {
        const descriptor =
            'wpkh([76223a6f/84\'/0\'/0\']tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)#invalid';
        expect(DescriptorUtil.hasDescriptorChecksum(descriptor), false);
      });

      test('공백이 있는 디스크립터 처리', () {
        const descriptor =
            '  wpkh([76223a6f/84\'/0\'/0\']tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)#n9g32cn0  ';
        expect(DescriptorUtil.hasDescriptorChecksum(descriptor), true);
      });
    });

    group('normalizeDescriptor', () {
      test('wtttttttt', () {
        const descriptor =
            "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)";
        expect(DescriptorUtil.normalizeDescriptor(descriptor), descriptor);
      });

      test('함수가 없는 디스크립터는 wpkh로 감싸짐', () {
        const descriptor =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*";
        expect(DescriptorUtil.normalizeDescriptor(descriptor), 'wpkh($descriptor)');
      });

      test('체크섬이 있는 디스크립터 처리', () {
        // 잘못된 체크섬 로직 검증(영문, 숫자 8개)
        const descriptor =
            "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)";
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor#test"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor#test2"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor#test3"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor#AAAA"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor#AAAAAAAAA"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor#논스랩"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor#코코넛"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor#월렛"), throwsException);
      });

      test('체크섬이 없는 디스크립터 처리', () {
        const descriptor =
            "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)";
        const descriptor2 =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*";
        expect(DescriptorUtil.normalizeDescriptor(descriptor), isNotEmpty);
        expect(DescriptorUtil.normalizeDescriptor(descriptor2), isNotEmpty);
      });

      test('잘못된 purpose를 가진 디스크립터는 예외 발생', () {
        const descriptor =
            'wpkh([76223a6f/44\'/0\'/0\']tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)#n9g32cn0';
        expect(() => DescriptorUtil.normalizeDescriptor(descriptor), throwsException);
      });

      test('지원하지 않는 함수는 예외 발생', () {
        const descriptor =
            'sh([76223a6f/84\'/0\'/0\']tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)#n9g32cn0';
        expect(() => DescriptorUtil.normalizeDescriptor(descriptor), throwsException);
      });

      test('잘못된 형식의 디스크립터는 예외 발생', () {
        const descriptor = 'invalid-descriptor';
        expect(() => DescriptorUtil.normalizeDescriptor(descriptor), throwsException);

        const descriptor2 =
            "([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)";
        expect(() => DescriptorUtil.normalizeDescriptor("test$descriptor2"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("1234$descriptor2"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("hello$descriptor2"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("Nonce$descriptor2"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("labCoconut$descriptor2"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("코코넛월렛$descriptor2"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("POW$descriptor2"), throwsException);
      });

      test("내부적으로 수정된 Descriptor의 중괄호 개수가 각각 1개여야 한다.", () {
        const descriptor =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg";
        // 정상 케이스
        expect(DescriptorUtil.normalizeDescriptor("wpkh($descriptor)"), isNotEmpty);
        expect(DescriptorUtil.normalizeDescriptor(descriptor), isNotEmpty);

        // 비정상 케이스
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor((()"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor()())"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor((()))"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(()()($descriptor)"), throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("wpkh())))((($descriptor)"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh()(($descriptor)"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(()()()$descriptor((()"),
            throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(((()))$descriptor((()"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("wpkh())))$descriptor((()"), throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub()()()5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATG()()()asJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub((((5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLY)))))gfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub((((5YSvHLY))))gfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub(5)Y(Sv))HLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0'](()))))()(vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsException);
      });

      test("Descriptor의 마지막 중괄호 이후에 문자가 있는 경우", () {
        const descriptor =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*";
        // 정상 케이스(체크섬이 있는 경우)
        expect(DescriptorUtil.normalizeDescriptor("wpkh($descriptor)#k8xga4tv"), isNotEmpty);

        // 비정상 케이스
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)test"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)test2"), throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)Coconut"), throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)Wallet"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)POW"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)코코넛"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)논스랩"), throwsException);
      });

      test("wpkh(와 [ 사이에 문자가 있는 경우", () {
        const descriptor =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*";
        // 정상 케이스
        expect(DescriptorUtil.normalizeDescriptor("wpkh($descriptor)#k8xga4tv"), isNotEmpty);

        // 비정상 케이스
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(test$descriptor)"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(test2$descriptor)"), throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("wpkh(Coconut$descriptor)"), throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("wpkh(Wallet$descriptor)"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(POW$descriptor)"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(코코넛$descriptor)"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(논스랩$descriptor)"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("논스랩$descriptor"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("포우$descriptor"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("1111$descriptor"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("2222$descriptor"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("Coconut$descriptor"), throwsException);
      });

      test("대괄호 개수가 다르거나 2개 이상인 경우", () {
        const descriptor =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*";
        // 정상 케이스
        expect(DescriptorUtil.normalizeDescriptor("wpkh($descriptor)#k8xga4tv"), isNotEmpty);

        // 비정상 케이스
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor[][])"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor[[]])"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor]]]])"), throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("wpkh($descriptor[][][]])"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh([][]$descriptor)"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh([[[[[$descriptor)"), throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("wpkh([][][]$descriptor)"), throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("wpkh([[[[$descriptor]]]])"), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh([[[[$descriptor[][][)"),
            throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh([]]]]$descriptor[[[[)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0'][]]]]]]][][][][]vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/30'/1'/0']vpub5YSvHLYgfa[][][][]Dn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i2[[[[[[3UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2]]]]]i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5Y[][[]][]SvHLYg[]][faDn1H][FBxmn[k2i23UF]pNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgf][][[][aDn1HFB[][][]][][][xmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54[][][][]][vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxm]]]]]]]]nk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8[[[[[[[[TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsException);
      });

      test("NetworkType에 따른 주소가 맞는지 검증(Descriptor)", () {
        // 테스트넷
        var descriptor1 =
            "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"; // 테스트넷
        var descriptor2 =
            "wpkh([98C7D774/84'/1'/0']vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7/<0;1>/*)";
        var descriptor3 =
            "wpkh([98c7d774/84'/1'/0']tpubDDbAxgGSifNq7nDVLi3LfzeqF1GXhx4BM3HwxcdJVqhPLxSjMida9WyJZeV95teMpW4tMA4KFYtcSc7srHjz7uFkx4RQ4T15baqyqBdYTgm/<0;1>/*)";

        NetworkType.setNetworkType(NetworkType.regtest);
        expect(DescriptorUtil.normalizeDescriptor(descriptor1), isNotEmpty);
        expect(DescriptorUtil.normalizeDescriptor(descriptor2), isNotEmpty);
        expect(DescriptorUtil.normalizeDescriptor(descriptor3), isNotEmpty);

        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(() => DescriptorUtil.normalizeDescriptor(descriptor1), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor(descriptor2), throwsException);
        expect(() => DescriptorUtil.normalizeDescriptor(descriptor3), throwsException);
      });
    });

    group('SingleSignatureWallet.fromExtendedPublicKey', () {
      test("NetworkType에 따른 주소가 맞는지 검증", () {
        // 테스트넷 t, v
        var vpub =
            "vpub5Zqvq9Zcs7aixHKwhyuyctgNQDw12wLv61fSWZz9QwodYLUH5hnSAC53jynrkXdzQKijGMut3KuFB1oGndWp6rDNb56mMqdNyYuKTzM3UyR";
        var tpub =
            "tpubDDt5xij8skd8vfu2ptUKEzCk5HKYuZpyTsJBRuq4WsKHPpmSfExeYm4A2RnpGqu51WVFNtcsVkSPdmX1ctC5am2sPMEvDBvb6xd216itFG6";
        // 메인넷 x, z
        var xpub =
            "xpub6DWTSUuTAUfgesiBNhVE34sNkADtvBKuvEht5MmvAxZPeY6jb27ZQKPKnPi2kLwqDbxLmK6zxecLwb2QE2LqhKaaKkVcXfGMX12cF84D74X";
        var zpub =
            "zpub6sAz3pFHTqkeMU6R3R4UTF4P66WnoRJukTkKe9ZgvyK9kjjC6LSgeShbpodCkAFg2tBxGGJ7syKSiAFXfRAsHnwn4RtThUuL4T9u2EtUh3v";

        NetworkType.setNetworkType(NetworkType.regtest);
        expect(
            SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, vpub, '-').descriptor,
            isNotEmpty);
        expect(
            SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, tpub, '-').descriptor,
            isNotEmpty);
        expect(
            () => SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, xpub, '-')
                .descriptor,
            throwsException);
        expect(
            () => SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, zpub, '-')
                .descriptor,
            throwsException);

        NetworkType.setNetworkType(NetworkType.mainnet);
        expect(
            SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, xpub, '-').descriptor,
            isNotEmpty);
        expect(
            SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, zpub, '-').descriptor,
            isNotEmpty);
        expect(
            () => SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, vpub, '-')
                .descriptor,
            throwsException);
        expect(
            () => SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, tpub, '-')
                .descriptor,
            throwsException);
      });

      test("공개키 테스트 케이스", () {
        // Test vector xpub 케이스 추가
        // https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
        var validXpubList = [
          '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',
        ];

        for (int i = 0; i < validXpubList.length; ++i) {
          expect(
              SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, validXpubList[i], '-')
                  .descriptor,
              isNotEmpty);
        }

        var invalidXpubList = [
          'xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6LBpB85b3D2yc8sfvZU521AAwdZafEz7mnzBBsz4wKY5fTtTQBm',
          'xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6Txnt3siSujt9RCVYsx4qHZGc62TG4McvMGcAUjeuwZdduYEvFn',
          'xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6N8ZMMXctdiCjxTNq964yKkwrkBJJwpzZS4HS2fxvyYUA4q2Xe4',
          'xpub661no6RGEX3uJkY4bNnPcw4URcQTrSibUZ4NqJEw5eBkv7ovTwgiT91XX27VbEXGENhYRCf7hyEbWrR3FewATdCEebj6znwMfQkhRYHRLpJ ',
          'xpub661MyMwAuDcm6CRQ5N4qiHKrJ39Xe1R1NyfouMKTTWcguwVcfrZJaNvhpebzGerh7gucBvzEQWRugZDuDXjNDRmXzSZe4c7mnTK97pTvGS8',
          'DMwo58pR1QLEFihHiXPVykYB6fJmsTeHvyTp7hRThAtCX8CvYzgPcn8XnmdfHGMQzT7ayAmfo4z3gY5KfbrZWZ6St24UVf2Qgo6oujFktLHdHY4',
          'DMwo58pR1QLEFihHiXPVykYB6fJmsTeHvyTp7hRThAtCX8CvYzgPcn8XnmdfHPmHJiEDXkTiJTVV9rHEBUem2mwVbbNfvT2MTcAqj3nesx8uBf9 ',
          'xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6Q5JXayek4PRsn35jii4veMimro1xefsM58PgBMrvdYre8QyULY',
        ];

        int invalidXpubCount = 0;
        for (int i = 0; i < invalidXpubList.length; ++i) {
          try {
            SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, invalidXpubList[i], '-')
                .descriptor;
          } catch (e) {
            expect((e is Error) || (e is Exception), true);
            ++invalidXpubCount;
          }
          expect(invalidXpubCount, i + 1);
        }
      });
    });
  });
}
