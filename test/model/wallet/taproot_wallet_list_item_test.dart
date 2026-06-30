import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_list_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 탭루트 상속 지갑
  const parentTaprootXpub =
      "tpubDDMbU29QrSafD2Ui4yGv31Xp3PPSMvudreoohYjR8xLTng7hbsjYwUTeRhiKULFqX16M5M8zZh9siw5i6RRyisc6LtWjr1FwBYTiZUGGYJN";
  const childTaprootXpub =
      "tpubDCp2emt17Ng6ujD8BC6ScL4vfwhN3nAJQ8kCqLjRQHxcFhWt6YK5Ws6UcKD6HgLCZuwU8DryKo7h2gpieLa7Q9YF1AqfL9XiF7349nHaLi8";
  const oneParentDescriptor =
      "tr([9B1441E4/86'/1'/0']$parentTaprootXpub/<0;1>/*,{and_v(v:pk([70C4E9DE/86'/1'/0']$childTaprootXpub/<0;1>/*),older(500000000))})#w0hf4lu5";

  const cosigner1TaprootXpub =
      "tpubDDJ3csugKLHjjx6HpLQLc9kpbQs5Kh1Kp3riEQ7Zm9YebjK8v7eFcZKdVRSuVDeXcjU3yM2e1cZXe1T7cTtPJQZvow5EovmgNoV6zgEJdc9";
  const cosigner2TaprootXpub =
      "tpubDDSNhWuFHA8XgWyxzM9yoGpmfYiBrzYZyGy29koZLXzPgSYjK7RUpkrrnmKiaMBWBzVUhvShA3vaSPTMGbx8YHL6sa8yY4eLqnuSSuECheK";
  const inheritanceMiniscript = "and_v(v:pk([70C4E9DE/86'/1'/0']$childTaprootXpub/<0;1>/*),older(500000000))";
  const twoParentDescriptor =
      "tr(musig(sorted([57450F41/86'/1'/0']$cosigner1TaprootXpub/<0;1>/*,[F82D58DD/86'/1'/0']$cosigner2TaprootXpub/<0;1>/*)),{$inheritanceMiniscript})#sz5a4k3h";

  group('TaprootWalletListItem', () {
    test('oneParentDescriptor: 필드 값 보존', () {
      final keyPathSeedInfos = [parentTaprootXpub];
      final scriptPathSeedInfos = [
        TaprootScriptPathSeedInfo(miniscript: inheritanceMiniscript, extendedPublicKeys: [childTaprootXpub]),
      ];

      final item = TaprootWalletListItem(
        id: 1,
        name: 'One Parent Taproot',
        colorIndex: 2,
        iconIndex: 3,
        descriptor: oneParentDescriptor,
        keyPathSeedInfos: keyPathSeedInfos,
        scriptPathSeedInfos: scriptPathSeedInfos,
      );

      expect(item.id, 1);
      expect(item.name, 'One Parent Taproot');
      expect(item.colorIndex, 2);
      expect(item.iconIndex, 3);
      expect(item.descriptor, oneParentDescriptor);
      expect(item.walletType, WalletType.taproot);
      expect(item.walletImportSource, WalletImportSource.coconutVault);
      expect(item.keyPathSeedInfos.length, 1);
      expect(item.keyPathSeedInfos[0], parentTaprootXpub);
      expect(item.scriptPathSeedInfos.length, 1);
      expect(item.scriptPathSeedInfos[0].miniscript, inheritanceMiniscript);
      expect(item.scriptPathSeedInfos[0].extendedPublicKeys, [childTaprootXpub]);
    });

    test('twoParentDescriptor: 필드 값 보존', () {
      final keyPathSeedInfos = [cosigner1TaprootXpub, cosigner2TaprootXpub];
      final scriptPathSeedInfos = [
        TaprootScriptPathSeedInfo(miniscript: inheritanceMiniscript, extendedPublicKeys: [childTaprootXpub]),
      ];

      final item = TaprootWalletListItem(
        id: 2,
        name: 'Two Parent Taproot',
        colorIndex: 3,
        iconIndex: 4,
        descriptor: twoParentDescriptor,
        keyPathSeedInfos: keyPathSeedInfos,
        scriptPathSeedInfos: scriptPathSeedInfos,
      );

      expect(item.id, 2);
      expect(item.name, 'Two Parent Taproot');
      expect(item.colorIndex, 3);
      expect(item.iconIndex, 4);
      expect(item.descriptor, twoParentDescriptor);
      expect(item.walletType, WalletType.taproot);
      expect(item.walletImportSource, WalletImportSource.coconutVault);
      expect(item.keyPathSeedInfos.length, 2);
      expect(item.keyPathSeedInfos[0], cosigner1TaprootXpub);
      expect(item.keyPathSeedInfos[1], cosigner2TaprootXpub);
      expect(item.scriptPathSeedInfos.length, 1);
      expect(item.scriptPathSeedInfos[0].miniscript, inheritanceMiniscript);
      expect(item.scriptPathSeedInfos[0].extendedPublicKeys, [childTaprootXpub]);
    });

    test('빈 배열도 허용', () {
      final item = TaprootWalletListItem(
        id: 1,
        name: 'Empty',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: oneParentDescriptor,
        keyPathSeedInfos: [],
        scriptPathSeedInfos: [],
      );

      expect(item.keyPathSeedInfos, isEmpty);
      expect(item.scriptPathSeedInfos, isEmpty);
    });
  });
}
