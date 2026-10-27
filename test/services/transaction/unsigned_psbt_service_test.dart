import 'dart:isolate';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/transaction/unsigned_psbt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur/utils.dart';

import '../../core/transaction/rbf_builder/setup_util.dart';
import '../../core/transaction/cpfp_builder/setup_util.dart';

import '../../mock/wallet_mock.dart';

class _ObservedTransaction extends Transaction {
  final Transaction original;
  final SendPort observations;
  bool _reported = false;

  _ObservedTransaction(this.original, this.observations)
    : super(
        Codec.decodeHex(original.version),
        original.inputs,
        original.outputs,
        Codec.decodeHex(original.lockTime),
        true,
      ) {
    changeAddressDerivationPath = original.changeAddressDerivationPath;
  }

  @override
  List<Utxo> get utxoList {
    if (!_reported) {
      _reported = true;
      observations.send(Isolate.current.controlPort);
    }
    return original.utxoList;
  }
}

void main() {
  late NetworkType previousNetwork;
  setUp(() => previousNetwork = NetworkType.currentNetworkType);
  tearDown(() => NetworkType.setNetworkType(previousNetwork));

  Transaction buildTransaction(WalletItemBase item, {int count = 1}) {
    final wallet = item.walletBase;
    final result =
        TransactionBuilder(
          availableUtxos: List.generate(
            count,
            (index) => UtxoState(
              transactionHash: (index + 1).toRadixString(16).padLeft(64, '0'),
              index: 0,
              amount: 100000,
              blockHeight: 100,
              to: wallet.getAddress(index),
              derivationPath: '${wallet.derivationPath}/0/$index',
              timestamp: DateTime(2026, 10, 20),
            ),
          ),
          recipients: {wallet.getAddress(count + 1): count * 50000},
          feeRate: 1,
          changeDerivationPath: '${wallet.derivationPath}/1/0',
          walletItemBase: item,
          isFeeSubtractedFromAmount: false,
          isUtxoFixed: true,
        ).build();
    expect(result.isSuccess, isTrue, reason: result.exception?.toString());
    return result.transaction!;
  }

  for (final network in [NetworkType.mainnet, NetworkType.testnet, NetworkType.regtest]) {
    test('$network preserves PSBT, fee and transaction across isolate', () async {
      NetworkType.setNetworkType(network);
      final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
      final item = SinglesigWalletItem(id: 1, name: 'test', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor);
      final tx = buildTransaction(item);
      final expected = Psbt.fromTransaction(tx, item.walletBase);
      final result = await prepareUnsignedPsbt(transaction: tx, wallet: item.walletBase);
      expect(result.serialized, expected.serialize());
      expect(result.psbt.serialize(), result.serialized);
      expect(result.fee, expected.fee);
      expect(NetworkType.currentNetworkType, network);
    });
  }

  test('multisig and Passport retain the same PSBT format', () async {
    NetworkType.setNetworkType(NetworkType.regtest);
    final item = WalletMock.createMultiSigWalletItem();
    final tx = buildTransaction(item);
    final expected = Psbt.fromTransaction(tx, item.walletBase);
    (expected.psbtMap['global'] as Map).remove('fc07636f636f6e757401');
    final result = await prepareUnsignedPsbt(transaction: tx, wallet: item.walletBase, passport: true);
    expect(result.serialized, expected.serialize());
    expect(result.fee, expected.fee);
  });

  test('Taproot preserves the existing PSBT format', () async {
    NetworkType.setNetworkType(NetworkType.regtest);
    final item = WalletMock.createTaprootWalletItem();
    final tx = buildTransaction(item);
    final expected = Psbt.fromTransaction(tx, item.walletBase);
    final result = await prepareUnsignedPsbt(transaction: tx, wallet: item.walletBase);
    expect(result.serialized, expected.serialize());
    expect(result.fee, expected.fee);
  });

  test('worker failures propagate to the caller', () async {
    NetworkType.setNetworkType(NetworkType.regtest);
    final item = WalletMock.createSingleSigWalletItem();
    final tx = buildTransaction(item);
    tx.utxoList.clear();
    await expectLater(prepareUnsignedPsbt(transaction: tx, wallet: item.walletBase), throwsA(isA<Exception>()));
  });

  for (final multisig in [false, true]) {
    for (final cpfp in [false, true]) {
      test('fee bump PSBT matches original: multisig=$multisig cpfp=$cpfp', () async {
        NetworkType.setNetworkType(NetworkType.regtest);
        final WalletItemBase item =
            multisig ? WalletMock.createMultiSigWalletItem() : WalletMock.createSingleSigWalletItem();
        final Transaction tx;
        if (cpfp) {
          final (_, builder) = CpfpBuilderCreator(
            item,
          ).createCpfpBuilder(receivedAmounts: [100000], parentFee: 100, parentVSize: 150, minimumNetworkFeeRate: 2);
          final result = builder.getBaselineTransaction();
          expect(result.isSuccess, isTrue);
          tx = result.transaction!;
        } else {
          final (_, builder) = RbfBuilderCreator(item).createRbfBuilder(
            inputAmounts: [100000],
            recipients: [Tuple(false, 1000)],
            changeAmount: 98859,
            fee: 141,
            vSize: 141,
          );
          final result = builder.getBaselineTransaction();
          expect(result.isSuccess, isTrue);
          tx = result.transaction!;
        }
        final expected = Psbt.fromTransaction(tx, item.walletBase);
        final result = await prepareUnsignedPsbt(transaction: tx, wallet: item.walletBase);
        expect(result.serialized, expected.serialize());
        expect(result.fee, expected.fee);
      });
    }
  }

  test('many-input PSBT preparation reads transaction metadata in a worker isolate', () async {
    NetworkType.setNetworkType(NetworkType.regtest);
    final item = WalletMock.createSingleSigWalletItem();
    final tx = buildTransaction(item, count: 100);
    final observations = ReceivePort();
    addTearDown(observations.close);
    final worker = observations.first.timeout(const Duration(seconds: 30));
    final result = await prepareUnsignedPsbt(
      transaction: _ObservedTransaction(tx, observations.sendPort),
      wallet: item.walletBase,
    );
    expect(await worker, isNot(Isolate.current.controlPort));
    expect(result.psbt.inputs, hasLength(100));
    expect(result.serialized, Psbt.fromTransaction(tx, item.walletBase).serialize());
  });
}
