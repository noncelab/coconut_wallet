import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/transaction_mock.dart';
import '../../../mock/utxo_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';

const _inputHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _previousHash = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _WalletProvider extends Fake implements WalletProvider {
  final WalletItemBase wallet;
  final Set<String> ownedAddresses = {};

  _WalletProvider(this.wallet);

  @override
  WalletItemBase getWalletById(int id) => wallet;

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) =>
      walletId == wallet.id && ownedAddresses.contains(address);
}

class _NodeProvider extends Fake implements NodeProvider {
  int broadcasts = 0;
  bool fails = false;
  void Function()? duringBroadcast;

  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async => Result.success(BlockTimestamp(100, DateTime(2026)));

  @override
  Future<Result<String>> broadcast(Transaction signedTx) async {
    broadcasts++;
    duringBroadcast?.call();
    return fails ? Result.failure(ErrorCodes.broadcastError) : Result.success(signedTx.transactionHash);
  }
}

class _TransactionProvider extends Fake implements TransactionProvider {
  TransactionRecord? previous;

  @override
  TransactionRecord? getTransactionRecord(int walletId, String txHash) =>
      walletId == 1 && previous?.transactionHash == txHash ? previous : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestRealmManager manager;
  late UtxoRepository repository;
  late _NodeProvider node;
  late _TransactionProvider transactions;
  late _WalletProvider wallets;
  late SingleSignatureVault vault;
  late BroadcastingViewModel viewModel;
  late UtxoTagProvider tags;

  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.testnet);
    vault = SingleSignatureVault.fromEntropy(Uint8List(16));
  });

  setUp(() {
    manager = TestRealmManager();
    repository = UtxoRepository(manager);
    node = _NodeProvider();
    transactions = _TransactionProvider();
    wallets = _WalletProvider(
      SinglesigWalletItem(id: 1, name: 'Test', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor),
    );
    tags = UtxoTagProvider(repository);
    manager.realm.write(() {
      manager.realm.add(
        UtxoMock.createUnspentRealmUtxo(walletId: 1, address: vault.getAddress(0), transactionHash: _inputHash),
      );
    });
  });

  tearDown(() {
    tags.dispose();
    manager.dispose();
  });

  void addTag(String id, String source, {int walletId = 1}) {
    manager.realm.write(() {
      manager.realm.add(RealmUtxoTag(id, walletId, id, 0, DateTime(2026), utxoIdList: [source]));
    });
  }

  List<String> tagIds(String utxoId, {int walletId = 1}) =>
      repository.getUtxoTagsByTxHash(walletId, utxoId).value.map((tag) => tag.id).toList();

  Future<void> initializeTransaction(Transaction transaction, {bool returnPsbt = false}) async {
    transaction.changeAddressDerivationPath = "${vault.derivationPath}/1/1";
    final original = Psbt.fromTransaction(transaction, vault);
    final signed = Psbt.parse(vault.addSignatureToPsbt(original.serialize()));
    if (returnPsbt) {
      // Some signers retain input derivation but omit optional output metadata.
      signed.psbtMap['outputs'][0].clear();
    }
    final sendInfo =
        SendInfoProvider()
          ..setWalletId(1)
          ..setTxWaitingForSign(original.serialize())
          ..setSignedResult(
            returnPsbt ? signed.serialize() : signed.getSignedTransaction(AddressType.p2wpkh).serialize(),
          );
    viewModel = BroadcastingViewModel(
      sendInfo,
      wallets,
      tags,
      true,
      node,
      transactions,
      TransactionDraftRepository(manager),
      repository,
      null,
    );
    addTearDown(viewModel.dispose);
    expect(await viewModel.setTxInfo(), isNull);
    expect(viewModel.isInitDone, isTrue);
  }

  Future<void> initialize({
    bool ownOutput = true,
    bool outputDerivation = true,
    bool returnPsbt = false,
    int outputAmount = 999000,
  }) async {
    final recipient = ownOutput ? vault.getAddress(1, isChange: true) : vault.getAddress(10);
    final transaction = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment(_inputHash, 0, sequence: 0xfffffffd)],
      [
        TransactionOutput.forPayment(
          outputAmount,
          recipient,
          derivationPath: ownOutput && outputDerivation ? "${vault.derivationPath}/1/1" : null,
          isChangeOutput: ownOutput && outputDerivation,
        ),
      ],
      AddressType.p2wpkh,
    );
    transaction.utxoList.add(Utxo(_inputHash, 0, 1000000, "${vault.derivationPath}/0/0"));
    await initializeTransaction(transaction, returnPsbt: returnPsbt);
  }

  String targetId() => getUtxoId(viewModel.signedTx!.transactionHash, 0);
  final inputId = getUtxoId(_inputHash, 0);

  test('normal broadcast persists input tags on a PSBT-owned output and clears only consumed links', () async {
    addTag('savings', inputId);
    addTag('unrelated', 'another-utxo');
    addTag('other-wallet', inputId, walletId: 2);
    await initialize(returnPsbt: true);
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);

    final result = await viewModel.broadcast(inheritedTagIds: ['savings']);

    expect(result.isSuccess, isTrue);
    expect(tagIds(targetId()), ['savings']);
    expect(tagIds(inputId), isEmpty);
    expect(tagIds('another-utxo'), ['unrelated']);
    expect(tagIds(inputId, walletId: 2), ['other-wallet']);
    expect(viewModel.tagInheritanceFailed, isFalse);
    expect(tags.isUpdatedTagList, isTrue);
  });

  test('address ownership recognizes self-send outputs without PSBT output derivation', () async {
    addTag('savings', inputId);
    wallets.ownedAddresses.add(vault.getAddress(1, isChange: true));
    await initialize(outputDerivation: false);
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);
    await viewModel.broadcast(inheritedTagIds: ['savings']);
    expect(tagIds(targetId()), ['savings']);
  });

  test('failed broadcast preserves source links and retry uses the original snapshot', () async {
    addTag('savings', inputId);
    await initialize();
    viewModel.prepareTagInheritance();
    node.fails = true;
    expect((await viewModel.broadcast(inheritedTagIds: ['savings'])).isFailure, isTrue);
    expect(tagIds(inputId), ['savings']);
    expect(tagIds(targetId()), isEmpty);

    manager.realm.write(() => manager.realm.find<RealmUtxoTag>('savings')!.utxoIdList.clear());
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);
    node.fails = false;
    expect((await viewModel.broadcast(inheritedTagIds: ['savings'])).isSuccess, isTrue);
    expect(tagIds(targetId()), ['savings']);
    expect(node.broadcasts, 2);
  });

  test('sync removing source associations during broadcast cannot erase the captured tags', () async {
    addTag('savings', inputId);
    await initialize();
    viewModel.prepareTagInheritance();
    node.duringBroadcast = () {
      manager.realm.write(() => manager.realm.find<RealmUtxoTag>('savings')!.utxoIdList.clear());
    };
    await viewModel.broadcast(inheritedTagIds: ['savings']);
    expect(tagIds(targetId()), ['savings']);
  });

  test('RBF inherits predecessor output tags before its output UTXO is synchronized', () async {
    final previousOutput = getUtxoId(_previousHash, 1);
    addTag('savings', previousOutput);
    manager.realm.write(() {
      final input = manager.realm.find<RealmUtxo>(inputId)!;
      input.status = 'outgoing';
      input.spentByTransactionHash = _previousHash;
    });
    transactions.previous = TransactionMock.createUnconfirmedTransactionRecord(transactionHash: _previousHash);
    expect(repository.getUtxoState(1, previousOutput), isNull);
    await initialize();
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);
    await viewModel.broadcast(inheritedTagIds: ['savings']);
    expect(tagIds(targetId()), ['savings']);
    expect(tagIds(previousOutput), isEmpty);
  });

  test('confirmed predecessor output tags are not candidates for another transaction', () async {
    addTag('savings', getUtxoId(_previousHash, 1));
    manager.realm.write(() {
      final input = manager.realm.find<RealmUtxo>(inputId)!;
      input.status = 'outgoing';
      input.spentByTransactionHash = _previousHash;
    });
    transactions.previous = TransactionMock.createConfirmedTransactionRecord(transactionHash: _previousHash);
    await initialize();
    expect(viewModel.prepareTagInheritance(), isEmpty);
  });

  test('second RBF unions immediate predecessor tags with extra input tags onto every own output', () async {
    addTag('savings', inputId);
    await initialize();
    await viewModel.broadcast(inheritedTagIds: ['savings']);
    final originalHash = viewModel.signedTx!.transactionHash;
    manager.realm.write(() {
      final input = manager.realm.find<RealmUtxo>(inputId)!;
      input.status = 'outgoing';
      input.spentByTransactionHash = originalHash;
    });
    transactions.previous = TransactionMock.createUnconfirmedTransactionRecord(transactionHash: originalHash);

    await initialize(outputAmount: 998000);
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['savings']);
    await viewModel.broadcast(inheritedTagIds: ['savings']);
    final firstBumpHash = viewModel.signedTx!.transactionHash;
    final firstBumpOutput = getUtxoId(firstBumpHash, 0);
    addTag('reviewed', firstBumpOutput);
    const extraHash = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    final extraInputId = getUtxoId(extraHash, 3);
    addTag('salary', extraInputId);
    manager.realm.write(() {
      manager.realm.find<RealmUtxo>(inputId)!.spentByTransactionHash = firstBumpHash;
      manager.realm.add(
        UtxoMock.createUnspentRealmUtxo(
          walletId: 1,
          address: vault.getAddress(1),
          amount: 300000,
          transactionHash: extraHash,
          index: 3,
          addressIndex: 1,
        ),
      );
    });
    transactions.previous = TransactionMock.createUnconfirmedTransactionRecord(transactionHash: firstBumpHash);
    wallets.ownedAddresses.add(vault.getAddress(2));
    final secondBump = Transaction.withInputsAndOutputs(
      [
        TransactionInput.forPayment(_inputHash, 0, sequence: 0xfffffffd),
        TransactionInput.forPayment(extraHash, 3, sequence: 0xfffffffd),
      ],
      [
        TransactionOutput.forPayment(400000, vault.getAddress(10)),
        TransactionOutput.forPayment(400000, vault.getAddress(2)),
        TransactionOutput.forPayment(
          497000,
          vault.getAddress(1, isChange: true),
          derivationPath: "${vault.derivationPath}/1/1",
          isChangeOutput: true,
        ),
      ],
      AddressType.p2wpkh,
    );
    secondBump.utxoList.addAll([
      Utxo(_inputHash, 0, 1000000, "${vault.derivationPath}/0/0"),
      Utxo(extraHash, 3, 300000, "${vault.derivationPath}/0/1"),
    ]);
    await initializeTransaction(secondBump);
    const expectedTags = ['savings', 'reviewed', 'salary'];
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), unorderedEquals(expectedTags));
    expect((await viewModel.broadcast(inheritedTagIds: expectedTags)).isSuccess, isTrue);
    final secondBumpHash = viewModel.signedTx!.transactionHash;
    expect(tagIds(getUtxoId(secondBumpHash, 0)), isEmpty);
    for (final index in [1, 2]) {
      expect(tagIds(getUtxoId(secondBumpHash, index)), unorderedEquals(expectedTags));
    }
    for (final source in [inputId, extraInputId, getUtxoId(originalHash, 0), firstBumpOutput]) {
      expect(tagIds(source), isEmpty);
    }
    expect(node.broadcasts, 3);
  });

  test('CPFP inherits the spent incoming output tags while preserving a sibling output', () async {
    addTag('incoming', inputId);
    final siblingId = getUtxoId(_inputHash, 1);
    addTag('sibling', siblingId);
    manager.realm.write(() {
      final input = manager.realm.find<RealmUtxo>(inputId)!;
      input.status = 'incoming';
      input.blockHeight = 0;
    });
    await initialize();
    expect(viewModel.prepareTagInheritance().map((tag) => tag.id), ['incoming']);
    await viewModel.broadcast(inheritedTagIds: ['incoming']);
    expect(tagIds(targetId()), ['incoming']);
    expect(tagIds(inputId), isEmpty);
    expect(tagIds(siblingId), ['sibling']);
  });

  test('full send has no consent candidates and removes source links only after success', () async {
    addTag('savings', inputId);
    await initialize(ownOutput: false);
    expect(viewModel.prepareTagInheritance(), isEmpty);
    expect(tagIds(inputId), ['savings']);
    await viewModel.broadcast(inheritedTagIds: []);
    expect(tagIds(inputId), isEmpty);
    expect(tagIds(targetId()), isEmpty);
  });

  test('declining inheritance keeps tag definitions but clears consumed associations', () async {
    addTag('savings', inputId);
    await initialize();
    viewModel.prepareTagInheritance();
    await viewModel.broadcast(inheritedTagIds: []);
    expect(tagIds(inputId), isEmpty);
    expect(tagIds(targetId()), isEmpty);
    expect(repository.getUtxoTags(1).value.map((tag) => tag.id), ['savings']);
  });

  test('unknown or more than five selected tags are rejected before network broadcast', () async {
    for (var i = 0; i < 6; i++) {
      addTag('tag$i', inputId);
    }
    await initialize();
    final candidates = viewModel.prepareTagInheritance().map((tag) => tag.id).toList();
    expect(candidates, hasLength(6));
    await expectLater(viewModel.broadcast(inheritedTagIds: ['unknown']), throwsArgumentError);
    await expectLater(viewModel.broadcast(inheritedTagIds: candidates), throwsArgumentError);
    expect(node.broadcasts, 0);
    expect(tagIds(inputId), hasLength(6));

    await viewModel.broadcast(inheritedTagIds: candidates.take(5).toList());
    expect(tagIds(targetId()), unorderedEquals(candidates.take(5)));
    expect(tagIds(inputId), isEmpty);
  });

  test('tag persistence failure after node acceptance never reports transaction failure', () async {
    addTag('savings', inputId);
    await initialize();
    viewModel.prepareTagInheritance();
    node.duringBroadcast = () {
      manager.realm.write(() => manager.realm.delete(manager.realm.find<RealmUtxoTag>('savings')!));
    };
    expect((await viewModel.broadcast(inheritedTagIds: ['savings'])).isSuccess, isTrue);
    expect(viewModel.tagInheritanceFailed, isTrue);
    expect(node.broadcasts, 1);
  });
}
