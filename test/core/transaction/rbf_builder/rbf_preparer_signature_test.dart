import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_preparer.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:flutter_test/flutter_test.dart';

Seed _seed(int byte) => Seed.fromEntropy(Uint8List.fromList(List.filled(16, byte)));

KeyStore _publicKey(KeyStore key) =>
    KeyStore.fromExtendedPublicKey(key.extendedPublicKey.serialize(), key.masterFingerprint);

/// 이 지갑 키로 서명한 대기 거래(남에게 30,000 sats + 잔돈)와 그 입력 UTXO
class _SignedPending {
  _SignedPending({
    required this.name,
    required this.item,
    required this.purpose,
    required this.addressType,
    required String Function(String psbt) sign,
    Policy? scriptPathPolicy,
  }) {
    final wallet = item.walletBase;
    utxo = UtxoState(
      transactionHash: 'ab' * 32,
      index: 0,
      amount: 100000,
      derivationPath: '$purpose/0/0',
      blockHeight: 100,
      to: wallet.getAddress(0),
      timestamp: DateTime(2026, 11, 1),
    );
    final unsigned =
        TransactionBuilder(
          availableUtxos: [utxo],
          recipients: {
            SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 0x99))).getAddress(0): 30000,
          },
          feeRate: 2,
          changeDerivationPath: '$purpose/1/0',
          walletItemBase: item,
          isFeeSubtractedFromAmount: false,
          isUtxoFixed: true,
          scriptPathPolicy: scriptPathPolicy,
        ).build().transaction!;
    signed = Psbt.parse(sign(Psbt.fromTransaction(unsigned, wallet).serialize())).getSignedTransaction(addressType);
    for (var i = 0; i < 10; i++) {
      receive.add(wallet.getAddress(i));
      change.add(wallet.getAddress(i, isChange: true));
    }
  }

  final String name;
  final WalletItemBase item;
  final String purpose;
  final AddressType addressType;
  late final UtxoState utxo;
  late final Transaction signed;
  final List<String> receive = [];
  final List<String> change = [];

  /// 서버가 같은 거래를 서명 없이 보여 준 것(거래 번호는 서명을 담지 않아 같다)
  Transaction get withoutSignatures {
    final tx = Transaction.parse(signed.serialize());
    for (final input in tx.inputs) {
      input.witnessList = [];
    }
    return tx;
  }

  /// 서명 하나만 엉뚱한 바이트로 바꾼 것(공개키·스크립트는 그대로)
  Transaction get withForgedSignature {
    final tx = Transaction.parse(signed.serialize());
    final witness = tx.inputs.first.witnessList;
    final index = witness.indexWhere((item) => item.isNotEmpty);
    witness[index] = '11' * (witness[index].length ~/ 2);
    return tx;
  }

  /// 서명 바이트는 그대로 두고 해시 유형만 SIGHASH_NONE(0x02)으로 바꾼 것(거래 번호는 같다)
  Transaction get withSighashNone {
    final tx = Transaction.parse(signed.serialize());
    final witness = tx.inputs.first.witnessList;
    final index = addressType == AddressType.p2wsh ? 1 : 0;
    final signature = witness[index];
    witness[index] = signature.length == 128 ? '${signature}02' : '${signature.substring(0, signature.length - 2)}02';
    return tx;
  }

  TransactionRecord get record {
    final outputs = [for (final output in signed.outputs) TransactionAddress(output.getAddress(), output.amount)];
    final paid = outputs.where((output) => !change.contains(output.address)).fold(0, (sum, o) => sum + o.amount);
    return TransactionRecord.fromTransactions(
      transactionHash: signed.transactionHash,
      timestamp: DateTime(2026, 11, 11),
      blockHeight: 0,
      transactionType: TransactionType.sent,
      amount: -paid,
      fee: utxo.amount - outputs.fold(0, (sum, o) => sum + o.amount),
      inputAddressList: [TransactionAddress(utxo.to, utxo.amount)],
      outputAddressList: outputs,
      vSize: signed.getVirtualByte(),
    );
  }

  RbfPreparer prepare(Transaction serverTx) => RbfPreparer.fromPendingTx(
    pendingTx: record,
    rawTx: serverTx.serialize(),
    getUtxos: _getUtxos,
    isMyAddress: _isMyAddress,
    getDerivationPath: _getDerivationPath,
  );

  /// 수수료 올리기 화면이 쓰는 길: 서명 확인을 다른 아이솔레이트에서 한다
  Future<RbfPreparer> prepareAsync(Transaction serverTx) => RbfPreparer.fromPendingTxAsync(
    pendingTx: record,
    rawTx: serverTx.serialize(),
    getUtxos: _getUtxos,
    isMyAddress: _isMyAddress,
    getDerivationPath: _getDerivationPath,
  );

  UtxoState? _getUtxos(String utxoId) =>
      utxoId == getUtxoId(utxo.transactionHash, utxo.index)
          ? UtxoState(
            transactionHash: utxo.transactionHash,
            index: utxo.index,
            amount: utxo.amount,
            derivationPath: utxo.derivationPath,
            blockHeight: utxo.blockHeight,
            to: utxo.to,
            timestamp: utxo.timestamp,
            status: UtxoStatus.outgoing,
            spentByTransactionHash: signed.transactionHash,
          )
          : null;

  bool _isMyAddress(String address, {bool isChange = false}) => (isChange ? change : receive).contains(address);

  String _getDerivationPath(String address) {
    if (receive.contains(address)) return '$purpose/0/${receive.indexOf(address)}';
    if (change.contains(address)) return '$purpose/1/${change.indexOf(address)}';
    return '';
  }
}

List<_SignedPending> _fixtures() {
  NetworkType.setNetworkType(NetworkType.regtest);
  final single = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 0x11)));
  final cosigners = [
    for (final byte in [0x31, 0x32, 0x33]) KeyStore.fromSeed(_seed(byte), AddressType.p2wsh),
  ];
  final multisig = MultisignatureVault.fromKeyStoreList(cosigners, 2);
  final parent = KeyStore.fromSeed(_seed(0x41), AddressType.p2tr);
  final beneficiary = KeyStore.fromSeed(_seed(0x42), AddressType.p2tr);
  final publicPolicy = InheritancePolicy(_publicKey(beneficiary), 1792646340);
  final taproot = TaprootWallet.fromKeyStoreList([_publicKey(parent)], [publicPolicy]);
  final scriptPathItem = TaprootWalletItem(
    id: 4,
    name: 'Inheritance',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: taproot.descriptor,
    keyPathSeedInfos: [],
    scriptPathSeedInfos: [
      TaprootScriptPathSeedInfo(
        miniscript: publicPolicy.toMiniscript(),
        extendedPublicKeys: [beneficiary.extendedPublicKey.serialize()],
      ),
    ],
  );
  return [
    _SignedPending(
      name: 'p2wpkh',
      item: SinglesigWalletItem(id: 1, name: 'Single', colorIndex: 0, iconIndex: 0, descriptor: single.descriptor),
      purpose: "m/84'/1'/0'",
      addressType: AddressType.p2wpkh,
      sign: single.addSignatureToPsbt,
    ),
    _SignedPending(
      name: 'p2wsh 2-of-3',
      item: MultisigWalletItem(
        id: 2,
        name: 'Multisig',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: multisig.descriptor,
        signers: [for (var i = 0; i < 3; i++) MultisigSigner(name: 'S$i', iconIndex: i, colorIndex: i, memo: '')],
        requiredSignatureCount: 2,
      ),
      purpose: "m/48'/1'/0'/2'",
      addressType: AddressType.p2wsh,
      sign: multisig.addSignatureToPsbt,
    ),
    _SignedPending(
      name: 'p2tr key path',
      item: TaprootWalletItem(
        id: 3,
        name: 'Taproot',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: taproot.descriptor,
        keyPathSeedInfos: [_publicKey(parent).extendedPublicKey.serialize()],
        scriptPathSeedInfos: [],
      ),
      purpose: "m/86'/1'/0'",
      addressType: AddressType.p2tr,
      sign: TaprootVault.fromKeyStoreList([parent], [publicPolicy]).addSignatureToPsbt,
    ),
    _SignedPending(
      name: 'p2tr script path',
      item: scriptPathItem,
      purpose: "m/86'/1'/0'",
      addressType: AddressType.p2tr,
      sign:
          TaprootVault.fromKeyStoreList(
            [_publicKey(parent)],
            [InheritancePolicy(beneficiary, 1792646340)],
          ).addSignatureToPsbt,
      scriptPathPolicy: scriptPathItem.defaultPolicy,
    ),
  ];
}

void main() {
  for (final fixture in _fixtures()) {
    group('RbfPreparer 서명 확인 (${fixture.name})', () {
      test('이 지갑 키로 서명한 대기 거래는 그대로 준비된다', () {
        expect(fixture.prepare(fixture.signed).inputUtxos.single.utxoId, fixture.utxo.utxoId);
      });

      test('서버가 서명 없이 보여 준 같은 거래로는 대체 거래를 만들지 않는다', () {
        expect(fixture.withoutSignatures.transactionHash, fixture.signed.transactionHash);
        expect(
          () => fixture.prepare(fixture.withoutSignatures),
          throwsA(isA<UnverifiedOriginalTransactionException>()),
        );
      });

      test('서명이 맞지 않는 같은 거래로는 대체 거래를 만들지 않는다', () {
        expect(fixture.withForgedSignature.transactionHash, fixture.signed.transactionHash);
        expect(
          () => fixture.prepare(fixture.withForgedSignature),
          throwsA(isA<UnverifiedOriginalTransactionException>()),
        );
      });

      test('해시 유형만 SIGHASH_NONE으로 바꾼 서명으로는 대체 거래를 만들지 않는다 (동기·비동기)', () async {
        expect(fixture.withSighashNone.transactionHash, fixture.signed.transactionHash);
        expect(() => fixture.prepare(fixture.withSighashNone), throwsA(isA<UnverifiedOriginalTransactionException>()));
        await expectLater(
          fixture.prepareAsync(fixture.withSighashNone),
          throwsA(isA<UnverifiedOriginalTransactionException>()),
        );
      });

      test('로컬 UTXO가 없으면 동기·비동기 모두 UtxoNotFoundException', () async {
        RbfPreparer sync() => RbfPreparer.fromPendingTx(
          pendingTx: fixture.record,
          rawTx: fixture.signed.serialize(),
          getUtxos: (_) => null,
          isMyAddress: fixture._isMyAddress,
          getDerivationPath: fixture._getDerivationPath,
        );
        expect(sync, throwsA(isA<UtxoNotFoundException>()));
        await expectLater(
          RbfPreparer.fromPendingTxAsync(
            pendingTx: fixture.record,
            rawTx: fixture.signed.serialize(),
            getUtxos: (_) => null,
            isMyAddress: fixture._isMyAddress,
            getDerivationPath: fixture._getDerivationPath,
          ),
          throwsA(isA<UtxoNotFoundException>()),
        );
      });

      test('수수료 올리기 화면의 길(다른 아이솔레이트에서 확인)도 결과가 같다', () async {
        expect((await fixture.prepareAsync(fixture.signed)).inputUtxos.single.utxoId, fixture.utxo.utxoId);
        await expectLater(
          fixture.prepareAsync(fixture.withoutSignatures),
          throwsA(isA<UnverifiedOriginalTransactionException>()),
        );
        await expectLater(
          fixture.prepareAsync(fixture.withForgedSignature),
          throwsA(isA<UnverifiedOriginalTransactionException>()),
        );
      });
    });
  }

  test('로컬 UTXO 주소가 깨져 이전 출력을 만들 수 없으면 동기·비동기 모두 서명 확인 불가로 본다', () async {
    final fixture = _fixtures().first;
    UtxoState broken(String utxoId) => UtxoState(
      transactionHash: fixture.utxo.transactionHash,
      index: 0,
      amount: fixture.utxo.amount,
      derivationPath: fixture.utxo.derivationPath,
      blockHeight: 100,
      to: 'not-a-bitcoin-address',
      timestamp: DateTime(2026),
    );
    expect(
      () => RbfPreparer.fromPendingTx(
        pendingTx: fixture.record,
        rawTx: fixture.signed.serialize(),
        getUtxos: broken,
        isMyAddress: fixture._isMyAddress,
        getDerivationPath: fixture._getDerivationPath,
      ),
      throwsA(isA<UnverifiedOriginalTransactionException>()),
    );
    await expectLater(
      RbfPreparer.fromPendingTxAsync(
        pendingTx: fixture.record,
        rawTx: fixture.signed.serialize(),
        getUtxos: broken,
        isMyAddress: fixture._isMyAddress,
        getDerivationPath: fixture._getDerivationPath,
      ),
      throwsA(isA<UnverifiedOriginalTransactionException>()),
    );
  });

  test('원문이 이 거래가 아니면 동기·비동기 모두 로컬 UTXO를 읽기 전에 ArgumentError', () async {
    final fixture = _fixtures().first;
    final other = Transaction.parse(fixture.signed.serialize());
    other.outputs.removeLast();
    UtxoState? unreadable(String utxoId) => throw StateError('local repository is unavailable');
    expect(
      () => RbfPreparer.fromPendingTx(
        pendingTx: fixture.record,
        rawTx: other.serialize(),
        getUtxos: unreadable,
        isMyAddress: fixture._isMyAddress,
        getDerivationPath: fixture._getDerivationPath,
      ),
      throwsArgumentError,
    );
    await expectLater(
      RbfPreparer.fromPendingTxAsync(
        pendingTx: fixture.record,
        rawTx: other.serialize(),
        getUtxos: unreadable,
        isMyAddress: fixture._isMyAddress,
        getDerivationPath: fixture._getDerivationPath,
      ),
      throwsArgumentError,
    );
  });

  test('서명 확인을 다른 아이솔레이트에서 하는 동안 메인 아이솔레이트는 멈추지 않는다 (입력 120개)', () async {
    NetworkType.setNetworkType(NetworkType.regtest);
    final vault = SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 0x11)));
    final item = SinglesigWalletItem(id: 1, name: 'Single', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor);
    final receive = vault.getAddress(0);
    final change = vault.getAddress(0, isChange: true);
    final coins = [
      for (var i = 0; i < 120; i++)
        UtxoState(
          transactionHash: 'cd' * 32,
          index: i,
          amount: 10000,
          derivationPath: "m/84'/1'/0'/0/0",
          blockHeight: 100,
          to: receive,
          timestamp: DateTime(2026, 11, 1),
        ),
    ];
    final unsigned =
        TransactionBuilder(
          availableUtxos: coins,
          recipients: {
            SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, 0x99))).getAddress(0): 600000,
          },
          feeRate: 2,
          changeDerivationPath: "m/84'/1'/0'/1/0",
          walletItemBase: item,
          isFeeSubtractedFromAmount: false,
          isUtxoFixed: true,
        ).build().transaction!;
    final signed = Psbt.parse(
      vault.addSignatureToPsbt(Psbt.fromTransaction(unsigned, vault).serialize()),
    ).getSignedTransaction(AddressType.p2wpkh);
    final outputs = [for (final output in signed.outputs) TransactionAddress(output.getAddress(), output.amount)];
    final record = TransactionRecord.fromTransactions(
      transactionHash: signed.transactionHash,
      timestamp: DateTime(2026, 11, 11),
      blockHeight: 0,
      transactionType: TransactionType.sent,
      amount: -outputs.where((o) => o.address != change).fold(0, (sum, o) => sum + o.amount),
      fee: 1200000 - outputs.fold(0, (sum, o) => sum + o.amount),
      inputAddressList: [for (final coin in coins) TransactionAddress(coin.to, coin.amount)],
      outputAddressList: outputs,
      vSize: signed.getVirtualByte(),
    );
    final coinById = {for (final coin in coins) coin.utxoId: coin};
    UtxoState? getUtxos(String utxoId) => coinById[utxoId];
    bool isMyAddress(String address, {bool isChange = false}) => address == (isChange ? change : receive);
    String getDerivationPath(String address) => address == change ? "m/84'/1'/0'/1/0" : "m/84'/1'/0'/0/0";

    final watch = Stopwatch()..start();
    RbfPreparer.fromPendingTx(
      pendingTx: record,
      rawTx: signed.serialize(),
      getUtxos: getUtxos,
      isMyAddress: isMyAddress,
      getDerivationPath: getDerivationPath,
    );
    final blockingMs = watch.elapsedMilliseconds;

    final ticks = Stopwatch()..start();
    var lastTick = 0;
    var maxGapMs = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      maxGapMs = math.max(maxGapMs, ticks.elapsedMilliseconds - lastTick);
      lastTick = ticks.elapsedMilliseconds;
    });
    final preparer = await RbfPreparer.fromPendingTxAsync(
      pendingTx: record,
      rawTx: signed.serialize(),
      getUtxos: getUtxos,
      isMyAddress: isMyAddress,
      getDerivationPath: getDerivationPath,
    );
    timer.cancel();

    expect(preparer.inputUtxos, hasLength(120));
    expect(blockingMs, greaterThan(200), reason: '같은 확인을 메인 아이솔레이트에서 하면 이만큼 멈춘다');
    expect(maxGapMs, lessThan(blockingMs ~/ 2), reason: '확인하는 동안에도 메인 아이솔레이트의 타이머가 돈다');
  });

  test('서명이 맞는 대기 거래는 수수료를 올린 대체 거래를 만들 수 있다 (p2wpkh)', () {
    final fixture = _fixtures().first;
    final result = RbfBuilder(
      preparer: fixture.prepare(fixture.signed),
      walletItemBase: fixture.item,
      nextChangeAddress: WalletAddress(fixture.change[1], "${fixture.purpose}/1/1", 1, true, false, 0, 0, 0),
    ).build(newFeeRate: 5);
    expect(result.isSuccess, isTrue, reason: '${result.exception}');
  });
}
