import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_builder.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_preparer.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../repository/realm/test_realm_manager.dart';
import 'pending_sync_harness.dart';

// test/fixtures/signing/*.json의 returned PSBT에 담긴 PSBT_GLOBAL_XPUB과 non_witness_utxo(실제 기기가 regtest에서 서명)
const _trezorXpub =
    'tpubDDPinnx7UxH5jVVXCn2E8zpRvgwsXjq3wzFMKKJcJwPcpRjz45Fw8Ps5ouMGPhbGGnKELhfFqUn7iHLSDyfbaWQc2LSFXwx9UEGygoUBqNt';
const _bitboxXpub =
    'tpubDDNXaRirbhf7t73JodgrXXA9UCvhbFfe9eLe2ScqUvTjz4Kz2v419hXQyEhfdJSPwMcKnjFaJG4o7koC5qdZNU7ESiYreZLrUf4U1WTP2gA';
const _trezorParent =
    '02000000000103db75f8600eadad7937709ee9abca99dc0ae3c47c253f4c1310eac7c499f0cb470000000000feffffffc41c7859897fa7f2'
    '90aa56af1829409ece6fc9551ac26719d8c5f324446282040100000000feffffffb61374f8b4b6e6dad86ede7e3479b269bf90381e7990a8'
    '4015369620302a6bfc0000000000feffffff022cdea9cc270100001600141387dd7c0fdccd992fe020133ff744a1cfa1fed400e1f50500000'
    '00016001496bbb46e19d6e338f0b4c197357c26bc3323db7802473044022072b16687f3546a025b65b42cdca253ca05e4d5aabeab0914627e'
    '37bf888fb17a022020a47f5ae628acabca05269645fc24e170244475baa2390490a3e17e06f9df510121035e4c2ceba5b6ee90c795372586a'
    '6c35aa77b040d47525f2223bd94f461702de30246304302200180a931a73ce507e087a906ccf3c9f5bc4d2bcf1a691d8428c36093c2e73d21'
    '021f1415ba1d9247b7734560a47dc2e73dfc90cbaffd05b3f324159e9a52557cc7012103613ebbe5b87bdccbf9dc80dda03288ee0979157e0'
    '3f0d6e488186d2a66cf311f0247304402205ca924c7c85200317ed7878ff21ad0700207f141dfa3ef1a60c0614b969fb88202202771885d82'
    '68e89aff97cb5338dadb8f67138128dc8a2c00c9ccabae08487984012102b0ce18b78bae21a0c015b13de8e1d2c2b38f9b0e9970e62cc1989'
    'cf0dbc99195655b0300';
const _bitboxParent =
    '02000000000101c73368ffb36e59efd6229fa3771bd04014cee8f0e56e5ef0bce9bbc8e793653a0100000000ffffffff0250c300000000000'
    '0160014fa649ef18cb29dd4fcb4f851de5202fee8a1a05b01eff4050000000016001428eec33372de48eb2a0966bde55b3a52ac9de981024'
    '83045022100db4b8d70e5e65c05e9309ce853dc6b08aa25eda52763c3a3698d10ed0bbd416202204311138af5bfcc29cda23abfd8bfd9168'
    '114c4c1703fdd0e230b83bb63206231012102937ef91679800f921bf7cbf824e3dbb399a0270cebfc6ac3c13a16773fcbbffe00000000';

SingleSignatureVault _vault(int byte) => SingleSignatureVault.fromEntropy(Uint8List.fromList(List.filled(16, byte)));

/// 받기 주소 [index]의 키(SIGHASH_ALL 수동 서명용)
HDWallet _receiveKey(SingleSignatureVault vault, int index) => vault.keyStore.hdWallet.derive(0).derive(index);

/// 남이 [wallet]의 받기 주소 [index]로 [amount] sats를 보내는 정상 미확정 거래. [tag]로 이전 거래를 구별한다
/// (같은 [tag]면 같은 코인을 쓰므로, 금액을 바꾸면 보낸 쪽의 RBF 대체 거래가 된다)
Transaction _paidToMe(SyncedWallet wallet, int index, int tag, {int amount = 40000}) {
  final foreign = _vault(0x55);
  final funding = fundingTransaction([(foreign.getAddress(0), 50000)], tag);
  final tx = Transaction.withInputsAndOutputs(
    [TransactionInput.forPayment(funding.transactionHash, 0)],
    [TransactionOutput.forPayment(amount, wallet.address(index))],
    AddressType.p2wpkh,
  );
  signP2wpkhInput(tx, 0, funding.outputs.single, _receiveKey(foreign, 0));
  wallet.publish([funding, tx]);
  return tx;
}

void main() {
  NetworkType.setNetworkType(NetworkType.regtest);
  final shop = _vault(0x77).getAddress(0);
  final attacker = _vault(0x88).getAddress(0);
  late TestRealmManager realm;

  setUp(() => realm = TestRealmManager());
  tearDown(() => realm.dispose());

  /// 내 결제 확인 결과가 "넣지 않음"일 때 데이터가 그대로인지 함께 본다
  Future<void> expectDropped(SyncedWallet wallet, Transaction fake, Future<void> Function() sync) async {
    final before = wallet.snapshot();
    final spendable = wallet.spendable;
    final fetches = wallet.utxoFetches;
    await sync();
    expect(wallet.snapshot(), before, reason: 'records, coin states and RBF/CPFP history stay the same');
    expect(wallet.spendable, spendable);
    expect(wallet.leavesNoTrace(fake.transactionHash), isTrue);
    expect(wallet.utxoFetches, fetches + 1, reason: 'the address UTXO fetch is not stalled by the dropped transaction');
  }

  for (final signer in walletSigners(0x10)) {
    group('1. 지갑·서명 도구: ${signer.name}', () {
      late SyncedWallet wallet;
      late Transaction deposit;
      late UtxoState coin;
      late Transaction own;

      setUp(() async {
        wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
        final funded = signer.funded([100000], 1);
        deposit = funded.funding;
        coin = funded.coins.single;
        own = signer.pay([coin], {shop: 30000});
        wallet.publish([deposit, own]);
        await wallet.sync([history(deposit, 100)], unspentList: wallet.unspent(deposit, 100));
      });

      test('정직한 서버: 이 지갑 키로 서명한 결제를 넣고 코인을 보내는 중으로 표시한다', () async {
        await wallet.sync([history(deposit, 100), history(own, 0)]);

        expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash)?.blockHeight, 0);
        expect(wallet.coin(coin.transactionHash, 0)?.status, UtxoStatus.outgoing);
        expect(wallet.coin(coin.transactionHash, 0)?.spentByTransactionHash, own.transactionHash);
        expect(wallet.utxoFetches, 2);
      });

      test('서명 바이트를 바꾼 가짜는 넣지 않고 코인·기록을 그대로 둔다', () async {
        final fake = withGarbageSignatures(own, attacker, signer.addressType);
        wallet.publish([fake]);

        await expectDropped(wallet, fake, () => wallet.sync([history(deposit, 100), history(fake, 0)]));
        expect(wallet.coin(coin.transactionHash, 0)?.status, UtxoStatus.unspent);
      });

      test('서명(증인)을 뺀 가짜는 넣지 않고 코인·기록을 그대로 둔다', () async {
        final fake = withoutWitness(own, attacker);
        wallet.publish([fake]);

        await expectDropped(wallet, fake, () => wallet.sync([history(deposit, 100), history(fake, 0)]));
      });

      test('서명 바이트는 그대로 두고 해시 유형만 SIGHASH_NONE으로 바꾼 원문은 넣지 않는다', () async {
        final forged = withSighashNone(own, signer.addressType);
        expect(forged.transactionHash, own.transactionHash);
        wallet.publish([forged]);

        await expectDropped(wallet, forged, () => wallet.sync([history(deposit, 100), history(forged, 0)]));
      });
    });
  }

  for (final hw in [
    (
      name: 'Trezor',
      fixture: 'trezor_usb',
      xpub: _trezorXpub,
      mfp: 'ba83cbfe',
      source: WalletImportSource.trezor,
      parent: _trezorParent,
      index: 0,
      isChange: false,
    ),
    (
      name: 'BitBox02',
      fixture: 'bitbox02_usb',
      xpub: _bitboxXpub,
      mfp: 'a3b2eb70',
      source: WalletImportSource.bitbox02,
      parent: _bitboxParent,
      index: 94,
      isChange: true,
    ),
    (
      name: 'MFP 없는 보기 전용 지갑(Trezor xpub, 서명은 Trezor)',
      fixture: 'trezor_usb',
      xpub: _trezorXpub,
      mfp: '00000000',
      source: WalletImportSource.extendedPublicKey,
      parent: _trezorParent,
      index: 0,
      isChange: false,
    ),
  ]) {
    group('1. 하드웨어 지갑이 돌려준 PSBT: ${hw.name}', () {
      late SyncedWallet wallet;
      late Transaction parent;
      late Transaction signed;

      Future<void> syncInput(List<Transaction> pending) => wallet.sync(
        [history(parent, 100), for (final tx in pending) history(tx, 0)],
        index: hw.index,
        isChange: hw.isChange,
      );

      setUp(() async {
        final base = SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh, hw.xpub, hw.mfp);
        wallet = SyncedWallet(realm, singlesigItem(base.descriptor, hw.source), purpose: "m/84'/1'/0'");
        final fixture =
            jsonDecode(File('test/fixtures/signing/${hw.fixture}.json').readAsStringSync()) as Map<String, dynamic>;
        signed = Psbt.parse(fixture['returnedPayload'] as String).getSignedTransaction(AddressType.p2wpkh);
        parent = Transaction.parse(hw.parent);
        expect(parent.transactionHash, signed.inputs.single.transactionHash);
        wallet.publish([parent, signed]);
        await wallet.sync(
          [history(parent, 100)],
          unspentList: wallet.unspent(parent, 100, index: hw.index, isChange: hw.isChange),
          index: hw.index,
          isChange: hw.isChange,
        );
        expect(wallet.coin(parent.transactionHash, signed.inputs.single.index)?.status, UtxoStatus.unspent);
      });

      test('기기가 서명한 그대로면 넣는다', () async {
        await syncInput([signed]);

        expect(wallet.txs.getTransactionRecord(walletId, signed.transactionHash), isNotNull);
        expect(
          wallet.coin(parent.transactionHash, signed.inputs.single.index)?.spentByTransactionHash,
          signed.transactionHash,
        );
      });

      test('서명 바이트를 바꾼 가짜는 넣지 않는다', () async {
        final fake = withGarbageSignatures(signed, attacker, AddressType.p2wpkh);
        wallet.publish([fake]);

        await expectDropped(wallet, fake, () => syncInput([fake]));
      });

      test('서명(증인)을 뺀 가짜는 넣지 않는다', () async {
        final fake = withoutWitness(signed, attacker);
        wallet.publish([fake]);

        await expectDropped(wallet, fake, () => syncInput([fake]));
      });

      test('기기 서명의 해시 유형만 SIGHASH_NONE으로 바꾼 원문은 넣지 않는다', () async {
        final forged = withSighashNone(signed, AddressType.p2wpkh);
        wallet.publish([forged]);

        await expectDropped(wallet, forged, () => syncInput([forged]));
      });
    });
  }

  group('2. 거래 모양 (p2wpkh 핫 지갑)', () {
    final signer = walletSigners(0x10).first;
    final ours = _vault(0x11);
    final foreign = _vault(0x55);
    late SyncedWallet wallet;
    var tag = 0;

    setUp(() => wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose));

    /// 받기 주소 0으로 들어온 확정 코인들(이 기기가 이미 아는 것)
    Future<({Transaction funding, List<UtxoState> coins})> receive(List<int> amounts) async {
      final funded = signer.funded(amounts, ++tag);
      wallet.publish([funded.funding]);
      await wallet.sync([history(funded.funding, 100)], unspentList: wallet.unspent(funded.funding, 100));
      return funded;
    }

    Future<void> expectKept(Transaction tx, List<UtxoState> coins, {Transaction? funding}) async {
      wallet.publish([tx]);
      await wallet.sync([if (funding != null) history(funding, 100), history(tx, 0)]);
      expect(wallet.txs.getTransactionRecord(walletId, tx.transactionHash)?.blockHeight, 0);
      for (final coin in coins) {
        expect(wallet.coin(coin.transactionHash, coin.index)?.spentByTransactionHash, tx.transactionHash);
      }
    }

    test('입력 5개짜리 내 결제를 넣는다', () async {
      final received = await receive(List.filled(5, 20000));
      final own = signer.pay(received.coins, {shop: 60000});
      expect(own.inputs, hasLength(5));

      await expectKept(own, received.coins, funding: received.funding);
    });

    test('입력 5개 중 4번째 서명만 틀린 원문은 넣지 않고, 바른 원문이 오면 넣는다', () async {
      final received = await receive(List.filled(5, 20000));
      final own = signer.pay(received.coins, {shop: 60000});
      final tampered = Transaction.parse(own.serialize());
      final witness = tampered.inputs[3].witnessList;
      witness[0] = '${'11' * (witness[0].length ~/ 2 - 1)}01';
      expect(tampered.transactionHash, own.transactionHash);
      wallet.publish([tampered]);

      await expectDropped(wallet, tampered, () => wallet.sync([history(received.funding, 100), history(tampered, 0)]));

      await expectKept(own, received.coins, funding: received.funding);
    });

    test('잔돈 없이 전부 보내기(send max)', () async {
      final received = await receive([30000, 40000]);
      final own = signer.pay(received.coins, {shop: 70000}, sendMax: true);
      expect(own.outputs, hasLength(1));

      await expectKept(own, received.coins, funding: received.funding);
    });

    test('받는 사람 여럿(batch)', () async {
      final received = await receive([100000]);
      final own = signer.pay(received.coins, {shop: 10000, attacker: 20000, _vault(0x66).getAddress(0): 30000});
      expect(own.outputs.length, greaterThanOrEqualTo(3));

      await expectKept(own, received.coins, funding: received.funding);
    });

    test('내 주소로 보내기(self-transfer)', () async {
      final received = await receive([100000]);
      final own = signer.pay(received.coins, {wallet.address(5): 50000});

      await expectKept(own, received.coins, funding: received.funding);
    });

    test('받는 사람 중 하나가 내 받기 주소', () async {
      final received = await receive([100000]);
      final own = signer.pay(received.coins, {shop: 20000, wallet.address(3): 30000});

      await expectKept(own, received.coins, funding: received.funding);
    });

    test('아직 확정되지 않은 내 잔돈을 쓰는 다음 거래(체인)', () async {
      final received = await receive([100000]);
      final first = signer.pay(received.coins, {shop: 30000});
      await expectKept(first, received.coins, funding: received.funding);
      final changeIndex = first.outputs.indexWhere((o) => o.getAddress() == wallet.address(0, isChange: true));
      await wallet.sync(
        [history(first, 0)],
        unspentList: wallet.unspent(first, 0, isChange: true),
        index: 0,
        isChange: true,
      );
      final change = wallet.coin(first.transactionHash, changeIndex)!;
      expect(change.status, UtxoStatus.incoming);

      final fake = withGarbageSignatures(
        signer.pay([change], {attacker: 20000}, changeIndex: 1),
        attacker,
        AddressType.p2wpkh,
      );
      wallet.publish([fake]);
      await expectDropped(
        wallet,
        fake,
        () => wallet.sync([history(first, 0), history(fake, 0)], index: 0, isChange: true),
      );
      expect(wallet.coin(first.transactionHash, changeIndex)?.status, UtxoStatus.incoming);

      final second = signer.pay([change], {_vault(0x66).getAddress(0): 20000}, changeIndex: 1);
      wallet.publish([second]);
      await wallet.sync([history(first, 0), history(second, 0)], index: 0, isChange: true);
      expect(wallet.txs.getTransactionRecord(walletId, second.transactionHash), isNotNull);
      expect(wallet.coin(first.transactionHash, changeIndex)?.spentByTransactionHash, second.transactionHash);
    });

    test('같은 시드를 쓰는 다른 기기가 만든 결제도 서명이 맞으면 넣는다', () async {
      final received = await receive([100000]);
      final otherDevice = WalletSigner(
        'other device',
        signer.item,
        signer.purpose,
        AddressType.p2wpkh,
        _vault(0x11).addSignatureToPsbt,
      );
      final tx = otherDevice.pay(received.coins, {_vault(0x66).getAddress(1): 45000}, feeRate: 7, changeIndex: 9);

      await expectKept(tx, received.coins, funding: received.funding);
    });

    group('내 입력과 남의 입력이 섞인 거래(payjoin 꼴)', () {
      late ({Transaction funding, List<UtxoState> coins}) received;
      late Transaction foreignFunding;
      late Transaction mixed;

      setUp(() async {
        received = await receive([100000]);
        expect(AddressType.getP2wpkhAddress(Codec.encodeHex(_receiveKey(ours, 0).publicKey)), wallet.address(0));
        foreignFunding = fundingTransaction([(foreign.getAddress(0), 80000)], 90);
        mixed = Transaction.withInputsAndOutputs(
          [
            TransactionInput.forPayment(received.funding.transactionHash, 0),
            TransactionInput.forPayment(foreignFunding.transactionHash, 0),
          ],
          [TransactionOutput.forPayment(170000, shop), TransactionOutput.forPayment(9000, wallet.address(1))],
          AddressType.p2wpkh,
        );
        wallet.publish([foreignFunding]);
      });

      void signOurs() =>
          signP2wpkhInput(mixed, 0, TransactionOutput.forPayment(100000, wallet.address(0)), _receiveKey(ours, 0));
      void signForeign() => signP2wpkhInput(
        mixed,
        1,
        TransactionOutput.forPayment(80000, foreign.getAddress(0)),
        _receiveKey(foreign, 0),
      );

      test('두 입력 모두 서명이 맞으면 넣는다', () async {
        signOurs();
        signForeign();

        await expectKept(mixed, received.coins, funding: received.funding);
      });

      test('남의 입력은 확인하지 않는다: 내 입력만 맞으면 넣는다', () async {
        signOurs();
        mixed.inputs[1].witnessList = ['30${'11' * 69}01', '02${'22' * 32}'];

        await expectKept(mixed, received.coins, funding: received.funding);
      });

      test('내 입력 서명이 틀리면 넣지 않는다', () async {
        signForeign();
        mixed.inputs[0].witnessList = ['30${'11' * 69}01', Codec.encodeHex(_receiveKey(ours, 0).publicKey)];
        wallet.publish([mixed]);

        await expectDropped(wallet, mixed, () => wallet.sync([history(received.funding, 100), history(mixed, 0)]));
      });
    });

    test('내 입력이 없는 받는 거래는 지금처럼 넣는다(남의 서명은 확인하지 않음)', () async {
      final foreignFunding = fundingTransaction([(foreign.getAddress(0), 80000)], 91);
      final incoming = Transaction.withInputsAndOutputs(
        [
          TransactionInput.forPayment(foreignFunding.transactionHash, 0)
            ..witnessList = ['30${'11' * 69}01', '02${'22' * 32}'],
        ],
        [
          TransactionOutput.forPayment(50000, wallet.address(0)),
          TransactionOutput.forPayment(29000, foreign.getAddress(1)),
        ],
        AddressType.p2wpkh,
      );
      wallet.publish([foreignFunding, incoming]);

      await wallet.sync([history(incoming, 0)], unspentList: wallet.unspent(incoming, 0));

      expect(wallet.txs.getTransactionRecord(walletId, incoming.transactionHash)?.blockHeight, 0);
      expect(wallet.coin(incoming.transactionHash, 0)?.status, UtxoStatus.incoming);
    });

    group('빨리 받기(CPFP)', () {
      late Transaction foreignFunding;
      late Transaction incoming;
      late Transaction child;

      setUp(() async {
        foreignFunding = fundingTransaction([(foreign.getAddress(0), 80000)], 92);
        incoming = Transaction.withInputsAndOutputs(
          [TransactionInput.forPayment(foreignFunding.transactionHash, 0)],
          [
            TransactionOutput.forPayment(50000, wallet.address(0)),
            TransactionOutput.forPayment(29900, foreign.getAddress(1)),
          ],
          AddressType.p2wpkh,
        );
        signP2wpkhInput(
          incoming,
          0,
          TransactionOutput.forPayment(80000, foreign.getAddress(0)),
          _receiveKey(foreign, 0),
        );
        wallet.publish([foreignFunding, incoming]);
        await wallet.sync([history(incoming, 0)], unspentList: wallet.unspent(incoming, 0));
        final preparer = CpfpPreparer.fromPendingTx(
          pendingTx: wallet.txs.getTransactionRecord(walletId, incoming.transactionHash)!,
          incomingUtxos: wallet.utxos.getUtxosByStatus(walletId, UtxoStatus.incoming),
          isMyAddress:
              (address, {bool isChange = false}) =>
                  wallet.addresses.containsAddress(walletId, address, isChange: isChange),
        );
        final result = CpfpBuilder(
          preparer: preparer,
          walletItemBase: signer.item,
          nextReceiveAddress: WalletAddress(wallet.address(1), '${signer.purpose}/0/1', 1, false, false, 0, 0, 0),
          minimumFeeRate: 1,
        ).build(newFeeRate: 10);
        child = signer.sign(result.transaction!);
      });

      test('받는 중 코인을 쓰는 내 자식 거래를 넣고 CPFP 기록을 남긴다', () async {
        wallet.publish([child]);

        await wallet.sync([history(incoming, 0), history(child, 0)]);

        expect(wallet.txs.getTransactionRecord(walletId, child.transactionHash), isNotNull);
        expect(wallet.coin(incoming.transactionHash, 0)?.spentByTransactionHash, child.transactionHash);
        expect(wallet.snapshot()['cpfp'], ['${incoming.transactionHash}>${child.transactionHash}']);
      });

      test('서명을 바꾼 자식 거래는 넣지 않는다', () async {
        final fake = withGarbageSignatures(child, attacker, AddressType.p2wpkh);
        wallet.publish([fake]);

        await expectDropped(wallet, fake, () => wallet.sync([history(incoming, 0), history(fake, 0)]));
        expect(wallet.coin(incoming.transactionHash, 0)?.status, UtxoStatus.incoming);
      });

      test('받는 중 거래의 원문 조회가 실패해도 내 자식 거래와 CPFP 기록을 지우지 않는다', () async {
        wallet.publish([child]);
        await wallet.sync([history(incoming, 0), history(child, 0)]);
        final other = _paidToMe(wallet, 2, 96);
        wallet.server.rawByHash.remove(incoming.transactionHash);

        await wallet.sync([history(other, 0)], unspentList: wallet.unspent(other, 0, index: 2), index: 2);

        expect(wallet.txs.getTransactionRecord(walletId, child.transactionHash)?.blockHeight, 0);
        expect(wallet.coin(incoming.transactionHash, 0)?.spentByTransactionHash, child.transactionHash);
        expect(wallet.snapshot()['cpfp'], ['${incoming.transactionHash}>${child.transactionHash}']);
      });

      /// 자식을 넣고 그 출력(받기 주소 1, 48,902 sats)을 받는 중 코인으로 둔다
      Future<({int index})> syncChild() async {
        wallet.publish([child]);
        await wallet.sync([history(incoming, 0), history(child, 0)]);
        final childOut = wallet.unspent(child, 0, index: 1);
        await wallet.sync([history(child, 0)], unspentList: childOut, index: 1);
        expect(wallet.coin(child.transactionHash, childOut.single.txPos)?.amount, 48902);
        return (index: childOut.single.txPos);
      }

      // PR #789 마지막 확인(Fable) 1: 정리 단계가 자식 원문을 기다리는 사이 다른 주소 처리가 부모를 확정으로 저장하면,
      // 확정된 부모를 대체된 거래로 보고 유효한 내 자식을 지웠음
      for (final childConfirmed in [false, true]) {
        test('정리 단계가 내 자식 원문을 기다리는 사이 다른 주소 처리가 부모를 확정으로 저장해도'
            '(자식${childConfirmed ? '도 확정' : '은 미확정'}), 자식 원문 조회가 한 번 실패한 것만으로 자식을 지우지 않는다', () async {
          await syncChild();
          final other = _paidToMe(wallet, 2, 96);
          var fired = false;
          wallet.server.transactionSource = (txHash) async {
            // 정리 단계(_cleanupOrphanedUnconfirmedTransactions)가 자식 원문을 요청할 때만 끼어든다
            if (txHash == child.transactionHash &&
                !fired &&
                StackTrace.current.toString().contains('_cleanupOrphanedUnconfirmedTransactions')) {
              fired = true;
              await wallet.syncTransactionsOnly([history(incoming, 101), history(child, childConfirmed ? 101 : 0)]);
              throw StateError('timeout $txHash');
            }
            return wallet.server.rawByHash[txHash] ?? (throw StateError('unavailable $txHash'));
          };

          await wallet.syncTransactionsOnly([history(other, 0)], index: 2);

          expect(fired, isTrue, reason: 'the cleanup step asked for the child');
          expect(wallet.txs.getTransactionRecord(walletId, incoming.transactionHash)?.blockHeight, 101);
          expect(
            wallet.txs.getTransactionRecord(walletId, child.transactionHash)?.blockHeight,
            childConfirmed ? 101 : 0,
          );
        });
      }

      // PR #789 재리뷰 1: 부모가 바뀌어 무효가 된 내 자식의 출력이 받는 중 코인으로, CPFP 기록과 함께 남았음
      for (final seenUnconfirmedFirst in [true, false]) {
        test('보낸 사람이 부모를 RBF로 바꾸면(대체 거래를 ${seenUnconfirmedFirst ? '미확정으로 먼저 봄' : '확정으로 처음 봄'}), '
            '원문을 못 받는 내 자식과 그 출력·CPFP 기록을 정리한다', () async {
          final childOut = await syncChild();
          final replacement = Transaction.withInputsAndOutputs(
            [TransactionInput.forPayment(foreignFunding.transactionHash, 0)],
            [
              TransactionOutput.forPayment(49000, wallet.address(0)),
              TransactionOutput.forPayment(29900, foreign.getAddress(1)),
            ],
            AddressType.p2wpkh,
          );
          signP2wpkhInput(replacement, 0, foreignFunding.outputs.single, _receiveKey(foreign, 0));
          wallet.publish([replacement]);
          wallet.server.rawByHash
            ..remove(incoming.transactionHash)
            ..remove(child.transactionHash);
          if (seenUnconfirmedFirst) {
            await wallet.sync([history(replacement, 0)], unspentList: wallet.unspent(replacement, 0));
          }

          await wallet.syncBatch([
            (
              history: [history(replacement, 101)],
              unspent: wallet.unspent(replacement, 101),
              index: 0,
              isChange: false,
            ),
            (history: [], unspent: [], index: 1, isChange: false),
          ]);

          expect(wallet.coin(replacement.transactionHash, 0)?.status, UtxoStatus.unspent);
          expect(wallet.txs.getTransactionRecord(walletId, child.transactionHash), isNull);
          expect(wallet.coin(child.transactionHash, childOut.index), isNull);
          expect(wallet.snapshot()['cpfp'], isEmpty);
        });
      }

      test('부모와 자식 원문을 잠깐 못 받아 자식까지 지웠어도, 둘이 확정되면 자식 기록과 출력 코인이 돌아온다', () async {
        final childOut = await syncChild();
        final rawParent = wallet.server.rawByHash.remove(incoming.transactionHash)!;
        final rawChild = wallet.server.rawByHash.remove(child.transactionHash)!;
        final other = _paidToMe(wallet, 2, 96);
        await wallet.sync([history(other, 0)], unspentList: wallet.unspent(other, 0, index: 2), index: 2);
        expect(
          wallet.txs.getTransactionRecord(walletId, child.transactionHash),
          isNull,
          reason: 'removed with the parent',
        );

        wallet.server.rawByHash[incoming.transactionHash] = rawParent;
        wallet.server.rawByHash[child.transactionHash] = rawChild;
        await wallet.sync([history(incoming, 101), history(child, 101)]);
        await wallet.sync([history(child, 101)], unspentList: wallet.unspent(child, 101, index: 1), index: 1);

        expect(wallet.txs.getTransactionRecord(walletId, child.transactionHash)?.blockHeight, 101);
        expect(wallet.coin(child.transactionHash, childOut.index)?.status, UtxoStatus.unspent);
      });
    });

    test('입력 100개짜리 내 결제를 넣는다', () async {
      final received = await receive(List.filled(100, 10000));
      final own = signer.pay(received.coins, {shop: 900000});
      expect(own.inputs, hasLength(100));

      await expectKept(own, received.coins, funding: received.funding);
    });
  });

  group('2. 받는 거래(내 입력 없음)는 지금처럼 넣는다', () {
    final ourSigner = walletSigners(0x10).first;
    late SyncedWallet wallet;

    setUp(() => wallet = SyncedWallet(realm, ourSigner.item, purpose: ourSigner.purpose));

    Future<void> expectStored(Transaction incoming) async {
      wallet.publish([incoming]);
      await wallet.sync([history(incoming, 0)], unspentList: wallet.unspent(incoming, 0));
      expect(wallet.txs.getTransactionRecord(walletId, incoming.transactionHash)?.blockHeight, 0);
      final output = wallet.unspent(incoming, 0).single;
      expect(wallet.coin(incoming.transactionHash, output.txPos)?.status, UtxoStatus.incoming);
    }

    final senders = walletSigners(0x50);
    for (final sender in [
      for (final name in ['p2wpkh 핫 지갑', 'p2wsh 2-of-3 (키 1+2)', 'p2tr 키 경로', 'p2tr 스크립트 경로'])
        senders.firstWhere((s) => s.name == name),
    ]) {
      test('보내는 쪽 ${sender.name}: 서명을 바꾼 받는 거래도 넣는다(남의 서명은 확인하지 않음)', () async {
        final funded = sender.funded([100000], 2);
        final payment = sender.pay(funded.coins, {wallet.address(0): 50000});
        wallet.publish([funded.funding]);

        await expectStored(withGarbageSignatures(payment, wallet.address(0), sender.addressType));
      });
    }

    test('보내는 쪽 이전 거래 자리에 서버가 다른 거래를 줘도 넣는다', () async {
      final sender = senders.first;
      final funded = sender.funded([100000], 2);
      wallet.server.rawByHash[funded.funding.transactionHash] = fundingTransaction([(shop, 100000)], 3).serialize();

      await expectStored(sender.pay(funded.coins, {wallet.address(0): 50000}));
    });

    test('보내는 쪽 이전 거래를 받지 못해도 넣는다', () async {
      final sender = senders.first;
      final funded = sender.funded([100000], 2);

      await expectStored(sender.pay(funded.coins, {wallet.address(0): 50000}));
    });

    test('레거시(P2PKH) 보내는 쪽의 미확정 거래도 넣는다', () async {
      final funding = fundingTransaction([('mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn', 80000)], 4);
      wallet.publish([funding]);

      await expectStored(
        Transaction.withInputsAndOutputs(
          [TransactionInput.forPayment(funding.transactionHash, 0)],
          [TransactionOutput.forPayment(50000, wallet.address(0))],
          AddressType.p2pkh,
        ),
      );
    });
  });

  group('2. 섞인 거래의 내 Taproot 입력: 서명 해시에 남의 이전 출력이 필요함', () {
    final signer = walletSigners(0x10).firstWhere((s) => s.name == 'p2tr 키 경로');
    late SyncedWallet wallet;
    late ({Transaction funding, List<UtxoState> coins}) known;
    late ({Transaction funding, List<UtxoState> coins}) unseen;
    late Transaction tx;

    setUp(() async {
      wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
      known = signer.funded([60000], 1);
      // 같은 지갑의 코인이지만 이 기기는 아직 그 주소 기록을 받지 않았다(로컬 UTXO 없음)
      unseen = signer.funded([50000], 2, indexes: [1]);
      wallet.publish([known.funding, unseen.funding]);
      await wallet.sync([history(known.funding, 100)], unspentList: wallet.unspent(known.funding, 100));
      tx = signer.pay([...known.coins, ...unseen.coins], {shop: 100000});
      wallet.publish([tx]);
      expect(wallet.coin(unseen.funding.transactionHash, 0), isNull);
    });

    Future<void> syncTx() => wallet.sync([history(known.funding, 100), history(tx, 0)]);

    test('남의 이전 거래를 받아(거래 번호 확인) 내 입력을 확인하고 넣는다', () async {
      await syncTx();

      expect(wallet.txs.getTransactionRecord(walletId, tx.transactionHash), isNotNull);
    });

    test('남의 이전 거래 자리에 다른 거래를 주면 넣지 않는다', () async {
      wallet.server.rawByHash[unseen.funding.transactionHash] = fundingTransaction([(shop, 50000)], 3).serialize();

      await expectDropped(wallet, tx, syncTx);
    });

    test('남의 이전 거래를 받지 못하면 지금은 넣지 않고 다음 동기화에서 넣는다', () async {
      wallet.server.rawByHash.remove(unseen.funding.transactionHash);
      await expectDropped(wallet, tx, syncTx);

      wallet.publish([unseen.funding]);
      await syncTx();

      expect(wallet.txs.getTransactionRecord(walletId, tx.transactionHash), isNotNull);
    });
  });

  group('3. 서버 동작 (p2wpkh 핫 지갑)', () {
    final signer = walletSigners(0x10).first;
    late SyncedWallet wallet;
    late Transaction deposit;
    late UtxoState coin;
    late Transaction own;

    setUp(() async {
      wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
      final funded = signer.funded([100000], 1);
      deposit = funded.funding;
      coin = funded.coins.single;
      own = signer.pay([coin], {shop: 30000});
      wallet.publish([deposit, own]);
      await wallet.sync([history(deposit, 100)], unspentList: wallet.unspent(deposit, 100));
      await wallet.sync([history(deposit, 100), history(own, 0)]);
    });

    test('바꿔치기: 기록에서 내 결제를 빼고 같은 코인을 쓰는 가짜를 보여 줘도, 가짜는 넣지 않고 내 결제는 그대로 보인다', () async {
      final fake = withGarbageSignatures(own, attacker, AddressType.p2wpkh);
      wallet.publish([fake]);

      await expectDropped(wallet, fake, () => wallet.sync([history(deposit, 100), history(fake, 0)]));

      expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash)?.blockHeight, 0);
      expect(wallet.coin(coin.transactionHash, 0)?.spentByTransactionHash, own.transactionHash);
      expect(wallet.txs.getRbfHistoryList(walletId, own.transactionHash), isEmpty);
    });

    test('해시 유형만 SIGHASH_NONE으로 바꾼 서명은 그 유형으로 계산하면 맞지 않는다(BIP143)', () {
      final forged = withSighashNone(own, AddressType.p2wpkh);
      final input = forged.inputs.first;
      String reversed(String hex) => Codec.encodeHex(Codec.decodeHex(hex).reversed.toList());
      String le(int value, int bytes) => Codec.encodeHex(Converter.intToLittleEndianBytes(value, bytes));
      final outpoint = '${reversed(input.transactionHash)}${le(input.index, 4)}';
      // SIGHASH_NONE: hashSequence·hashOutputs는 0, 마지막 해시 유형은 2
      final preimage =
          '${forged.version}${Hash.sha256fromHex(Hash.sha256fromHex(outpoint))}${'00' * 32}$outpoint'
          '1976a914${Codec.encodeHex(deposit.outputs.first.scriptPubKey.commands[1])}88ac'
          '${le(deposit.outputs.first.amount, 8)}${le(input.sequence, 4)}${'00' * 32}${forged.lockTime}02000000';
      final digest = Codec.decodeHex(Hash.sha256fromHex(Hash.sha256fromHex(preimage)));

      expect(
        Ecc.verifyEcdsa(
          digest,
          Codec.decodeHex(input.witnessList[1]),
          Converter.derToRawSignature(Codec.decodeHex(input.witnessList[0])),
        ),
        isFalse,
      );
    });

    test('같은 실제 거래를 다시 보내 줘도(앱 재시작) 기록이 겹치지 않는다', () async {
      final before = wallet.snapshot();
      wallet.callbacks = ScriptCallbackService();

      await wallet.sync([history(deposit, 100), history(own, 0)]);

      expect(wallet.snapshot(), before);
    });

    test('같은 거래 번호에 서명을 뺀 원문을 다시 보내 줘도(앱 재시작) 저장된 내 결제와 코인은 그대로다', () async {
      final stripped = Transaction.parse(own.serialize());
      for (final input in stripped.inputs) {
        input.witnessList = [];
      }
      expect(stripped.transactionHash, own.transactionHash);
      wallet.server.rawByHash[own.transactionHash] = stripped.serialize();
      final before = wallet.snapshot();
      wallet.callbacks = ScriptCallbackService();

      await wallet.sync([history(deposit, 100), history(own, 0)]);

      expect(wallet.snapshot(), before);
    });

    test('정리 단계에서 서버가 내 결제 번호에 다른 거래를 주면(B의 FormatException) 내 결제를 지우지 않는다', () async {
      final foreign = _vault(0x55);
      final foreignFunding = fundingTransaction([(foreign.getAddress(0), 80000)], 93);
      final incoming = Transaction.withInputsAndOutputs(
        [TransactionInput.forPayment(foreignFunding.transactionHash, 0)],
        [
          TransactionOutput.forPayment(40000, wallet.address(0)),
          TransactionOutput.forPayment(39000, foreign.getAddress(1)),
        ],
        AddressType.p2wpkh,
      );
      signP2wpkhInput(incoming, 0, TransactionOutput.forPayment(80000, foreign.getAddress(0)), _receiveKey(foreign, 0));
      wallet.publish([foreignFunding, incoming]);
      wallet.server.transactionSource = (txHash) async {
        if (txHash == own.transactionHash) throw FormatException('Received a different transaction for $txHash');
        return wallet.server.rawByHash[txHash] ?? (throw StateError('unavailable $txHash'));
      };

      await wallet.sync([history(deposit, 100), history(own, 0), history(incoming, 0)]);

      expect(wallet.txs.getTransactionRecord(walletId, incoming.transactionHash), isNotNull);
      expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash)?.blockHeight, 0);
      expect(wallet.coin(coin.transactionHash, 0)?.spentByTransactionHash, own.transactionHash);
    });

    /// 받기 주소 1의 받는 중 거래 하나를 넣고, 그 원문 조회를 [error]로 실패시킨 채 받기 주소 2에 새 받는 거래를 동기화한다
    Future<Transaction> receiveThenFailFetch(Object Function(String txHash) error) async {
      final first = _paidToMe(wallet, 1, 94);
      final second = _paidToMe(wallet, 2, 95);
      await wallet.sync([history(first, 0)], unspentList: wallet.unspent(first, 0, index: 1), index: 1);
      expect(wallet.coin(first.transactionHash, 0)?.status, UtxoStatus.incoming);
      wallet.server.transactionSource = (txHash) async {
        if (txHash == first.transactionHash) throw error(txHash);
        return wallet.server.rawByHash[txHash] ?? (throw StateError('unavailable $txHash'));
      };
      await wallet.sync([history(second, 0)], unspentList: wallet.unspent(second, 0, index: 2), index: 2);
      expect(wallet.coin(second.transactionHash, 0)?.status, UtxoStatus.incoming);
      wallet.server.transactionSource = null;
      return first;
    }

    // PR #789 2라운드: getTransaction이 다른 거래에 FormatException을 던지면서, 받는 RBF 확인이 이를 "대체됨"으로 봤음
    test('받는 RBF 확인에서 서버가 받는 중 거래 번호에 다른 거래를 주면(FormatException) 그 받는 중 코인을 지우지 않는다', () async {
      final first = await receiveThenFailFetch(
        (txHash) => FormatException('Received a different transaction for $txHash'),
      );

      expect(wallet.coin(first.transactionHash, 0)?.status, UtxoStatus.incoming);
      expect(wallet.txs.getTransactionRecord(walletId, first.transactionHash)?.blockHeight, 0);
      await wallet.sync([history(first, 101)], unspentList: wallet.unspent(first, 101, index: 1), index: 1);
      expect(wallet.coin(first.transactionHash, 0)?.status, UtxoStatus.unspent);
    });

    // 이 PR 전과 같은 동작(별도 이슈): 남이 보낸 거래는 원문 조회 실패를 대체로 보고, 지운 것으로 표시된 코인은 다시 넣지 않는다
    test('받는 중 거래의 원문 조회가 일반 오류로 실패하면 지금처럼 그 받는 중 코인을 지우고, 확정 뒤에도 코인은 돌아오지 않는다', () async {
      final first = await receiveThenFailFetch((txHash) => StateError('unavailable $txHash'));

      expect(wallet.coin(first.transactionHash, 0), isNull);
      expect(wallet.txs.getTransactionRecord(walletId, first.transactionHash), isNull);
      await wallet.sync([history(first, 101)], unspentList: wallet.unspent(first, 101, index: 1), index: 1);
      expect(wallet.txs.getTransactionRecord(walletId, first.transactionHash)?.blockHeight, 101);
      expect(wallet.coin(first.transactionHash, 0), isNull);
    });

    test('보낸 쪽이 RBF로 바꾼 받는 거래는, 이전 거래 원문을 못 받으면 대체됨으로 보고 새 거래만 받는 중으로 남긴다', () async {
      final first = _paidToMe(wallet, 1, 99);
      final replacement = _paidToMe(wallet, 1, 99, amount: 39000);
      await wallet.sync([history(first, 0)], unspentList: wallet.unspent(first, 0, index: 1), index: 1);
      wallet.server.rawByHash.remove(first.transactionHash);

      await wallet.sync([history(replacement, 0)], unspentList: wallet.unspent(replacement, 0, index: 1), index: 1);

      expect(wallet.txs.getTransactionRecord(walletId, first.transactionHash), isNull);
      expect(wallet.coin(first.transactionHash, 0), isNull);
      expect(wallet.coin(replacement.transactionHash, 0)?.status, UtxoStatus.incoming);
      await wallet.sync([history(replacement, 101)], unspentList: wallet.unspent(replacement, 101, index: 1), index: 1);
      expect(wallet.coin(replacement.transactionHash, 0)?.status, UtxoStatus.unspent);
    });

    test('내 결제 A의 원문 조회가 실패해도 A에서 나온 내 잔돈 코인을 지우지 않고, A가 확정되면 그대로 쓸 수 있다', () async {
      final changeUnspent = wallet.unspent(own, 0, isChange: true);
      final changeIndex = changeUnspent.single.txPos;
      await wallet.sync([history(own, 0)], unspentList: changeUnspent, isChange: true);
      expect(wallet.coin(own.transactionHash, changeIndex)?.status, UtxoStatus.incoming);
      final other = _paidToMe(wallet, 1, 97);
      wallet.server.rawByHash.remove(own.transactionHash);

      await wallet.sync([history(other, 0)], unspentList: wallet.unspent(other, 0, index: 1), index: 1);

      expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash)?.blockHeight, 0);
      expect(wallet.coin(own.transactionHash, changeIndex)?.status, UtxoStatus.incoming);
      wallet.publish([own]);
      await wallet.sync([history(deposit, 100), history(own, 101)]);
      await wallet.sync([history(own, 101)], unspentList: wallet.unspent(own, 101, isChange: true), isChange: true);
      expect(wallet.coin(own.transactionHash, changeIndex)?.status, UtxoStatus.unspent);
    });

    test('가짜 B를 넣지 않은 회차에 A 원문 조회가 실패해도 A를 지우지 않는다', () async {
      final fake = withGarbageSignatures(own, attacker, AddressType.p2wpkh);
      wallet.publish([fake]);
      wallet.server.rawByHash.remove(own.transactionHash);

      await wallet.sync([history(deposit, 100), history(fake, 0)]);

      expect(wallet.leavesNoTrace(fake.transactionHash), isTrue);
      expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash)?.blockHeight, 0);
      expect(wallet.coin(coin.transactionHash, 0)?.spentByTransactionHash, own.transactionHash);
    });

    test('B 없이 다른 주소에 정상 입금만 와도 A 원문 조회가 실패하면 A를 지우지 않는다. 대체 없이 빠진 A는 보내는 중으로 남는다', () async {
      final other = _paidToMe(wallet, 1, 97);
      wallet.server.rawByHash.remove(own.transactionHash);

      await wallet.sync([history(other, 0)], unspentList: wallet.unspent(other, 0, index: 1), index: 1);

      expect(wallet.txs.getTransactionRecord(walletId, other.transactionHash), isNotNull);
      expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash)?.blockHeight, 0);
      expect(wallet.coin(coin.transactionHash, 0)?.status, UtxoStatus.outgoing);
      expect(wallet.coin(coin.transactionHash, 0)?.spentByTransactionHash, own.transactionHash);
    });

    test('B를 넣지 않은 다음 회차(B 없음, 새 입금)에도 A를 지우지 않고, A 원문이 다시 오면 그대로다', () async {
      final fake = withGarbageSignatures(own, attacker, AddressType.p2wpkh);
      wallet.publish([fake]);
      wallet.server.rawByHash.remove(own.transactionHash);
      await wallet.sync([history(deposit, 100), history(fake, 0)]);
      final next = _paidToMe(wallet, 0, 98);

      await wallet.sync([history(deposit, 100), history(next, 0)], unspentList: wallet.unspent(next, 0));
      expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash)?.blockHeight, 0);

      wallet.publish([own]);
      await wallet.sync([
        history(deposit, 100),
        history(own, 0),
        history(next, 0),
      ], unspentList: wallet.unspent(next, 0));

      expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash)?.blockHeight, 0);
      expect(wallet.coin(coin.transactionHash, 0)?.spentByTransactionHash, own.transactionHash);
    });

    test('정상 RBF: 내가 수수료를 올린 대체 거래가 오면, 원문을 못 받는 A도 대체됨으로 표시한다', () async {
      final replacement = signer.pay([coin], {shop: 30000}, feeRate: 10);
      wallet.publish([replacement]);
      wallet.server.rawByHash.remove(own.transactionHash);

      await wallet.sync([history(deposit, 100), history(replacement, 0)]);

      expect(wallet.txs.getTransactionRecord(walletId, replacement.transactionHash)?.blockHeight, 0);
      expect(wallet.coin(coin.transactionHash, 0)?.spentByTransactionHash, replacement.transactionHash);
      expect(wallet.snapshot()['rbf'], contains('${own.transactionHash}>${replacement.transactionHash}'));
      expect(
        wallet.txs.getUnconfirmedTransactionRecordList(walletId, excludeReplaced: true).map((r) => r.transactionHash),
        [replacement.transactionHash],
      );
    });

    test('A가 쓰던 코인을 다른 거래가 확정으로 쓰면, A 원문을 못 받아도 A를 지운다', () async {
      final conflict = signer.pay([coin], {shop: 20000}, feeRate: 5);
      wallet.publish([conflict]);
      wallet.server.rawByHash.remove(own.transactionHash);

      await wallet.sync([history(deposit, 100), history(conflict, 101)]);

      expect(wallet.txs.getTransactionRecord(walletId, conflict.transactionHash)?.blockHeight, 101);
      expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash), isNull);
    });

    /// A(내 결제)의 잔돈을 쓰는 내 다음 결제를 만들어 넣고, 그 잔돈 출력(받는 중)을 돌려준다
    Future<({Transaction tx, int changeIndex})> spendChangeOf(
      Transaction parent,
      int parentChange,
      int childChange,
    ) async {
      final parentOut = wallet.unspent(parent, 0, index: parentChange, isChange: true);
      final child = signer.pay(
        [wallet.coin(parent.transactionHash, parentOut.single.txPos)!],
        {shop: 20000},
        changeIndex: childChange,
      );
      wallet.publish([child]);
      await wallet.sync([history(parent, 0), history(child, 0)], index: parentChange, isChange: true);
      final childOut = wallet.unspent(child, 0, index: childChange, isChange: true);
      await wallet.sync([history(child, 0)], unspentList: childOut, index: childChange, isChange: true);
      expect(wallet.coin(child.transactionHash, childOut.single.txPos)?.status, UtxoStatus.incoming, reason: 'setup');
      return (tx: child, changeIndex: childOut.single.txPos);
    }

    Future<void> syncOwnChange() =>
        wallet.sync([history(own, 0)], unspentList: wallet.unspent(own, 0, isChange: true), isChange: true);

    // PR #789 재리뷰 1·푸시 전 리뷰 2: 무효가 된 A의 잔돈을 쓰던 내 다음 결제 C가 받는 중 출력과 함께 남았음.
    // A를 대체한 내 거래 B를 미확정으로 먼저 보면, A는 대체됨으로 남고 A의 출력은 이미 지운 것으로 표시된다
    for (final (pendingFirst, viaBatch) in [(false, false), (true, false), (true, true)]) {
      test('A의 잔돈을 쓰는 내 다음 결제 C가 있을 때 A의 입력을 쓰는 B가 '
          '${pendingFirst ? '미확정으로 먼저(${viaBatch ? '전체 동기화' : '주소 이벤트'}) 오면' : '확정으로 처음 오면'}, '
          '원문을 못 받는 C와 그 출력을 정리한다', () async {
        await syncOwnChange();
        final next = await spendChangeOf(own, 0, 1);
        expect(wallet.coin(next.tx.transactionHash, next.changeIndex)?.amount, 49436);
        final conflict = signer.pay([coin], {shop: 25000}, feeRate: 5, changeIndex: 2);
        wallet.publish([conflict]);
        wallet.server.rawByHash
          ..remove(own.transactionHash)
          ..remove(next.tx.transactionHash);

        if (pendingFirst && viaBatch) {
          await wallet.syncBatch([
            (history: [history(deposit, 100), history(conflict, 0)], unspent: [], index: 0, isChange: false),
            (history: [], unspent: [], index: 0, isChange: true),
            (history: [], unspent: [], index: 1, isChange: true),
          ]);
        } else if (pendingFirst) {
          await wallet.sync([history(deposit, 100), history(conflict, 0)]);
        }
        if (pendingFirst) {
          expect(
            wallet.txs
                .getUnconfirmedTransactionRecordList(walletId, excludeReplaced: true)
                .map((r) => r.transactionHash),
            [conflict.transactionHash],
            reason: 'A is kept as replaced, C is gone',
          );
          expect(wallet.snapshot()['rbf'], contains('${own.transactionHash}>${conflict.transactionHash}'));
          expect(wallet.coin(next.tx.transactionHash, next.changeIndex), isNull);
        }
        await wallet.syncBatch([
          (history: [history(deposit, 100), history(conflict, 101)], unspent: [], index: 0, isChange: false),
          (history: [], unspent: [], index: 0, isChange: true),
          (history: [], unspent: [], index: 1, isChange: true),
          (
            history: [history(conflict, 101)],
            unspent: wallet.unspent(conflict, 101, index: 2, isChange: true),
            index: 2,
            isChange: true,
          ),
        ]);

        if (!pendingFirst) {
          expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash), isNull);
        }
        expect(wallet.txs.getTransactionRecord(walletId, next.tx.transactionHash), isNull);
        expect(wallet.coin(next.tx.transactionHash, next.changeIndex), isNull);
      });
    }

    test('A를 대체한 내 거래를 미확정으로 먼저 보면, A 잔돈을 쓰는 C와 C 잔돈을 쓰는 D까지 원문을 못 받으면 함께 정리한다', () async {
      await syncOwnChange();
      final next = await spendChangeOf(own, 0, 1);
      final last = await spendChangeOf(next.tx, 1, 3);
      final conflict = signer.pay([coin], {shop: 25000}, feeRate: 5, changeIndex: 2);
      wallet.publish([conflict]);
      for (final tx in [own, next.tx, last.tx]) {
        wallet.server.rawByHash.remove(tx.transactionHash);
      }

      await wallet.sync([history(deposit, 100), history(conflict, 0)]);

      for (final child in [next, last]) {
        expect(wallet.txs.getTransactionRecord(walletId, child.tx.transactionHash), isNull);
        expect(wallet.coin(child.tx.transactionHash, child.changeIndex), isNull);
      }
      expect(wallet.snapshot()['cpfp'], isEmpty);
      expect(wallet.snapshot()['rbf'], contains('${own.transactionHash}>${conflict.transactionHash}'));
    });

    // PR #789 마지막 확인(GPT) 1: 내 대체 거래 B를 본 뒤 B가 아니라 원래 A가 확정되면, A의 확정 기록은 정리 단계 뒤에 저장되므로
    // 정리 단계는 A를 아직 '대체됨'으로 보고, 그 회차에 원문을 못 받은 A의 후속 결제 C를 지웠음. 다시 켠 경우는 DB를 다시 열고
    // 처리 기록을 비운 뒤 받기 주소만 동기화한다(처리 기록이 비면 잔돈 주소 동기화가 원문 없는 C를 다시 받으려다 실패한다)
    for (final restart in [false, true]) {
      test('내 대체 거래를 본 뒤 원래 A가 확정되면(${restart ? '앱을 다시 켠 뒤' : '같은 세션'}), 그 회차에 원문을 못 받은 A의 후속 결제 C를 지우지 않는다', () async {
        await syncOwnChange();
        final next = await spendChangeOf(own, 0, 1);
        final replacement = signer.pay([coin], {shop: 30000}, feeRate: 10, changeIndex: 2);
        wallet.publish([replacement]);
        wallet.server.rawByHash.remove(own.transactionHash);
        await wallet.sync([history(deposit, 100), history(replacement, 0)]);
        expect(
          wallet.txs.getTransactionRecord(walletId, next.tx.transactionHash),
          isNotNull,
          reason: 'C kept (raw still served)',
        );
        wallet.server.rawByHash.remove(replacement.transactionHash);
        if (restart) {
          wallet.realm.reopen();
          wallet.callbacks = ScriptCallbackService();
        }
        wallet.publish([own]);
        wallet.server.rawByHash.remove(next.tx.transactionHash);

        await wallet.sync([history(deposit, 100), history(own, 101)]);
        if (!restart) {
          await wallet.syncBatch([
            (history: [history(own, 101), history(next.tx, 0)], unspent: [], index: 0, isChange: true),
            (
              history: [history(next.tx, 0)],
              unspent: wallet.unspent(next.tx, 0, index: 1, isChange: true),
              index: 1,
              isChange: true,
            ),
          ]);
        }

        expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash)?.blockHeight, 101);
        expect(wallet.txs.getTransactionRecord(walletId, next.tx.transactionHash)?.blockHeight, 0);
        expect(wallet.coin(next.tx.transactionHash, next.changeIndex)?.status, UtxoStatus.incoming);
      });
    }
  });

  group('3. 서버 동작: 연결 끊김 (p2wpkh 핫 지갑)', () {
    final signer = walletSigners(0x10).first;

    test('내 결제를 받는 중에 연결이 끊기면 아무것도 바꾸지 않고, 다시 연결되면 넣는다', () async {
      final wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
      final funded = signer.funded([100000], 1);
      final own = signer.pay(funded.coins, {shop: 30000});
      wallet.publish([funded.funding, own]);
      await wallet.sync([history(funded.funding, 100)], unspentList: wallet.unspent(funded.funding, 100));
      final before = wallet.snapshot();
      wallet.server.transactionSource = (txHash) async {
        if (txHash == own.transactionHash) throw const SocketException('Connection reset by peer');
        return wallet.server.rawByHash[txHash]!;
      };

      await expectLater(wallet.sync([history(funded.funding, 100), history(own, 0)]), throwsA(isA<SocketException>()));
      expect(wallet.snapshot(), before);

      wallet.server.transactionSource = null;
      await wallet.sync([history(funded.funding, 100), history(own, 0)]);
      expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash), isNotNull);
    });
  });

  // PR #789 리뷰 2: 넣지 않은 거래의 출력이 서버 listunspent에 있으면 기록 없는 받는 중 코인으로 저장됐음
  group('3. 서버 동작: 넣지 않은 거래의 출력이 listunspent에 있음 (p2wpkh 핫 지갑)', () {
    final signer = walletSigners(0x10).first;
    late SyncedWallet wallet;
    late Transaction deposit;
    late UtxoState coin;

    setUp(() async {
      wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
      final funded = signer.funded([100000], 1);
      deposit = funded.funding;
      coin = funded.coins.single;
      wallet.publish([deposit]);
      await wallet.sync([history(deposit, 100)], unspentList: wallet.unspent(deposit, 100));
    });

    /// 내 코인을 [남 60,000 + 내 잔돈 주소 39,000]으로 쓰는 서명 틀린 가짜
    Transaction fakeWithMyChange() {
      final fake = withGarbageSignatures(signer.pay([coin], {shop: 30000}), attacker, AddressType.p2wpkh);
      fake.outputs
        ..clear()
        ..addAll([
          TransactionOutput.forPayment(60000, attacker),
          TransactionOutput.forPayment(39000, wallet.address(0, isChange: true)),
        ]);
      wallet.publish([fake]);
      return fake;
    }

    test('가짜가 내 잔돈 주소로 보내는 출력은 받는 중 코인으로 넣지 않는다(앱을 다시 켜도)', () async {
      final fake = fakeWithMyChange();
      final changeUnspent = wallet.unspent(fake, 0, isChange: true);
      expect(changeUnspent.single.value, 39000);

      await wallet.sync([history(deposit, 100), history(fake, 0)]);
      await wallet.sync([history(fake, 0)], unspentList: changeUnspent, isChange: true);
      expect(wallet.leavesNoTrace(fake.transactionHash), isTrue);

      wallet.callbacks = ScriptCallbackService();
      await wallet.sync([history(fake, 0)], unspentList: changeUnspent, isChange: true);

      expect(wallet.leavesNoTrace(fake.transactionHash), isTrue);
      expect(wallet.coin(coin.transactionHash, 0)?.status, UtxoStatus.unspent);
    });

    test('가짜가 출력을 내 받기 주소로 바꿔도 그 출력은 받는 중 코인으로 넣지 않는다', () async {
      final fake = withGarbageSignatures(signer.pay([coin], {shop: 30000}), wallet.address(0), AddressType.p2wpkh);
      wallet.publish([fake]);

      await wallet.sync([history(deposit, 100), history(fake, 0)], unspentList: wallet.unspent(fake, 0));

      expect(wallet.leavesNoTrace(fake.transactionHash), isTrue);
      expect(wallet.coin(coin.transactionHash, 0)?.status, UtxoStatus.unspent);
    });

    test('정상 받는 거래의 미확정 출력은 같은 동기화에서 받는 중 코인으로 넣는다', () async {
      final incoming = _paidToMe(wallet, 1, 93);

      await wallet.sync([history(incoming, 0)], unspentList: wallet.unspent(incoming, 0, index: 1), index: 1);

      expect(wallet.txs.getTransactionRecord(walletId, incoming.transactionHash), isNotNull);
      expect(wallet.coin(incoming.transactionHash, 0)?.status, UtxoStatus.incoming);
    });

    test('증인만 바꿔 번호가 같은 원문이 다시 와도(앱 재시작) 저장된 내 결제의 잔돈 코인은 그대로다', () async {
      final own = signer.pay([coin], {shop: 30000});
      wallet.publish([own]);
      final changeUnspent = wallet.unspent(own, 0, isChange: true);
      await wallet.sync([history(deposit, 100), history(own, 0)]);
      await wallet.sync([history(own, 0)], unspentList: changeUnspent, isChange: true);
      final change = wallet.coin(own.transactionHash, changeUnspent.single.txPos);
      expect(change?.status, UtxoStatus.incoming);
      final stripped = Transaction.parse(own.serialize());
      for (final input in stripped.inputs) {
        input.witnessList = [];
      }
      expect(stripped.transactionHash, own.transactionHash);
      wallet.server.rawByHash[own.transactionHash] = stripped.serialize();
      wallet.callbacks = ScriptCallbackService();

      await wallet.sync([history(own, 0)], unspentList: changeUnspent, isChange: true);

      final after = wallet.coin(own.transactionHash, changeUnspent.single.txPos);
      expect(after?.status, UtxoStatus.incoming);
      expect(after?.amount, change!.amount);
    });

    test('기록이 없는 확정 출력은 지금처럼 코인으로 넣는다(대량 스캔 복구)', () async {
      final unseen = fundingTransaction([(wallet.address(2), 50000)], 95);

      await wallet.sync([], unspentList: wallet.unspent(unseen, 90, index: 2), index: 2);

      expect(wallet.txs.getTransactionRecord(walletId, unseen.transactionHash), isNull);
      expect(wallet.coin(unseen.transactionHash, 0)?.status, UtxoStatus.unspent);
    });

    test('전체 동기화(거래 → UTXO → 정리)에서도 가짜 출력은 넣지 않고 정상 출력은 넣는다', () async {
      final fake = fakeWithMyChange();
      final incoming = _paidToMe(wallet, 1, 93);

      await wallet.syncBatch([
        (history: [history(deposit, 100), history(fake, 0)], unspent: [], index: 0, isChange: false),
        (history: [history(fake, 0)], unspent: wallet.unspent(fake, 0, isChange: true), index: 0, isChange: true),
        (history: [history(incoming, 0)], unspent: wallet.unspent(incoming, 0, index: 1), index: 1, isChange: false),
      ]);

      expect(wallet.leavesNoTrace(fake.transactionHash), isTrue);
      expect(wallet.coin(incoming.transactionHash, 0)?.status, UtxoStatus.incoming);
      expect(wallet.coin(coin.transactionHash, 0)?.status, UtxoStatus.unspent);
    });

    test('전체 동기화에서 증인을 뺀 같은 번호의 원문을 먼저 받아도, 나중에 받은 서명 맞는 결제의 잔돈은 확정 뒤까지 코인으로 들어온다', () async {
      final own = signer.pay([coin], {shop: 30000});
      final stripped = Transaction.parse(own.serialize());
      for (final input in stripped.inputs) {
        input.witnessList = [];
      }
      expect(stripped.transactionHash, own.transactionHash);
      wallet.server.rawByHash[own.transactionHash] = stripped.serialize();
      final changeUnspent = wallet.unspent(own, 0, isChange: true);
      final changeIndex = changeUnspent.single.txPos;

      // 전체 동기화는 끝에서 기록 없는 받는 중 코인을 지운 것으로 표시하고, 지운 코인은 다시 넣지 않는다
      await wallet.syncBatch([
        (history: [history(deposit, 100), history(own, 0)], unspent: [], index: 0, isChange: false),
        (history: [history(own, 0)], unspent: changeUnspent, index: 0, isChange: true),
      ]);
      expect(wallet.txs.getTransactionRecord(walletId, own.transactionHash), isNull);

      wallet.server.rawByHash[own.transactionHash] = own.serialize();
      wallet.callbacks = ScriptCallbackService();
      await wallet.sync([history(deposit, 100), history(own, 0)]);
      await wallet.sync([history(own, 0)], unspentList: changeUnspent, isChange: true);
      expect(wallet.coin(own.transactionHash, changeIndex)?.status, UtxoStatus.incoming);

      await wallet.sync([history(deposit, 100), history(own, 101)]);
      await wallet.sync([history(own, 101)], unspentList: wallet.unspent(own, 101, isChange: true), isChange: true);
      expect(wallet.coin(own.transactionHash, changeIndex)?.status, UtxoStatus.unspent);
    });

    test('정상 받는 거래의 원문 조회가 실패한 회차 뒤 다시 동기화하면 받는 중 코인으로 넣는다', () async {
      final incoming = _paidToMe(wallet, 1, 93);
      final unspent = wallet.unspent(incoming, 0, index: 1);
      wallet.server.transactionSource = (txHash) async {
        if (txHash == incoming.transactionHash) throw const SocketException('Connection reset by peer');
        return wallet.server.rawByHash[txHash]!;
      };

      await expectLater(
        wallet.sync([history(incoming, 0)], unspentList: unspent, index: 1),
        throwsA(isA<SocketException>()),
      );
      expect(wallet.leavesNoTrace(incoming.transactionHash), isTrue);

      wallet.server.transactionSource = null;
      await wallet.sync([history(incoming, 0)], unspentList: unspent, index: 1);

      expect(wallet.coin(incoming.transactionHash, 0)?.status, UtxoStatus.incoming);
    });
  });

  group('N1: 코인 목록에 아직 없는 내 미확정 잔돈을 쓰는 거래', () {
    final signer = walletSigners(0x10).first;
    late SyncedWallet wallet;
    late Transaction deposit;
    // 이 기기가 아직 모르는 내 결제(같은 시드 다른 기기나 공동 서명자가 보냄)
    late Transaction first;
    late int changeIndex;

    setUp(() async {
      wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
      final funded = signer.funded([100000], 1);
      deposit = funded.funding;
      first = signer.pay(funded.coins, {shop: 30000});
      changeIndex = first.outputs.indexWhere((o) => o.getAddress() == wallet.address(0, isChange: true));
      wallet.publish([deposit, first]);
      await wallet.sync([history(deposit, 100)], unspentList: wallet.unspent(deposit, 100));
    });

    UtxoState change() => UtxoState(
      transactionHash: first.transactionHash,
      index: changeIndex,
      amount: first.outputs[changeIndex].amount,
      derivationPath: signer.path(0, isChange: true),
      blockHeight: 0,
      to: wallet.address(0, isChange: true),
      timestamp: DateTime(2026, 11, 11),
    );

    Transaction fakeChild() =>
        withGarbageSignatures(signer.pay([change()], {attacker: 20000}, changeIndex: 1), attacker, AddressType.p2wpkh);

    Future<void> syncChange(List<Transaction> pending) =>
        wallet.sync([for (final tx in pending) history(tx, 0)], index: 0, isChange: true);

    test('같은 동기화에서 처음 받은 내 결제의 잔돈을 쓰는 가짜는 넣지 않고, 내 결제는 넣는다', () async {
      final fake = fakeChild();
      wallet.publish([fake]);

      await syncChange([first, fake]);

      expect(wallet.txs.getTransactionRecord(walletId, first.transactionHash)?.blockHeight, 0);
      expect(wallet.leavesNoTrace(fake.transactionHash), isTrue);
    });

    test('먼저 저장된 내 결제의 잔돈(아직 코인 목록에 없음)을 쓰는 가짜는 넣지 않는다', () async {
      await wallet.sync([history(deposit, 100), history(first, 0)]);
      expect(wallet.coin(first.transactionHash, changeIndex), isNull);
      final fake = fakeChild();
      wallet.publish([fake]);

      await expectDropped(wallet, fake, () => syncChange([first, fake]));
    });

    test('같은 동기화에서 처음 받은 내 결제의 잔돈을 쓰는 내 다음 결제는 넣는다', () async {
      final second = signer.pay([change()], {_vault(0x66).getAddress(0): 20000}, changeIndex: 1);
      wallet.publish([second]);

      await syncChange([first, second]);

      expect(wallet.txs.getTransactionRecord(walletId, first.transactionHash), isNotNull);
      expect(wallet.txs.getTransactionRecord(walletId, second.transactionHash), isNotNull);
    });

    // N1′: 내 결제가 이 주소의 묶음에도 코인 목록에도 없을 때. 거래 기록은 이전 거래를 받아 "보냄"으로 세므로, 같은 이전 거래로 확인한다
    Transaction fakeWithDustToReceive() {
      final fake = Transaction.withInputsAndOutputs(
        [TransactionInput.forPayment(first.transactionHash, changeIndex)],
        [
          TransactionOutput.forPayment(first.outputs[changeIndex].amount - 1546, attacker),
          TransactionOutput.forPayment(546, wallet.address(1)),
        ],
        AddressType.p2wpkh,
      );
      fake.inputs[0].witnessList = ['30${'11' * 69}01', '02${'22' * 32}'];
      return fake;
    }

    test('서버가 잔돈 주소 기록에서 내 결제를 빼고 가짜만 보여 줘도, 내 결제를 받아 내 입력으로 보고 넣지 않는다', () async {
      final fake = fakeChild();
      wallet.publish([fake]);

      await expectDropped(wallet, fake, () => syncChange([fake]));
    });

    test('가짜가 내 받기 주소로도 보내고 그 주소가 잔돈 주소보다 먼저 동기화돼도 넣지 않는다', () async {
      final fake = fakeWithDustToReceive();
      wallet.publish([fake]);

      await expectDropped(wallet, fake, () => wallet.sync([history(fake, 0)], index: 1));
      await syncChange([first, fake]);

      expect(wallet.txs.getTransactionRecord(walletId, first.transactionHash)?.transactionType, TransactionType.sent);
      expect(wallet.leavesNoTrace(fake.transactionHash), isTrue);
    });

    test('(대조) 잔돈 주소가 먼저 동기화돼도 그 가짜는 넣지 않는다', () async {
      final fake = fakeWithDustToReceive();
      wallet.publish([fake]);

      await syncChange([first, fake]);
      await expectDropped(wallet, fake, () => wallet.sync([history(fake, 0)], index: 1));
    });
  });

  group('N3: 3.1.4·3.1.5가 표준이 아닌 출력을 자리 없이 저장한 기록', () {
    test('그 거래에서 남의 출력을 쓰는 정상 받는 거래는 밀린 출력 자리와 상관없이 넣는다', () async {
      final signer = walletSigners(0x10).first;
      final wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
      final sender = _vault(0x55);
      final senderKey = _receiveKey(sender, 0);
      final senderFunding = fundingTransaction([(sender.getAddress(0), 100000)], 7);
      // 예전에 확정된 채로 받은 거래: [OP_RETURN, 보내는 사람 잔돈, 내 받기 주소 0]
      final old = Transaction.withInputsAndOutputs(
        [TransactionInput.forPayment(senderFunding.transactionHash, 0)],
        [
          TransactionOutput.parse('0000000000000000066a04deadbeef'),
          TransactionOutput.forPayment(40000, sender.getAddress(0)),
          TransactionOutput.forPayment(30000, wallet.address(0)),
        ],
        AddressType.p2wpkh,
      );
      signP2wpkhInput(old, 0, senderFunding.outputs.single, senderKey);
      // 보내는 사람이 그 거래의 자기 잔돈(출력 1)을 써서 내 받기 주소 1로 보낸다(실제 서명)
      final incoming = Transaction.withInputsAndOutputs(
        [TransactionInput.forPayment(old.transactionHash, 1)],
        [
          TransactionOutput.forPayment(20000, wallet.address(1)),
          TransactionOutput.forPayment(19000, sender.getAddress(0)),
        ],
        AddressType.p2wpkh,
      );
      signP2wpkhInput(incoming, 0, old.outputs[1], senderKey);
      wallet.publish([senderFunding, old, incoming]);
      // 3.1.4·3.1.5는 OP_RETURN 출력을 자리 없이 건너뛰고 저장했고, 마이그레이션은 그대로 옮긴다(출력 1 자리에 내 주소)
      await wallet.txs.addAllTransactions(walletId, [
        TransactionRecord.fromTransactions(
          transactionHash: old.transactionHash,
          timestamp: DateTime(2025, 6, 20),
          blockHeight: 100,
          transactionType: TransactionType.received,
          amount: 30000,
          fee: 30000,
          inputAddressList: [TransactionAddress(sender.getAddress(0), 100000)],
          outputAddressList: [
            TransactionAddress(sender.getAddress(0), 40000),
            TransactionAddress(wallet.address(0), 30000),
          ],
          vSize: 150,
        ),
      ]);

      await wallet.sync([history(incoming, 0)], index: 1);

      final record = wallet.txs.getTransactionRecord(walletId, incoming.transactionHash);
      expect(record?.transactionType, TransactionType.received);
      expect(record?.amount, 20000);
    });
  });

  group('N2: 내 Taproot 스크립트 경로 입력 + 남의 레거시(P2PKH) 입력', () {
    final signer = walletSigners(0x10).firstWhere((s) => s.name == 'p2tr 스크립트 경로');
    final keys = taprootKeys(0x10);
    late SyncedWallet wallet;
    late Transaction funding;
    late UtxoState coin;
    late Transaction mixed;
    late List<TransactionOutput> prevouts;
    late List<String> leaf;

    setUp(() async {
      wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
      final known = signer.funded([60000], 1);
      funding = known.funding;
      coin = known.coins.single;
      // 같은 코인의 실제 스크립트 경로 지출에서 스크립트·제어 블록·잠금 시각을 가져온다
      final real = signer.pay(known.coins, {shop: 30000});
      leaf = real.inputs.single.witnessList.sublist(1);
      final legacyFunding = fundingTransaction([('mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn', 80000)], 4);
      wallet.publish([funding, legacyFunding]);
      await wallet.sync([history(funding, 100)], unspentList: wallet.unspent(funding, 100));
      mixed = Transaction.withInputsAndOutputs(
        [
          TransactionInput.forPayment(legacyFunding.transactionHash, 0),
          TransactionInput.forPayment(coin.transactionHash, coin.index, sequence: real.inputs.single.sequence),
        ],
        [TransactionOutput.forPayment(130000, shop)],
        AddressType.p2tr,
        lockTime: Converter.littleEndianToInt(Codec.decodeHex(real.lockTime)),
      );
      prevouts = [legacyFunding.outputs.single, TransactionOutput.forPayment(coin.amount, coin.to)];
    });

    Future<void> syncMixed() => wallet.sync([history(funding, 100), history(mixed, 0)]);

    test('내 스크립트 경로 서명이 맞으면 남의 입력 모양과 상관없이 넣는다', () async {
      signTaprootScriptPathInput(mixed, 1, prevouts, keys.beneficiary.hdWallet.derive(0).derive(0), leaf[0], leaf[1]);
      wallet.publish([mixed]);

      await syncMixed();

      expect(wallet.txs.getTransactionRecord(walletId, mixed.transactionHash)?.blockHeight, 0);
      expect(wallet.coin(coin.transactionHash, coin.index)?.spentByTransactionHash, mixed.transactionHash);
    });

    test('내 스크립트 경로 서명이 틀리면 넣지 않는다', () async {
      signTaprootScriptPathInput(mixed, 1, prevouts, keys.parent.hdWallet.derive(0).derive(0), leaf[0], leaf[1]);
      wallet.publish([mixed]);

      await expectDropped(wallet, mixed, syncMixed);
    });
  });

  group('2. 내 Taproot 키 경로 입력 + 진짜 남의 P2WPKH 입력', () {
    final signer = walletSigners(0x10).firstWhere((s) => s.name == 'p2tr 키 경로');
    final scriptSigner = walletSigners(0x10).firstWhere((s) => s.name == 'p2tr 스크립트 경로');
    final keys = taprootKeys(0x10);
    final foreign = _vault(0x55);
    late SyncedWallet wallet;
    late Transaction funding;
    late Transaction foreignFunding;
    late UtxoState coin;
    late Transaction mixed;
    late List<TransactionOutput> prevouts;
    late List<String> leaf;

    setUp(() async {
      wallet = SyncedWallet(realm, signer.item, purpose: signer.purpose);
      final known = signer.funded([60000], 1);
      funding = known.funding;
      coin = known.coins.single;
      leaf = scriptSigner.pay(known.coins, {shop: 30000}).inputs.single.witnessList.sublist(1);
      expect(
        Codec.encodeHex(Codec.decodeHex(leaf[1]).sublist(1, 33)),
        Codec.encodeHex(keys.parent.hdWallet.derive(0).derive(0).publicKey.sublist(1)),
        reason: '제어 블록의 내부 키는 키 경로 키',
      );
      foreignFunding = fundingTransaction([(foreign.getAddress(0), 80000)], 95);
      wallet.publish([funding, foreignFunding]);
      await wallet.sync([history(funding, 100)], unspentList: wallet.unspent(funding, 100));
      mixed = Transaction.withInputsAndOutputs(
        [
          TransactionInput.forPayment(coin.transactionHash, coin.index),
          TransactionInput.forPayment(foreignFunding.transactionHash, 0),
        ],
        [TransactionOutput.forPayment(130000, shop), TransactionOutput.forPayment(9000, foreign.getAddress(1))],
        AddressType.p2tr,
      );
      prevouts = [TransactionOutput.forPayment(coin.amount, coin.to), foreignFunding.outputs.single];
      signP2wpkhInput(mixed, 1, foreignFunding.outputs.single, _receiveKey(foreign, 0));
    });

    Future<void> syncMixed() => wallet.sync([history(funding, 100), history(mixed, 0)]);

    test('남의 이전 거래를 받아(거래 번호 확인) 내 키 경로 서명을 확인하고 넣는다', () async {
      signTaprootKeyPathInput(mixed, 0, prevouts, keys.parent.hdWallet.derive(0).derive(0), leaf[0], leaf[1]);
      wallet.publish([mixed]);

      await syncMixed();

      expect(wallet.txs.getTransactionRecord(walletId, mixed.transactionHash)?.blockHeight, 0);
    });

    test('내 키 경로 서명이 틀리면 넣지 않는다', () async {
      signTaprootKeyPathInput(mixed, 0, prevouts, keys.beneficiary.hdWallet.derive(0).derive(0), leaf[0], leaf[1]);
      wallet.publish([mixed]);

      await expectDropped(wallet, mixed, syncMixed);
    });
  });
}
