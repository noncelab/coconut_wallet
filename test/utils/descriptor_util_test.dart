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
        expect(() => DescriptorUtil.extractPurpose(descriptor), throwsFormatException);
      });

      test('잘못된 형식의 디스크립터는 예외 발생', () {
        const descriptor = 'invalid-descriptor';
        expect(() => DescriptorUtil.extractPurpose(descriptor), throwsFormatException);
      });
    });

    group('validatePurpose', () {
      test('올바른 purpose는 예외를 발생시키지 않음', () {
        expect(() => DescriptorUtil.validatePurpose('84'), returnsNormally);
      });

      test('잘못된 purpose는 예외 발생', () {
        expect(() => DescriptorUtil.validatePurpose('44'), throwsFormatException);
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
      test('wpkh 함수가 있는 디스크립터는 그대로 반환', () {
        const descriptor =
            'wpkh([38d0b5e1/84\'/1\'/0\']vpub5TmYRnYy8ScbkG2WmearTx1DG91gJC4TM9kRTvSQjgVMGRUdx4vRUD8UHjZn8fJZfjUoBHPnVX1q5AmHJHTHw3CRtHzfK4yqMhAKS93Xb3y/<0;1>/*)#uqpyzfuf';
        expect(DescriptorUtil.normalizeDescriptor(descriptor), descriptor);
      });

      test('함수가 없는 디스크립터는 wpkh로 감싸짐', () {
        const descriptor =
            '[38d0b5e1/84\'/1\'/0\']vpub5TmYRnYy8ScbkG2WmearTx1DG91gJC4TM9kRTvSQjgVMGRUdx4vRUD8UHjZn8fJZfjUoBHPnVX1q5AmHJHTHw3CRtHzfK4yqMhAKS93Xb3y/<0;1>/*';
        expect(DescriptorUtil.normalizeDescriptor(descriptor), 'wpkh($descriptor)');
      });

      test('체크섬이 있는 디스크립터 처리', () {
        const descriptor =
            'wpkh([38d0b5e1/84\'/1\'/0\']vpub5TmYRnYy8ScbkG2WmearTx1DG91gJC4TM9kRTvSQjgVMGRUdx4vRUD8UHjZn8fJZfjUoBHPnVX1q5AmHJHTHw3CRtHzfK4yqMhAKS93Xb3y/<0;1>/*)#uqpyzfuf';
        expect(DescriptorUtil.normalizeDescriptor(descriptor), descriptor);

        // 잘못된 체크섬 로직 검증(영문, 숫자 8개)
        const descriptor2 =
            "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)";
        expect(
            () => DescriptorUtil.normalizeDescriptor("$descriptor2#test"), throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("$descriptor2#test2"), throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("$descriptor2#test3"), throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("$descriptor2#AAAA"), throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor2#AAAAAAAAA"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor2#논스랩"), throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor2#코코넛"), throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("$descriptor2#월렛"), throwsFormatException);
      });

      test('체크섬이 없는 디스크립터 처리', () {
        const descriptor =
            'wpkh([38d0b5e1/84\'/1\'/0\']vpub5TmYRnYy8ScbkG2WmearTx1DG91gJC4TM9kRTvSQjgVMGRUdx4vRUD8UHjZn8fJZfjUoBHPnVX1q5AmHJHTHw3CRtHzfK4yqMhAKS93Xb3y/<0;1>/*)';
        const descriptor2 =
            "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)";
        const descriptor3 =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*";

        expect(DescriptorUtil.normalizeDescriptor(descriptor), descriptor);
        expect(DescriptorUtil.normalizeDescriptor(descriptor2), isNotEmpty);
        expect(DescriptorUtil.normalizeDescriptor(descriptor3), isNotEmpty);
      });

      test('잘못된 purpose를 가진 디스크립터는 예외 발생', () {
        const descriptor =
            'wpkh([76223a6f/44\'/0\'/0\']tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)#n9g32cn0';
        expect(() => DescriptorUtil.normalizeDescriptor(descriptor), throwsFormatException);
      });

      test('지원하지 않는 함수는 예외 발생', () {
        const descriptor =
            'sh([76223a6f/84\'/0\'/0\']tpubDE7NQymr4AFtewpAsWtnreyq9ghkzQBXpCZjWLFVRAvnbf7vya2eMTvT2fPapNqL8SuVvLQdbUbMfWLVDCZKnsEBqp6UK93QEzL8Ck23AwF/0/*)#n9g32cn0';
        expect(() => DescriptorUtil.normalizeDescriptor(descriptor), throwsFormatException);
      });

      test('잘못된 형식의 디스크립터는 예외 발생', () {
        const descriptor = 'invalid-descriptor';
        expect(() => DescriptorUtil.normalizeDescriptor(descriptor), throwsFormatException);

        const descriptor2 =
            "([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)";
        expect(() => DescriptorUtil.normalizeDescriptor("test$descriptor2"), throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("1234$descriptor2"), throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("hello$descriptor2"), throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("Nonce$descriptor2"), throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("labCoconut$descriptor2"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("코코넛월렛$descriptor2"), throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("POW$descriptor2"), throwsFormatException);
      });

      test('ExtendedPublicKey만으로 descriptor 생성', () {
        const descriptor =
            'wpkh([00000000/84\'/1\'/0\']vpub5TmYRnYy8ScbkG2WmearTx1DG91gJC4TM9kRTvSQjgVMGRUdx4vRUD8UHjZn8fJZfjUoBHPnVX1q5AmHJHTHw3CRtHzfK4yqMhAKS93Xb3y/<0;1>/*)';
        expect(DescriptorUtil.normalizeDescriptor(descriptor), descriptor);
      });

      test("내부적으로 수정된 Descriptor의 중괄호 개수가 각각 1개여야 한다.", () {
        const descriptor =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg";
        // 정상 케이스
        expect(DescriptorUtil.normalizeDescriptor("wpkh($descriptor)"), isNotEmpty);
        expect(DescriptorUtil.normalizeDescriptor(descriptor), isNotEmpty);

        // 비정상 케이스
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor((()"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor()())"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor((()))"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(()()($descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh())))((($descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh()(($descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(()()()$descriptor((()"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(((()))$descriptor((()"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh())))$descriptor((()"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub()()()5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATG()()()asJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub((((5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLY)))))gfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub((((5YSvHLY))))gfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub(5)Y(Sv))HLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0'](()))))()(vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg)"),
            throwsFormatException);
      });

      test("Descriptor의 마지막 중괄호 이후에 문자가 있는 경우", () {
        const descriptor =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*";
        // 정상 케이스(체크섬이 있는 경우)
        expect(DescriptorUtil.normalizeDescriptor("wpkh($descriptor)#k8xga4tv"), isNotEmpty);

        // 비정상 케이스
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)test"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)test2"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)Coconut"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)Wallet"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)POW"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)코코넛"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor)논스랩"),
            throwsFormatException);
      });

      test("wpkh(와 [ 사이에 문자가 있는 경우", () {
        const descriptor =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*";
        // 정상 케이스
        expect(DescriptorUtil.normalizeDescriptor("wpkh($descriptor)#k8xga4tv"), isNotEmpty);

        // 비정상 케이스
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(test$descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(test2$descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(Coconut$descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(Wallet$descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(POW$descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(코코넛$descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh(논스랩$descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("논스랩$descriptor"), throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("포우$descriptor"), throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("1111$descriptor"), throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("2222$descriptor"), throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor("Coconut$descriptor"), throwsFormatException);
      });

      test("대괄호 개수가 다르거나 2개 이상인 경우", () {
        const descriptor =
            "[F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*";
        // 정상 케이스
        expect(DescriptorUtil.normalizeDescriptor("wpkh($descriptor)#k8xga4tv"), isNotEmpty);

        // 비정상 케이스
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor[][])"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor[[]])"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor]]]])"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh($descriptor[][][]])"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh([][]$descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh([[[[[$descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh([][][]$descriptor)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh([[[[$descriptor]]]])"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh([[[[$descriptor[][][)"),
            throwsFormatException);
        expect(() => DescriptorUtil.normalizeDescriptor("wpkh([]]]]$descriptor[[[[)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0'][]]]]]]][][][][]vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfa[][][][]Dn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i2[[[[[[3UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2]]]]]i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5Y[][[]][]SvHLYg[]][faDn1H][FBxmn[k2i23UF]pNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgf][][[][aDn1HFB[][][]][][][xmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxmnk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8TPJfxysxdQxRZ8CQqtu54[][][][]][vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsFormatException);
        expect(
            () => DescriptorUtil.normalizeDescriptor(
                "wpkh([F75F5AB5/84'/1'/0']vpub5YSvHLYgfaDn1HFBxm]]]]]]]]nk2i23UFpNBLNJNFGfkdbEtwijtwHHMv5UhH6QATGasJWmRp8[[[[[[[[TPJfxysxdQxRZ8CQqtu54vXBRz696bSraBPThxNg/<0;1>/*)"),
            throwsFormatException);
      });
    });
  });
}
