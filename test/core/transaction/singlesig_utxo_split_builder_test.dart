import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/core/exceptions/utxo_split/utxo_split_exception.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_transaction_builder.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
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
  final SinglesigWalletListItem wallet = WalletMock.createSingleSigWalletItem();
  const int walletId = 1;

  UtxoState createUtxo(int amount) => UtxoState(
    transactionHash: 'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
    index: 0,
    amount: amount,
    blockHeight: 100,
    to: 'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66',
    derivationPath: "m/84'/1'/0'/0/0",
    timestamp: DateTime.now(),
  );

  UtxoSplitTransactionBuilder createBuilder([UtxoState? utxo, double feeRate = 1.0]) => UtxoSplitTransactionBuilder(
    utxo: utxo,
    dustThreshold: DustThresholds.p2wpkh,
    feeRate: feeRate,
    walletListItemBase: wallet,
    addressRepository: addressRepository,
  );

  void printSplitOutputs(UtxoSplitResult result, String label) {
    print('--- $label ---');
    for (final entry in result.splitAmountMap.entries) {
      print('${entry.key} x ${entry.value}');
    }

    print('estimatedFee: ${result.estimatedFee}');
  }

  setUpAll(() async {
    realmManager = await setupTestRealmManager();
    final realmWalletBase = RealmWalletBase(
      wallet.id,
      wallet.colorIndex,
      wallet.iconIndex,
      wallet.descriptor,
      wallet.name,
      WalletType.singleSignature.name,
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

  group('nullable utxo', () {
    test('utxo 없이 생성 후 utxo 필수 함수 호출 시 StateError', () async {
      final builder = createBuilder();

      expect(() => builder.getMaxEqualSplitCount(), throwsA(isA<StateError>()));
      expect(() => builder.buildEqualAmountSplit(splitCount: 200).future, throwsA(isA<StateError>()));
      expect(() => builder.getNiceSplitCounts(), throwsA(isA<StateError>()));
      expect(() => builder.getEqualAmountSplitPreview(splitCount: 2), throwsA(isA<StateError>()));
    });

    test('setUtxo(null) 이후 utxo 필수 함수 호출 시 StateError', () async {
      final builder = createBuilder(createUtxo(100000));

      builder.setUtxo(null);

      expect(() => builder.getFixedAmountSplitPreview(amountPerOutput: 10000), throwsA(isA<StateError>()));
    });

    test('setUtxo로 나중에 지정하면 정상 동작', () async {
      final builder = createBuilder();

      builder.setUtxo(createUtxo(100000));

      final result = await builder.buildEqualAmountSplit(splitCount: 2).future;

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
    });
  });

  group('균등 나누기 (Equal Split)', () {
    test('기본 균등 분할 - 나머지가 있는 경우', () async {
      // P2WPKH: 1 input, 5 outputs → vSize 약 203 → fee = 203 sats (feeRate 1.0)
      // 100000 - 203 = 99797 → 99797 / 5 = 19959 remainder 2
      // splitAmountMap: {19959: 3, 19960: 2} 203/ 5 = 40 r 3
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo);

      final result = await builder.buildEqualAmountSplit(splitCount: 5).future;

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);

      // splitAmountMap의 총 개수가 5인지 확인
      final totalCount = result.splitAmountMap.values.fold<int>(0, (sum, c) => sum + c);
      expect(totalCount, 5);

      // 금액 합 + fee = utxo amount 검증
      final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
      expect(totalAmount + result.estimatedFee, utxo.amount);

      // feeRatio 검증 (소숫점 2자리)
      expect(result.feeRatio, isA<double>());
      expect(result.feeRatio.toString().split('.').last.length, lessThanOrEqualTo(2));
      printSplitOutputs(result, '기본 균등 분할');
    });

    test('기본 균등 분할 - 수수료율이 소수점', () async {
      // P2WPKH: 1 input, 5 outputs → vSize 약 203 → fee = 203 sats (feeRate 1.0)
      // 50000000 - 203 = 49999797 → 49999797 / 5 = 9999959 remainder 2
      // splitAmountMap: {9999959: 3, 9999960: 2}
      final utxo = createUtxo(50000000);
      final builder = createBuilder(utxo, 0.15);

      final result = await builder.buildEqualAmountSplit(splitCount: 5).future;

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);

      // splitAmountMap의 총 개수가 5인지 확인
      final totalCount = result.splitAmountMap.values.fold<int>(0, (sum, c) => sum + c);
      expect(totalCount, 5);

      // 금액 합 + fee = utxo amount 검증
      final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
      expect(totalAmount + result.estimatedFee, utxo.amount);

      // feeRatio 검증 (소숫점 2자리)
      expect(result.feeRatio, isA<double>());
      expect(result.feeRatio.toString().split('.').last.length, lessThanOrEqualTo(2));
      printSplitOutputs(result, '기본 균등 분할');
    });

    test('나머지 없이 딱 떨어지는 경우', () async {
      // fee를 빼고 splitCount로 나누어 떨어지는 금액을 찾아야 함
      // 1 input, 2 outputs → vSize 약 135 → fee = 135 sats (feeRate 1.0)
      // 100000 - 135 = 99865 / 2 = 49932.5 → 이건 안 맞으니까
      // 100270 - 135 = 100135 / 5 = 20027 remainder 0
      final utxo = createUtxo(100270);
      final builder = createBuilder(utxo);

      final result = await builder.buildEqualAmountSplit(splitCount: 5).future;

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      // 딱 떨어지면 splitAmountMap에 1개 항목
      // (나머지가 0이면 {baseAmount: splitCount}가 되어 1개 key)
      // 나머지가 있으면 2개 key

      final totalCount = result.splitAmountMap.values.fold<int>(0, (sum, c) => sum + c);
      expect(totalCount, 5);
      printSplitOutputs(result, '균등분할: 나머지 없이 딱 떨어지는 경우');
    });

    test('dust 발생 시 SplitOutputDustException', () async {
      // 최소 허용 금액에서 많이 쪼개려 하면 dust 발생
      final utxo = createUtxo(50000);
      final builder = createBuilder(utxo);

      expect(() => builder.buildEqualAmountSplit(splitCount: 200).future, throwsA(isA<SplitOutputDustException>()));
    });

    test('fee가 UTXO amount 대비 너무 크면 SplitInsufficientAmountException', () async {
      final utxo = createUtxo(50000);
      final builder = createBuilder(utxo, 1000.0);

      expect(() => builder.buildEqualAmountSplit(splitCount: 2).future, throwsA(isA<FeeExceedsUtxoAmountException>()));
    });
  });

  group('일정 금액으로 나누기 (Fixed Amount Split)', () {
    test('기본 성공 케이스 - 1BTC UTXO, 1000000 sats per output', () async {
      final utxo = createUtxo(100000000);
      final builder = createBuilder(utxo);

      final result = await builder.buildFixedAmountSplit(amountPerOutput: 1000000).future;

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

      expect(
        () => builder.buildFixedAmountSplit(amountPerOutput: 100).future,
        throwsA(isA<SplitOutputDustException>()),
      );
    });

    test('기본 성공 케이스 - 100000 sats UTXO, 5000 sats per output', () async {
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo);

      final result = await builder.buildFixedAmountSplit(amountPerOutput: 5000).future;

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

      final result = await builder.buildFixedAmountSplit(amountPerOutput: 300000).future;

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
      final builder = createBuilder(utxo, 12.5);

      final result = await builder.buildFixedAmountSplit(amountPerOutput: 300000).future;

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
      // firstLeft = 100000 - 10 - 110 - 99990 = -110 ≤ dustLimit(546) + feePerOutput(31)
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo);

      expect(
        () => builder.buildFixedAmountSplit(amountPerOutput: 99990).future,
        throwsA(isA<SplitInsufficientAmountException>()),
      );
    });

    test('feeRate가 너무 높아서 fee 포함 불가 → SplitInsufficientAmountException', () async {
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo, 100000);

      expect(
        () => builder.buildFixedAmountSplit(amountPerOutput: 5000).future,
        throwsA(isA<FeeExceedsUtxoAmountException>()),
      );
    });
  });

  group('Nice Split Counts', () {
    test('성공 가능한 nice amount 기준 count를 오름차순으로 최대 5개 반환한다', () async {
      final utxo = createUtxo(100000000);
      final builder = createBuilder(utxo);

      final counts = await builder.getNiceSplitCounts();

      expect(counts, [2, 5, 10, 20, 50]);
      expect(counts.length, lessThanOrEqualTo(5));
      expect(counts, orderedEquals([...counts]..sort()));
    });

    test('추천 count로 균등 분할하면 output amount가 대응 nice amount 근사값이 된다', () async {
      final utxo = createUtxo(100000000);
      final builder = createBuilder(utxo);

      final counts = await builder.getNiceSplitCounts();

      expect(counts, [2, 5, 10, 20, 50]);
      await expectEqualSplitAmountsNearNiceAmounts(builder, {
        2: 50000000,
        5: 20000000,
        10: 10000000,
        20: 5000000,
        50: 2000000,
      });
    });

    test('utxo.amount가 50000일 때 가능한 nice split count만 반환한다', () async {
      final utxo = createUtxo(50000);
      final builder = createBuilder(utxo);

      final counts = await builder.getNiceSplitCounts();

      expect(counts, [3, 5]);
      expect(counts, orderedEquals([...counts]..sort()));
    });

    test('utxo.amount가 50000일 때 추천 count로 균등 분할하면 output amount가 대응 nice amount 근사값이 된다', () async {
      final utxo = createUtxo(50000);
      final builder = createBuilder(utxo);

      final counts = await builder.getNiceSplitCounts();

      expect(counts, [3, 5]);
      await expectEqualSplitAmountsNearNiceAmounts(builder, {3: 20000, 5: 10000});
    });

    test('같은 feeRate에서는 캐시된 동일 인스턴스를 반환하고 feeRate 변경 후에는 새로 계산한다', () async {
      final utxo = createUtxo(100000000);
      final builder = createBuilder(utxo, 1.0);

      final first = await builder.getNiceSplitCounts();
      final cached = await builder.getNiceSplitCounts();
      expect(cached, same(first));

      builder.feeRate = 50.0;

      final afterFeeChange = await builder.getNiceSplitCounts();

      expect(afterFeeChange, [2, 5, 10, 20, 50]);
      expect(afterFeeChange, isNot(same(first)));
    });
  });

  group('직접 나누기 (Custom Split)', () {
    test('1BTC를 0.1 x 5, 0.05 x 9로 나누기', () async {
      final utxo = createUtxo(100000000); // 1 BTC
      final builder = createBuilder(utxo, 1.0);

      final result = await builder.buildCustomAmountSplit(amountCountMap: {10000000: 5, 5000000: 9}).future;

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
      final builder = createBuilder(utxo, 1.0);

      final result = await builder.buildCustomAmountSplit(amountCountMap: {300000: 332}).future;

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
      final builder = createBuilder(utxo, 12.5);

      final result = await builder.buildCustomAmountSplit(amountCountMap: {300000: 332}).future;

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
      final builder = createBuilder(utxo, 1.0);

      expect(
        () => builder.buildCustomAmountSplit(amountCountMap: {10000000: 5, 5000000: 10}).future,
        throwsA(isA<SplitInsufficientAmountException>()),
      );
    });

    test('1BTC를 0.5 x 1, 0.49999828 x 1로 나누려 하면 SplitOutputDustException', () async {
      final utxo = createUtxo(100000000); // 1 BTC
      final builder = createBuilder(utxo, 1.0);

      expect(
        () => builder.buildCustomAmountSplit(amountCountMap: {50000000: 1, 49999828: 1}).future,
        throwsA(isA<SplitOutputDustException>()),
      );
    });

    test('feeRate 10000000에서 0.1BTC를 0.05 x 20으로 나누려 하면 FeeExceedsUtxoAmountException이고 estimatedFee가 있다', () async {
      final utxo = createUtxo(10000000); // 0.1 BTC
      final builder = createBuilder(utxo, 10000000);

      try {
        await builder.buildCustomAmountSplit(amountCountMap: {5000000: 20}).future;
        fail('SplitInsufficientAmountException should be thrown');
      } on FeeExceedsUtxoAmountException catch (e) {
        expect(e.estimatedFee, isNotNull);
      }
    });
  });

  group('수수료 계산', () {
    test('estimatedFee 검증', () async {
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo);

      final result = await builder.buildEqualAmountSplit(splitCount: 3).future;

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      // 실제 fee는 TransactionBuilder가 계산하므로 양수이고 utxo amount 미만인지 검증
      expect(result.estimatedFee, greaterThan(0));
      expect(result.estimatedFee, lessThan(utxo.amount));
    });

    test('feeRatio 소숫점 2자리 검증', () async {
      final utxo = createUtxo(100000);
      final builder = createBuilder(utxo, 3.5);

      final result = await builder.buildEqualAmountSplit(splitCount: 3).future;

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      // feeRatio가 소숫점 2자리 이내인지 검증
      final ratioStr = result.feeRatio.toString();
      if (ratioStr.contains('.')) {
        expect(ratioStr.split('.').last.length, lessThanOrEqualTo(2));
      }
    });

    test('높은 fee rate에서도 정상 동작', () async {
      final utxo = createUtxo(1000000);
      final builder = createBuilder(utxo, 100.0);

      final result = await builder.buildEqualAmountSplit(splitCount: 2).future;

      expect(result.isSuccess, isTrue);
      expectSuccessfulTransaction(result);
      expect(result.estimatedFee, greaterThan(0));
    });
  });

  group('getMaxEqualSplitCount로 buildEqualSplit 성공 검증', () {
    final testCases = [
      //(amount, feeRate, description)
      (20000, 1.0, '최소 허용 금액 (20000)'),
      (30000, 1.0, '소액 UTXO'),
      (50000, 1.0, '5만 sats'),
      (100000, 1.0, '10만 sats'),
      (1000000, 1.0, '100만 sats'),
      (10000000, 1.0, '0.1 BTC'),
      (100000, 5.0, '높은 feeRate'),
      (100000, 50.0, '매우 높은 feeRate'),
      (10000000, 100.0, '높은 금액 + 높은 feeRate'), // estimatedFee: 8498810.0 8498975
      // (100000000, 1.0, '1 BTC'), // output 173010개: 너무 많아서 10분으로도 부족함
    ];

    for (final (amount, feeRate, description) in testCases) {
      test('$description (amount: $amount, feeRate: $feeRate)', () async {
        final utxo = createUtxo(amount);
        final builder = createBuilder(utxo, feeRate);
        final maxCount = await builder.getMaxEqualSplitCount();

        print('--> maxCount: $maxCount');
        if (maxCount < 2) {
          // 분할 불가능한 경우 - 2분할도 실패해야 함
          expect(
            () => builder.buildEqualAmountSplit(splitCount: 2).future,
            throwsA(anyOf(isA<SplitOutputDustException>(), isA<SplitInsufficientAmountException>())),
          );
          return;
        }

        final result = await builder.buildEqualAmountSplit(splitCount: maxCount).future;

        expect(result.isSuccess, isTrue, reason: 'getMaxEqualSplitCount=$maxCount, buildEqualSplit 실패');
        expectSuccessfulTransaction(result);

        // 금액 합 + fee = utxo amount
        final totalAmount = result.splitAmountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
        expect(totalAmount + result.estimatedFee, utxo.amount);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  group('Preview compare with buildResult', () {
    test('FixedAmountSplit 21000 / 10000', () async {
      final utxo = createUtxo(21000);
      final builder = createBuilder(utxo, 1.0);

      final SplitPreview preview = await builder.getFixedAmountSplitPreview(amountPerOutput: 10000);
      final UtxoSplitResult result = await builder.buildFixedAmountSplit(amountPerOutput: 10000).future;

      print('--- preview.amountCountMap ---');
      print(formatAmountCountMap(preview.amountCountMap));
      print('--- result.splitAmountMap ---');
      print(formatAmountCountMap(result.splitAmountMap));

      expect(preview.estimatedFee, equals(result.estimatedFee));
    });

    test('FixedAmountSplit 50000 / 10000', () async {
      final utxo = createUtxo(50000);
      final builder = createBuilder(utxo, 1.0);

      final SplitPreview preview = await builder.getFixedAmountSplitPreview(amountPerOutput: 10000);
      final UtxoSplitResult result = await builder.buildFixedAmountSplit(amountPerOutput: 10000).future;

      print('--- preview.amountCountMap ---');
      print(formatAmountCountMap(preview.amountCountMap));
      print('--- result.splitAmountMap ---');
      print(formatAmountCountMap(result.splitAmountMap));

      expect(preview.estimatedFee, equals(result.estimatedFee));
    });

    test('CustomAmountSplit 21000 / 10000', () async {
      final utxo = createUtxo(21000);
      final builder = createBuilder(utxo, 1.0);

      final SplitPreview preview = await builder.getCustomAmountSplitPreview(amountCountMap: {10000: 2});
      final UtxoSplitResult result = await builder.buildCustomAmountSplit(amountCountMap: {10000: 2}).future;

      print('--- preview.amountCountMap ---');
      print(formatAmountCountMap(preview.amountCountMap));
      print('--- result.splitAmountMap ---');
      print(formatAmountCountMap(result.splitAmountMap));

      expect(preview.estimatedFee, equals(result.estimatedFee));
    });

    test('EqualAmountSplit 99990000 / 5000개로 나누기', () async {
      final utxo = createUtxo(99990000);
      final builder = createBuilder(utxo, 1.0);

      final SplitPreview preview = await builder.getEqualAmountSplitPreview(splitCount: 5000);
      final UtxoSplitResult result = await builder.buildEqualAmountSplit(splitCount: 5000).future;

      print('--- preview.amountCountMap ---');
      print(formatAmountCountMap(preview.amountCountMap));
      print('--- result.splitAmountMap ---');
      print(formatAmountCountMap(result.splitAmountMap));

      expect(preview.estimatedFee, equals(result.estimatedFee));
    });

    /// feeRate 커질수록 예상 수수료 예측값이 차이가 커지는 상황
    test('EqualAmountSplit 989807 / 20개로 나누기 / feeRate 1000', () async {
      final utxo = createUtxo(989807);
      final builder = createBuilder(utxo, 1000.0);

      final SplitPreview preview = await builder.getEqualAmountSplitPreview(splitCount: 20);
      final UtxoSplitResult result = await builder.buildEqualAmountSplit(splitCount: 20).future;

      print('--- preview.amountCountMap ---');
      print(formatAmountCountMap(preview.amountCountMap));
      print('--- result.splitAmountMap ---');
      print(formatAmountCountMap(result.splitAmountMap));
      print('--- fee ---');
      print(preview.estimatedFee);
      print(result.estimatedFee);
      expect(preview.estimatedFee, isNot(equals(result.estimatedFee)));
    });
  });
}
