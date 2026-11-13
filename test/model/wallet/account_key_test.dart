import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';

/// 결정 ⑦의 같은 계정 키([WalletItemBase.accountKey]). 핫월렛과 그 계정의 보기 전용 지갑은 앱이 넣는 어느 길로 넣어도 같고,
/// 다른 계정 번호·패스프레이즈·다른 시드·다른 주소 유형·다중 서명은 다르다. 지갑 종류(핫·보기 전용)는 키를 가르지 않는다.
/// Fable v6 확인(N2)의 스크래치 테스트를 정식으로 옮겼다.
void main() {
  // BIP-39 표준 테스트 니모닉(자금 없음)
  Uint8List words(String text) => Uint8List.fromList(utf8.encode(text));
  final mnemonic = words(
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
  );

  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  SingleSignatureVault vault({int accountIndex = 0, AddressType? addressType, String passphrase = ''}) =>
      SingleSignatureVault.fromSeed(
        Seed.fromMnemonic(mnemonic, passphrase: words(passphrase)),
        addressType: addressType,
        accountIndex: accountIndex,
      );

  SinglesigWalletItem wallet(int id, String descriptor) =>
      SinglesigWalletItem(id: id, name: 'w$id', colorIndex: 0, iconIndex: 0, descriptor: descriptor);

  // 앱이 핫월렛을 만드는 길: 니모닉 → 볼트 descriptor + 핫월렛 메타데이터
  SinglesigWalletItem hotWallet(SingleSignatureVault source) => SinglesigWalletItem(
    id: 1,
    name: 'hot',
    colorIndex: 0,
    iconIndex: 0,
    descriptor: source.descriptor,
    hotWalletMetadata: HotWalletMetadata(
      walletId: 1,
      secureStorageKey: 'test',
      masterFingerprint: '73C5DA0A',
      derivationPath: source.derivationPath,
      accountIndex: 0,
      backupVerified: true,
      enterPassphraseWhenSigning: false,
      createdAt: DateTime(2026, 11, 12),
    ),
  );

  test('a hot wallet and its watch-only copies share the key however they were added', () {
    final source = vault();
    final hot = hotWallet(source);
    final service = WalletAddService();
    final xpub = source.keyStore.extendedPublicKey.serialize();
    final copies = {
      'same descriptor': wallet(2, source.descriptor),
      // 지문을 모르는 확장 공개키: 지갑 정보 글자가 00000000으로 달라진다
      'xpub only': wallet(3, service.createExtendedPublicKeyWallet(xpub, 'watch', null).descriptor),
      'xpub with fingerprint': wallet(
        4,
        service.createExtendedPublicKeyWallet(xpub, 'watch', source.keyStore.masterFingerprint).descriptor,
      ),
      'descriptor': wallet(5, service.createWalletFromDescriptor(descriptor: source.descriptor, name: 'd').descriptor),
      'descriptor without checksum': wallet(
        6,
        service.createWalletFromDescriptor(descriptor: source.descriptor.split('#').first, name: 'd').descriptor,
      ),
    };
    expect(hot.hasLocalKey, isTrue);
    copies.forEach((label, copy) {
      expect(copy.hasLocalKey, isFalse, reason: label);
      // 지갑 종류는 둘 다 단일 서명이라 핫·보기 전용으로 나뉘지 않는다
      expect(copy.walletType, hot.walletType, reason: label);
      expect(copy.accountKey, hot.accountKey, reason: label);
    });
    // 지갑 정보 글자로 비교했다면 놓쳤을 경우
    expect(copies['xpub only']!.descriptor, isNot(hot.descriptor));
  });

  test('another account index, passphrase, seed, address type or a multisig wallet is another account', () {
    final hot = hotWallet(vault());
    final taproot = vault(addressType: AddressType.p2tr);
    final others = <String, WalletItemBase>{
      'account 1': wallet(10, vault(accountIndex: 1).descriptor),
      'passphrase': wallet(11, vault(passphrase: 'p').descriptor),
      'other seed': wallet(12, SingleSignatureVault.random().descriptor),
      // 이 앱의 단일 서명은 native SegWit만 받아서, 같은 시드의 다른 주소 유형은 taproot 지갑으로 본다
      'taproot from the same seed': TaprootWalletItem(
        id: 13,
        name: 'taproot',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: taproot.descriptor,
        keyPathSeedInfos: [taproot.keyStore.extendedPublicKey.serialize()],
        scriptPathSeedInfos: const [],
      ),
      'taproot': WalletMock.createTaprootWalletItem(id: 14),
      'multisig': WalletMock.createMultiSigWalletItem(id: 15),
      'another single sig': WalletMock.createSingleSigWalletItem(id: 16),
    };
    final keys = {hot.accountKey};
    others.forEach((label, other) => expect(keys.add(other.accountKey), isTrue, reason: label));
  });

  test('the key is cached per wallet base and follows a replaced one', () {
    final hot = hotWallet(vault());
    final before = hot.accountKey;
    expect(identical(hot.accountKey, before), isTrue);
    hot.walletBase = SingleSignatureWallet.fromDescriptor(SingleSignatureVault.random().descriptor);
    expect(hot.accountKey, isNot(before));
  });

  // Fable N7: 앱이 만들지 않는 조합(단일 서명 지갑에 taproot 지갑 정보)은 첫 주소를 만들지 못한다. 그때는 묶지 않는다.
  test('a wallet whose first address cannot be made is not grouped with anything', () {
    final odd = wallet(20, vault(addressType: AddressType.p2tr).descriptor);
    expect(odd.accountKey, 'wallet:20');
  });
}
