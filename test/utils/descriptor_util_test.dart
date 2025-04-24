import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:flutter_test/flutter_test.dart';

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
            '[38d0b5e1/84\'/1\'/0\']vpub5TmYRnYy8ScbkG2WmearTx1DG91gJC4TM9kRTvSQjgVMGRUdx4vRUD8UHjZn8fJZfjUoBHPnVX1q5AmHJHTHw3CRtHzfK4yqMhAKS93Xb3y/<0;1>/*)#uqpyzfuf';
        expect(DescriptorUtil.normalizeDescriptor(descriptor), 'wpkh($descriptor)');
      });

      test('체크섬이 있는 디스크립터 처리', () {
        const descriptor =
            'wpkh([38d0b5e1/84\'/1\'/0\']vpub5TmYRnYy8ScbkG2WmearTx1DG91gJC4TM9kRTvSQjgVMGRUdx4vRUD8UHjZn8fJZfjUoBHPnVX1q5AmHJHTHw3CRtHzfK4yqMhAKS93Xb3y/<0;1>/*)#uqpyzfuf';
        expect(DescriptorUtil.normalizeDescriptor(descriptor), descriptor);
      });

      test('체크섬이 없는 디스크립터 처리', () {
        const descriptor =
            'wpkh([38d0b5e1/84\'/1\'/0\']vpub5TmYRnYy8ScbkG2WmearTx1DG91gJC4TM9kRTvSQjgVMGRUdx4vRUD8UHjZn8fJZfjUoBHPnVX1q5AmHJHTHw3CRtHzfK4yqMhAKS93Xb3y/<0;1>/*)';
        expect(DescriptorUtil.normalizeDescriptor(descriptor), descriptor);
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
      });
    });
  });
}
