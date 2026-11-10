import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/services/transaction/unsigned_psbt_service.dart';
import 'package:coconut_wallet/utils/migration/taproot_legacy_inheritance_migration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/legacy_inheritance_fixtures.dart';

const _amount = 100000;

TaprootWalletItem _loadedWallet(String storedDescriptor, String storedMiniscript) {
  final loaded = TaprootLegacyInheritanceMigration.migrate(
    descriptor: storedDescriptor,
    scriptPathSeedInfos: [TaprootScriptPathSeedInfo(miniscript: storedMiniscript, extendedPublicKeys: const [])],
  );
  return TaprootWalletItem(
    id: 1,
    name: 'Inheritance',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: loaded.descriptor,
    keyPathSeedInfos: const ['parent'],
    scriptPathSeedInfos: loaded.scriptPathSeedInfos,
  );
}

UtxoState _utxoAt(String address, String derivationPath) {
  return UtxoState(
    transactionHash: '11' * 32,
    index: 0,
    amount: _amount,
    blockHeight: 100,
    to: address,
    derivationPath: derivationPath,
    timestamp: DateTime(2026, 11, 9),
  );
}

Future<PreparedUnsignedPsbt> _preparePsbt(TaprootWalletItem item, UtxoState utxo, {required bool scriptPath}) {
  final wallet = item.walletBase as TaprootWallet;
  final result =
      TransactionBuilder(
        availableUtxos: [utxo],
        recipients: {wallet.getAddress(5): 50000},
        feeRate: 2,
        changeDerivationPath: '${wallet.derivationPath}/1/0',
        walletItemBase: item,
        isFeeSubtractedFromAmount: false,
        isUtxoFixed: true,
        scriptPathPolicy: scriptPath ? item.defaultPolicy : null,
      ).build();
  expect(result.isSuccess, isTrue, reason: result.exception?.toString());
  return prepareUnsignedPsbt(transaction: result.transaction!, wallet: wallet);
}

String _signLikeVault(String vaultDescriptor, String psbt, String mnemonic, {required bool scriptPath}) {
  final vault = TaprootVault.fromCoordinatorBsms(TaprootVault.fromDescriptor(vaultDescriptor).getCoordinatorBsms());
  final seed = Seed.fromMnemonic(utf8.encode(mnemonic));
  if (scriptPath) {
    vault.bindSeedToBeneficiaryKeyStore(seed);
  } else {
    vault.bindSeedToKeyStore(seed);
  }
  return vault.addSignatureToPsbt(psbt);
}

void main() {
  late NetworkType previousNetwork;

  setUpAll(() {
    previousNetwork = NetworkType.currentNetworkType;
    NetworkType.setNetworkType(NetworkType.testnet);
  });

  tearDownAll(() => NetworkType.setNetworkType(previousNetwork));

  final fixture = legacyInheritanceFixtures.firstWhere(
    (fixture) => fixture.parentMnemonics.length == 1 && fixture.locktime == 1780012800,
  );
  final newMiniscript = fixture.storedMiniscript.replaceFirstMapped(
    RegExp(r'^and_v\(v:pk\((.+)\),after\((\d+)\)\)$'),
    (match) => 'and_v(v:after(${match[2]}),pk(${match[1]}))',
  );
  final newDescriptor =
      Descriptor.parse(
        fixture.storedDescriptor.split('#').first.replaceFirst('{${fixture.storedMiniscript}}', newMiniscript),
        ignoreChecksum: true,
      ).serialize();

  final cases = {
    '스크립트 수정 이전 지갑': (_loadedWallet(fixture.storedDescriptor, fixture.storedMiniscript), fixture.receive0, true),
    '스크립트 수정 이후 지갑': (
      _loadedWallet(newDescriptor, newMiniscript),
      'tb1pcnwfgvdym3sewa7cdccscmensvy45lfes4hla3j887ul0lxlzmzqk9n266',
      false,
    ),
  };

  for (final entry in cases.entries) {
    final (item, receive0, isLegacy) = entry.value;
    final wallet = item.walletBase as TaprootWallet;

    group(entry.key, () {
      test('받기 주소 0번과 정책 방식이 유지된다', () {
        expect(wallet.getAddress(0), receive0);
        expect(item.defaultPolicy is LegacyInheritancePolicy, isLegacy);
      });

      test('이전 방식 지갑 PSBT에만 코코넛 식별자를 넣지 않는다', () async {
        final utxo = _utxoAt(wallet.getAddress(0), '${wallet.derivationPath}/0/0');
        for (final scriptPath in [false, true]) {
          final prepared = await _preparePsbt(item, utxo, scriptPath: scriptPath);
          final psbt = Psbt.parse(prepared.serialized);
          expect(psbt.isFromCoconut, !isLegacy);
          expect(psbt.matchesVault(TaprootVault.fromDescriptor(item.descriptor)), isTrue);
        }
      });

      for (final scriptPath in [false, true]) {
        final label = scriptPath ? 'script-path' : 'key-path';
        test('$label PSBT에 볼트 방식으로 서명하고 완성한 거래의 서명이 유효하다', () async {
          final utxo = _utxoAt(wallet.getAddress(0), '${wallet.derivationPath}/0/0');
          final prepared = await _preparePsbt(item, utxo, scriptPath: scriptPath);

          final signed = _signLikeVault(
            item.descriptor,
            prepared.serialized,
            scriptPath ? legacyChildMnemonic : legacyParentMnemonic1,
            scriptPath: scriptPath,
          );
          final transaction = Psbt.parse(signed).getSignedTransaction(AddressType.p2tr);

          expect(transaction.validateSpend([TransactionOutput.forPayment(_amount, receive0)]), isTrue);
          if (scriptPath) {
            final witness = transaction.inputs.single.witnessList;
            expect(witness, hasLength(3));
            expect(witness[1], (item.defaultPolicy!).toScript(0).rawSerialize());
            expect(Codec.decodeHex(transaction.lockTime), Converter.intToLittleEndianBytes(fixture.locktime, 4));
            expect(transaction.inputs.single.sequence, lessThan(0xffffffff));
          }
        });
      }
    });
  }

  test('저장된 이전 지갑의 UTXO로 수정 이후 방식 PSBT를 만들지 않는다', () async {
    final (legacyItem, _, _) = cases['스크립트 수정 이전 지갑']!;
    final (newItem, _, _) = cases['스크립트 수정 이후 지갑']!;
    final legacyWallet = legacyItem.walletBase as TaprootWallet;
    final legacyUtxo = _utxoAt(legacyWallet.getAddress(0), '${legacyWallet.derivationPath}/0/0');

    for (final scriptPath in [false, true]) {
      await expectLater(_preparePsbt(newItem, legacyUtxo, scriptPath: scriptPath), throwsA(isA<StateError>()));
    }
  });
}
