import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_address_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([SendInfoProvider, WalletProvider])
// flutter pub run build_runner build
// 또는
// flutter pub run build_runner build --delete-conflicting-outputs
// 수행 후 테스트 코드 실행
import 'send_address_view_model_test.mocks.dart';

void main() {
  late SendAddressViewModel viewModel;
  late MockSendInfoProvider mockSendInfoProvider;
  late MockWalletProvider mockWalletProvider;

  setUp(() {
    mockSendInfoProvider = MockSendInfoProvider();
    mockWalletProvider = MockWalletProvider();
    viewModel = SendAddressViewModel(mockSendInfoProvider, true, mockWalletProvider);
  });

  group('validateAddress', () {
    test('빈 주소는 에러를 발생시켜야 함', () async {
      expect(
        () => viewModel.validateAddress(''),
        throwsA(viewModel.invalidAddressMessage),
      );
    });

    test('잘못된 길이의 bech32 주소는 에러를 발생시켜야 함', () async {
      expect(
        () => viewModel.validateAddress('bc1q'),
        throwsA(viewModel.invalidAddressMessage),
      );
    });

    test('잘못된 길이의 legacy 주소는 에러를 발생시켜야 함 - 26자 미만', () async {
      expect(
        () => viewModel.validateAddress('1A1zP1eP5Q'),
        throwsA(viewModel.invalidAddressMessage),
      );
    });

    test('잘못된 길이의 legacy 주소는 에러를 발생시켜야 함 - 62자 초과', () async {
      expect(
        () => viewModel.validateAddress(
            '1ThisAddressIsWayTooLongToBeValidOnBitcoinNetworkIfT2RAddressIsInsertedItWillBeOver62Characters'),
        throwsA(viewModel.invalidAddressMessage),
      );
    });

    group('testnet 네트워크', () {
      setUp(() {
        NetworkType.setNetworkType(NetworkType.testnet);
      });

      test('mainnet 주소는 에러를 발생시켜야 함', () async {
        expect(
          () => viewModel.validateAddress('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'),
          throwsA(viewModel.notTestnetAddressMessage),
        );
        expect(
          () => viewModel.validateAddress('3EktnHQD7RiAE6uzMj2ZifT9YgRrkSgzQX'),
          throwsA(viewModel.notTestnetAddressMessage),
        );
        expect(
          () => viewModel.validateAddress('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'),
          throwsA(viewModel.notTestnetAddressMessage),
        );
      });
      test('유효한 testnet 주소는 검증을 통과해야 함 - m 주소', () async {
        expect(
          () => viewModel.validateAddress('mr3MGrB8CpqEkJAT8XaenEcQxXvG6FEGKa'),
          returnsNormally,
        );
      });

      test('유효한 testnet 주소는 검증을 통과해야 함 - n 주소', () async {
        expect(
          () => viewModel.validateAddress('n4Jp6MDWWyz3naY7ydyFua76fNvH3KYCMu'),
          returnsNormally,
        );
      });

      test('유효한 testnet 주소는 검증을 통과해야 함 - 2 주소', () async {
        expect(
          () => viewModel.validateAddress('2N2i65CqwXpacR5HRDCnKyoK7VS1jf2Kj37'),
          returnsNormally,
        );
      });

      test('유효한 testnet 주소는 검증을 통과해야 함 - tb1 ', () async {
        expect(
          () => viewModel.validateAddress('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'),
          returnsNormally,
        );
      });

      test('유효한 testnet 주소는 검증을 통과해야 함 - TB1', () async {
        expect(
          () => viewModel.validateAddress('TB1Q3SQEUFQWJ853G2TLPFN8QZ3YTUKE3K9T2YT67T'),
          returnsNormally,
        );
      });
    });

    group('mainnet 네트워크', () {
      setUp(() {
        NetworkType.setNetworkType(NetworkType.mainnet);
      });

      test('testnet 주소는 에러를 발생시켜야 함', () async {
        expect(
          () => viewModel.validateAddress('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'),
          throwsA(viewModel.notMainnetAddressMessage),
        );
        expect(
          () => viewModel.validateAddress('mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn'),
          throwsA(viewModel.notMainnetAddressMessage),
        );
        expect(
          () => viewModel.validateAddress('2MzQwSSnBHWHqSAqtTVQ6v47Xtais7Ja7Vb'),
          throwsA(viewModel.notMainnetAddressMessage),
        );
      });

      test('유효한 mainnet 주소는 검증을 통과해야 함 - 1 주소', () async {
        expect(
          () => viewModel.validateAddress('1MFwsZ6Z7x9qDmDZcJeRY44mkr2kBJydv4'),
          returnsNormally,
        );
      });

      test('유효한 mainnet 주소는 검증을 통과해야 함 - 3 주소', () async {
        expect(
          () => viewModel.validateAddress('3GBTzpjL56T3wiCjtF6tdzoyyJ3FkarPjg'),
          returnsNormally,
        );
      });

      test('유효한 mainnet 주소는 검증을 통과해야 함 - bc1', () async {
        expect(
          () => viewModel.validateAddress('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'),
          returnsNormally,
        );
      });

      test('유효한 mainnet 주소는 검증을 통과해야 함 - BC1', () async {
        expect(
          () => viewModel.validateAddress('BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4'),
          returnsNormally,
        );
      });
    });

    group('regtest 네트워크', () {
      setUp(() {
        NetworkType.setNetworkType(NetworkType.regtest);
      });

      test('regtest가 아닌 주소는 에러를 발생시켜야 함', () async {
        expect(
          () => viewModel.validateAddress('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4'),
          throwsA(viewModel.notRegtestnetAddressMessage),
        );
        expect(
          () => viewModel.validateAddress('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'),
          throwsA(viewModel.notRegtestnetAddressMessage),
        );
      });

      test('유효한 regtest 주소는 검증을 통과해야 함 - bcrt1 주소', () async {
        expect(
          () => viewModel.validateAddress('bcrt1qz9edcv2r9wh5rjfyj2nvvms6uxyqctnu70ecaq'),
          returnsNormally,
        );
      });

      test('유효한 regtest 주소는 검증을 통과해야 함 - BCRT1', () async {
        expect(
          () => viewModel.validateAddress('BCRT1QZ9EDCV2R9WH5RJFYJ2NVVMS6UXYQCTNU70ECAQ'),
          returnsNormally,
        );
      });
    });
  });
}
