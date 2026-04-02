import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/utxo_split/utxo_split_exception.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_builder.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utxo_split_test_helper.dart';
import '../../mock/wallet_mock.dart';
import '../../repository/realm/test_realm_manager.dart';

void main() {
  NetworkType.setNetworkType(NetworkType.regtest);

  late TestRealmManager realmManager;
  late AddressRepository addressRepository;
  final MultisigWalletListItem wallet = WalletMock.createMultiSigWalletItem();
  const int walletId = 1;

  UtxoState createUtxo(int amount) => UtxoState(
    transactionHash: 'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
    index: 0,
    amount: amount,
    blockHeight: 100,
    to: 'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66',
    derivationPath: "m/48'/1'/0'/2'/0/0",
    timestamp: DateTime.now(),
  );

  UtxoSplitBuilder createBuilder(UtxoState utxo, {double feeRate = 1.0}) =>
      UtxoSplitBuilder(utxo: utxo, feeRate: feeRate, walletListItemBase: wallet, addressRepository: addressRepository);

  void printSplitOutputs(UtxoSplitResult result, String label) {
    print('--- $label ---');
    for (final entry in result.splitAmountMap.entries) {
      print('${entry.key} x ${entry.value}');
    }
  }

  setUpAll(() async {
    realmManager = await setupTestRealmManager();
    final realmWalletBase = RealmWalletBase(
      wallet.id,
      wallet.colorIndex,
      wallet.iconIndex,
      wallet.descriptor,
      wallet.name,
      WalletType.multiSignature.name,
    );
    addressRepository = AddressRepository(realmManager);

    realmManager.realm.write(() {
      realmManager.realm.add(realmWalletBase);
    });

    // generatedReceiveIndex, generatedChangeIndex 업데이트
    realmManager.realm.write(() {
      final savedWallet = realmManager.realm.find<RealmWalletBase>(wallet.id)!;
      savedWallet.generatedReceiveIndex = 399;
      savedWallet.generatedChangeIndex = 19;
    });

    // receive 주소 400개, change 주소 20개 생성
    final List<WalletAddress> addresses = [];
    for (int i = 0; i < 400; i++) {
      final address = wallet.walletBase.getAddress(i, isChange: false);
      final derivationPath = "${wallet.walletBase.derivationPath}/0/$i";
      addresses.add(WalletAddress(address, derivationPath, i, false, false, 0, 0, 0));
    }
    for (int i = 0; i < 20; i++) {
      final address = wallet.walletBase.getAddress(i, isChange: true);
      final derivationPath = "${wallet.walletBase.derivationPath}/1/$i";
      addresses.add(WalletAddress(address, derivationPath, i, true, false, 0, 0, 0));
    }

    realmManager.realm.write(() {
      realmManager.realm.addAll<RealmWalletAddress>([
        ...addresses.map(
          (addr) => RealmWalletAddress(
            getWalletAddressId(walletId, addr.index, addr.address),
            walletId,
            addr.address,
            addr.index,
            addr.isChange,
            addr.derivationPath,
            false,
            0,
            0,
            0,
          ),
        ),
      ]);
    });
  });

  tearDownAll(() {
    realmManager.dispose();
  });

  group('균등 나누기 (Equal Split)', () {
    test('기본 균등 분할 - 나머지가 있는 경우', () async {
      // P2WSH (2-of-3 multisig): vSize가 P2WPKH보다 큼
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo);

      final result = await builder.buildEqualSplit(splitCount: 5);

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);

      final totalCount = result.splitAmountMap.values.fold<int>(0, (sum, c) => sum + c);
      expect(totalCount, 5);

      final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
      expect(totalAmount + result.estimatedFee, utxo.amount);

      expect(result.feeRatio, isA<double>());
      expect(result.feeRatio.toString().split('.').last.length, lessThanOrEqualTo(2));
      printSplitOutputs(result, '기본 균등 분할');
    });

    test('나머지 없이 딱 떨어지는 경우', () async {
      final utxo = createUtxo(100270);
      final builder = createBuilder(utxo);

      final result = await builder.buildEqualSplit(splitCount: 5);

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);

      final totalCount = result.splitAmountMap.values.fold<int>(0, (sum, c) => sum + c);
      expect(totalCount, 5);
      printSplitOutputs(result, '균등분할: 나머지 없이 딱 떨어지는 경우');
    });

    test('dust 발생 시 SplitOutputDustException', () async {
      final utxo = createUtxo(50000);
      final builder = createBuilder(utxo);

      expect(() => builder.buildEqualSplit(splitCount: 200), throwsA(isA<SplitOutputDustException>()));
    });

    test('fee가 UTXO amount 대비 너무 크면 SplitInsufficientAmountException', () async {
      final utxo = createUtxo(50000);
      final builder = createBuilder(utxo, feeRate: 1000.0);

      expect(() => builder.buildEqualSplit(splitCount: 2), throwsA(isA<SplitInsufficientAmountException>()));
    });
  });

  group('일정 금액으로 나누기 (Fixed Amount Split)', () {
    test('기본 성공 케이스 - 1BTC UTXO, 1000000 sats per output', () async {
      final utxo = createUtxo(100000000);
      final builder = createBuilder(utxo);

      final result = await builder.buildFixedAmountSplit(amountPerOutput: 1000000);

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      expect(result.splitAmountMap.containsKey(1000000), isTrue);

      final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
      expect(totalAmount + result.estimatedFee, utxo.amount);
      printSplitOutputs(result, '1BTC UTXO, 1000000 sats per output');
    });

    test('dust 금액 → SplitOutputDustException', () async {
      // amountPerOutput(100) <= dustLimit(546)
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo);

      expect(() => builder.buildFixedAmountSplit(amountPerOutput: 100), throwsA(isA<SplitOutputDustException>()));
    });

    test('기본 성공 케이스 - 100000 sats UTXO, 5000 sats per output', () async {
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo);

      final result = await builder.buildFixedAmountSplit(amountPerOutput: 5000);

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      expect(result.splitAmountMap.containsKey(5000), isTrue);

      final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
      expect(totalAmount + result.estimatedFee, utxo.amount);
      printSplitOutputs(result, '100000 sats UTXO, 5000 sats per output');
    });

    test('1BTC UTXO를 300000 sats씩 나누기 - outputCount varInt threshold 초과', () async {
      final utxo = createUtxo(100000000);
      final builder = createBuilder(utxo);

      final result = await builder.buildFixedAmountSplit(amountPerOutput: 300000);

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      expect(result.splitAmountMap.containsKey(300000), isTrue);

      final totalCount = result.splitAmountMap.values.fold<int>(0, (sum, c) => sum + c);
      expect(totalCount, greaterThanOrEqualTo(253));

      final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
      expect(totalAmount + result.estimatedFee, utxo.amount);
      printSplitOutputs(result, '1BTC UTXO, 300000 sats per output');
    });

    test('1BTC UTXO를 300000 sats씩 나누기 - feeRate 12.5, outputCount varInt threshold 초과', () async {
      final utxo = createUtxo(100000000);
      final builder = createBuilder(utxo, feeRate: 12.5);

      final result = await builder.buildFixedAmountSplit(amountPerOutput: 300000);

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      expect(result.splitAmountMap.containsKey(300000), isTrue);

      final totalCount = result.splitAmountMap.values.fold<int>(0, (sum, c) => sum + c);
      expect(totalCount, greaterThanOrEqualTo(253));

      final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
      expect(totalAmount + result.estimatedFee, utxo.amount);
      printSplitOutputs(result, '1BTC UTXO, 300000 sats per output, feeRate 12.5');
    });

    test('amountPerOutput이 너무 커서 fee 포함 불가 → SplitInsufficientAmountException', () async {
      // multisig fee가 singlesig보다 크므로 firstLeft는 더욱 음수
      // firstLeft = 100000 - margin - (oneOutputTxVBytes × 1.0) - 99990 ≤ dustLimit + feePerOutput
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo);

      expect(
        () => builder.buildFixedAmountSplit(amountPerOutput: 99990),
        throwsA(isA<SplitInsufficientAmountException>()),
      );
    });

    test('feeRate가 너무 높아서 fee 포함 불가 → SplitInsufficientAmountException', () async {
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo, feeRate: 100000);

      expect(
        () => builder.buildFixedAmountSplit(amountPerOutput: 5000),
        throwsA(isA<SplitInsufficientAmountException>()),
      );
    });
  });

  group('직접 나누기 (Custom Split)', () {
    test('1BTC를 0.1 x 5, 0.05 x 9로 나누기', () async {
      final utxo = createUtxo(100000000); // 1 BTC
      final builder = createBuilder(utxo, feeRate: 1.0);

      final result = await builder.buildCustomSplit(amountCountMap: {10000000: 5, 5000000: 9});

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      expect(result.splitAmountMap[10000000], 5);
      expect(result.splitAmountMap[5000000], 9);
      expect(result.splitAmountMap.keys.length, 3);

      final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
      expect(totalAmount + result.estimatedFee, utxo.amount);
      printSplitOutputs(result, 'CustomSplit: 1BTC UTXO, 0.1 x 5, 0.05 x 9 and extra');
    });

    test('1BTC를 300000 sats 332개로 나누기', () async {
      final utxo = createUtxo(100000000); // 1 BTC
      final builder = createBuilder(utxo, feeRate: 1.0);

      final result = await builder.buildCustomSplit(amountCountMap: {300000: 332});

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      expect(result.splitAmountMap[300000], 332);

      final totalCount = result.splitAmountMap.values.fold<int>(0, (sum, count) => sum + count);
      expect(totalCount, 333);

      final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
      expect(totalAmount + result.estimatedFee, utxo.amount);
      printSplitOutputs(result, 'CustomSplit: 1BTC UTXO, 300000 sats x 332 and extra');
    });

    test('1BTC를 300000 sats 332개로 나누기, feeRate 12.5', () async {
      final utxo = createUtxo(100000000); // 1 BTC
      final builder = createBuilder(utxo, feeRate: 12.5);

      final result = await builder.buildCustomSplit(amountCountMap: {300000: 332});

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      expect(result.splitAmountMap[300000], 332);

      final totalCount = result.splitAmountMap.values.fold<int>(0, (sum, count) => sum + count);
      expect(totalCount, 333);

      final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
      expect(totalAmount + result.estimatedFee, utxo.amount);
      printSplitOutputs(result, 'CustomSplit: 1BTC UTXO, 300000 sats x 332, feeRate 12.5 and extra');
    });

    test('1BTC를 0.1 x 5, 0.05 x 10로 나누려 하면 SplitInsufficientAmountException', () async {
      final utxo = createUtxo(100000000); // 1 BTC
      final builder = createBuilder(utxo, feeRate: 1.0);

      expect(
        () => builder.buildCustomSplit(amountCountMap: {10000000: 5, 5000000: 10}),
        throwsA(isA<SplitInsufficientAmountException>()),
      );
    });

    test('1BTC를 0.5 x 1, 0.49999828 x 1로 나누려 하면 SplitOutputDustException', () async {
      final utxo = createUtxo(100000000); // 1 BTC
      final builder = createBuilder(utxo, feeRate: 1.0);
      // 50000000 - 219 = 49999781
      expect(
        () => builder.buildCustomSplit(amountCountMap: {50000000: 1, 49999781: 1}),
        throwsA(isA<SplitOutputDustException>()),
      );
    });

    test('feeRate 10000000에서 0.1BTC를 0.05 x 20으로 나누려 하면 SplitInsufficientAmountException이고 estimatedFee가 있다', () async {
      final utxo = createUtxo(10000000); // 0.1 BTC
      final builder = createBuilder(utxo, feeRate: 10000000);

      try {
        await builder.buildCustomSplit(amountCountMap: {5000000: 20});
        fail('SplitInsufficientAmountException should be thrown');
      } on SplitInsufficientAmountException catch (e) {
        expect(e.estimatedFee, isNotNull);
      }
    });
  });

  group('수수료 계산', () {
    test('estimatedFee 검증', () async {
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo);

      final result = await builder.buildEqualSplit(splitCount: 3);

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      expect(result.estimatedFee, greaterThan(0));
      expect(result.estimatedFee, lessThan(utxo.amount));
    });

    test('multisig fee가 singlesig보다 큼', () async {
      // P2WSH multisig는 P2WPKH singlesig보다 input witness가 크므로 fee가 더 높아야 함
      final utxo = createUtxo(1000000);
      final builder = createBuilder(utxo);

      final result = await builder.buildEqualSplit(splitCount: 3);

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      // 2-of-3 P2WSH: 1 input, 3 outputs → singlesig 대비 fee가 높음
      // singlesig 동일 조건에서 약 170 sats, multisig는 그보다 높아야 함
      expect(result.estimatedFee, greaterThan(170));
    });

    test('feeRatio 소숫점 2자리 검증', () async {
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo, feeRate: 3.5);

      final result = await builder.buildEqualSplit(splitCount: 3);

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      final ratioStr = result.feeRatio.toString();
      if (ratioStr.contains('.')) {
        expect(ratioStr.split('.').last.length, lessThanOrEqualTo(2));
      }
    });

    test('높은 fee rate에서도 정상 동작', () async {
      final utxo = createUtxo(1000000);
      final builder = createBuilder(utxo, feeRate: 100.0);

      final result = await builder.buildEqualSplit(splitCount: 2);

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      expect(result.estimatedFee, greaterThan(0));
    });
  });

  group('getMaxEqualSplitCount로 buildEqualSplit 성공 검증', () {
    final testCases = [
      // (amount, feeRate, description)
      (50000, 1.0, '최소 허용 금액 (50000)'),
      (100000, 1.0, '10만 sats'),
      (1000000, 1.0, '100만 sats'),
      (10000000, 1.0, '0.1 BTC'),
      (100000, 5.0, '높은 feeRate'),
      (100000, 50.0, '매우 높은 feeRate'),
      (10000000, 100.0, '높은 금액 + 높은 feeRate'),
      // (100000000, 1.0, '1 BTC'), // output 약 173010개: 너무 많아서 10분으로도 부족함
    ];

    for (final (amount, feeRate, description) in testCases) {
      test('$description (amount: $amount, feeRate: $feeRate)', () async {
        final utxo = createUtxo(amount);
        final builder = createBuilder(utxo, feeRate: feeRate);
        final maxCount = await builder.getMaxEqualSplitCount();

        print('[$description] amount: $amount, feeRate: $feeRate, maxCount: $maxCount');

        if (maxCount < 2) {
          print('[$description] maxCount < 2 → split 불가, 예외 발생 확인');
          expect(
            () => builder.buildEqualSplit(splitCount: 2),
            throwsA(anyOf(isA<SplitOutputDustException>(), isA<SplitInsufficientAmountException>())),
          );
          return;
        }

        final result = await builder.buildEqualSplit(splitCount: maxCount);

        print('[$description] buildEqualSplit 결과: isSuccess=${result.isSuccess}, estimatedFee=${result.estimatedFee}');
        print('[$description] splitAmountMap: ${result.splitAmountMap}');
        print('[$description] outputs: ${result.transaction!.outputs.map((o) => o.amount).toList()}');

        expect(result.isSuccess, isTrue, reason: 'getMaxEqualSplitCount=$maxCount, buildEqualSplit 실패');
        expectSuccessfulTransaction(result);

        final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
        print('[$description] totalAmount: $totalAmount, fee: ${result.estimatedFee}, utxo.amount: ${utxo.amount}');
        expect(totalAmount + result.estimatedFee, utxo.amount);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });
}
