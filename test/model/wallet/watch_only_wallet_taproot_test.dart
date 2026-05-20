import 'dart:convert';

import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
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
  // 기존 볼트 QR에서 사용하는 singlesig descriptor (testnet, purpose 84')
  const singlesigDescriptor =
      "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";

  group('WatchOnlyWallet Taproot fromJson', () {
    test('oneParentDescriptor: keyPathSeedInfos + scriptPathSeedInfos 모두 있을 때', () {
      final json = {
        'name': 'Taproot Inheritance',
        'colorIndex': 2,
        'iconIndex': 3,
        'descriptor': oneParentDescriptor,
        'keyPathSeedInfos': [parentTaprootXpub],
        'scriptPathSeedInfos': [
          {
            'miniscript': inheritanceMiniscript,
            'extendedPublicKeys': [childTaprootXpub],
          },
        ],
      };

      final wallet = WatchOnlyWallet.fromJson(json);

      expect(wallet.name, 'Taproot Inheritance');
      expect(wallet.colorIndex, 2);
      expect(wallet.iconIndex, 3);
      expect(wallet.isTaproot, true);
      expect(wallet.keyPathSeedInfos, isNotNull);
      expect(wallet.keyPathSeedInfos!.length, 1);
      expect(wallet.scriptPathSeedInfos, isNotNull);
      expect(wallet.scriptPathSeedInfos!.length, 1);
      expect(wallet.scriptPathSeedInfos![0].miniscript, inheritanceMiniscript);
      expect(wallet.scriptPathSeedInfos![0].extendedPublicKeys.length, 1);
    });

    test('twoParentDescriptor: keyPathSeedInfos + scriptPathSeedInfos 모두 있을 때', () {
      final json = {
        'name': 'Taproot 2P',
        'colorIndex': 1,
        'iconIndex': 1,
        'descriptor': twoParentDescriptor,
        'keyPathSeedInfos': ['vpub1', 'vpub2'],
        'scriptPathSeedInfos': [
          {
            'miniscript': 'and_v(v:pk(key_1),older(500000000))',
            'extendedPublicKeys': ['vpub3'],
          },
        ],
      };

      final wallet = WatchOnlyWallet.fromJson(json);

      expect(wallet.isTaproot, true);
      expect(wallet.keyPathSeedInfos!.length, 2);
      expect(wallet.scriptPathSeedInfos!.length, 1);
    });

    test('기존 singlesig 볼트 QR JSON 파싱: Taproot 필드 없을 때', () {
      final json = {'name': 'My Vault', 'colorIndex': 0, 'iconIndex': 0, 'descriptor': singlesigDescriptor};

      final wallet = WatchOnlyWallet.fromJson(json);

      expect(wallet.name, 'My Vault');
      expect(wallet.isTaproot, false);
      expect(wallet.keyPathSeedInfos, isNull);
      expect(wallet.scriptPathSeedInfos, isNull);
    });

    test('keyPathSeedInfos만 있고 scriptPathSeedInfos 없으면 isTaproot == true', () {
      final json = {
        'name': 'Partial',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': oneParentDescriptor,
        'keyPathSeedInfos': ['vpub1'],
      };

      final wallet = WatchOnlyWallet.fromJson(json);

      expect(wallet.isTaproot, true);
      expect(wallet.keyPathSeedInfos, isNotNull);
      expect(wallet.scriptPathSeedInfos, isNull);
    });

    test('scriptPathSeedInfos만 있고 keyPathSeedInfos 없으면 isTaproot == true', () {
      final json = {
        'name': 'Partial2',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': oneParentDescriptor,
        'scriptPathSeedInfos': [
          {
            'miniscript': 'and_v(v:pk(key_1),older(500000000))',
            'extendedPublicKeys': ['vpub1'],
          },
        ],
      };

      final wallet = WatchOnlyWallet.fromJson(json);

      expect(wallet.isTaproot, true);
      expect(wallet.keyPathSeedInfos, isNull);
      expect(wallet.scriptPathSeedInfos, isNotNull);
    });

    test('keyPathSeedInfos와 scriptPathSeedInfos가 빈 배열이어도 isTaproot == true', () {
      final json = {
        'name': 'Partial',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': oneParentDescriptor,
        'keyPathSeedInfos': [],
        'scriptPathSeedInfos': [],
      };

      final wallet = WatchOnlyWallet.fromJson(json);

      expect(wallet.isTaproot, true);
      expect(wallet.keyPathSeedInfos, isNotNull);
      expect(wallet.keyPathSeedInfos, isEmpty);
      expect(wallet.scriptPathSeedInfos, isNotNull);
      expect(wallet.scriptPathSeedInfos, isEmpty);
    });

    test('toJson round-trip: Taproot 필드 보존', () {
      final json = {
        'name': 'Taproot RT',
        'colorIndex': 1,
        'iconIndex': 2,
        'descriptor': oneParentDescriptor,
        'keyPathSeedInfos': ['vpub1'],
        'scriptPathSeedInfos': [
          {
            'miniscript': 'and_v(v:pk(key_1),older(500000000))',
            'extendedPublicKeys': ['vpub2'],
          },
        ],
      };

      final wallet = WatchOnlyWallet.fromJson(json);
      final serialized = jsonDecode(wallet.toJson()) as Map<String, dynamic>;

      expect(serialized['keyPathSeedInfos'], json['keyPathSeedInfos']);
      expect(serialized['scriptPathSeedInfos'], json['scriptPathSeedInfos']);
    });

    test('빈 배열이 null로 변환되지 않고 그대로 유지됨', () {
      final json = {
        'name': 'Empty Arrays',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': oneParentDescriptor,
        'keyPathSeedInfos': <String>[],
        'scriptPathSeedInfos': <Map<String, dynamic>>[],
      };

      final wallet = WatchOnlyWallet.fromJson(json);

      expect(wallet.isTaproot, true);
      expect(wallet.keyPathSeedInfos, isNotNull);
      expect(wallet.keyPathSeedInfos, isEmpty);
      expect(wallet.scriptPathSeedInfos, isNotNull);
      expect(wallet.scriptPathSeedInfos, isEmpty);
    });

    test('toJson: 기존 singlesig에는 Taproot 필드 포함되지 않음', () {
      final json = {'name': 'Normal', 'colorIndex': 0, 'iconIndex': 0, 'descriptor': singlesigDescriptor};

      final wallet = WatchOnlyWallet.fromJson(json);
      final serialized = jsonDecode(wallet.toJson()) as Map<String, dynamic>;

      expect(serialized.containsKey('keyPathSeedInfos'), false);
      expect(serialized.containsKey('scriptPathSeedInfos'), false);
    });
  });

  group('isSupportedTaprootConfiguration', () {
    test('oneParentDescriptor: keypath 1개 + scriptpath 1개: 지원됨', () {
      final json = {
        'name': 'Valid1',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': oneParentDescriptor,
        'keyPathSeedInfos': ['vpub1'],
        'scriptPathSeedInfos': [
          {
            'miniscript': 'and_v(v:pk(key_1),older(500000000))',
            'extendedPublicKeys': ['vpub2'],
          },
        ],
      };
      final wallet = WatchOnlyWallet.fromJson(json);
      expect(wallet.isSupportedTaprootConfiguration, true);
    });

    test('twoParentDescriptor: keypath 2개 + scriptpath 1개: 지원됨', () {
      final json = {
        'name': 'Valid2',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': twoParentDescriptor,
        'keyPathSeedInfos': ['vpub1', 'vpub2'],
        'scriptPathSeedInfos': [
          {
            'miniscript': 'and_v(v:pk(key_1),older(500000000))',
            'extendedPublicKeys': ['vpub3'],
          },
        ],
      };
      final wallet = WatchOnlyWallet.fromJson(json);
      expect(wallet.isSupportedTaprootConfiguration, true);
    });

    test('keypath 3개 + scriptpath 1개: 지원 안됨', () {
      final json = {
        'name': 'Invalid',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': twoParentDescriptor,
        'keyPathSeedInfos': ['vpub1', 'vpub2', 'vpub3'],
        'scriptPathSeedInfos': [
          {
            'miniscript': 'and_v(v:pk(key_1),older(500000000))',
            'extendedPublicKeys': ['vpub4'],
          },
        ],
      };
      final wallet = WatchOnlyWallet.fromJson(json);
      expect(wallet.isSupportedTaprootConfiguration, false);
    });

    test('keypath 1개 + scriptpath 2개: 지원 안됨', () {
      final json = {
        'name': 'Invalid2',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': oneParentDescriptor,
        'keyPathSeedInfos': ['vpub1'],
        'scriptPathSeedInfos': [
          {
            'miniscript': 'and_v(v:pk(key_1),older(500000000))',
            'extendedPublicKeys': ['vpub2'],
          },
          {
            'miniscript': 'and_v(v:pk(key_2),older(1000))',
            'extendedPublicKeys': ['vpub3'],
          },
        ],
      };
      final wallet = WatchOnlyWallet.fromJson(json);
      expect(wallet.isSupportedTaprootConfiguration, false);
    });

    test('keypath 0개 + scriptpath 1개: 지원 안됨', () {
      final json = {
        'name': 'Invalid3',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': oneParentDescriptor,
        'keyPathSeedInfos': <String>[],
        'scriptPathSeedInfos': [
          {
            'miniscript': 'and_v(v:pk(key_1),older(500000000))',
            'extendedPublicKeys': ['vpub1'],
          },
        ],
      };
      final wallet = WatchOnlyWallet.fromJson(json);
      expect(wallet.isSupportedTaprootConfiguration, false);
    });

    test('purpose가 86이 아닌 descriptor: 지원 안됨', () {
      final json = {
        'name': 'WrongPurpose',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': singlesigDescriptor,
        'keyPathSeedInfos': ['vpub1'],
        'scriptPathSeedInfos': [
          {
            'miniscript': 'and_v(v:pk(key_1),older(1000))',
            'extendedPublicKeys': ['vpub2'],
          },
        ],
      };
      final wallet = WatchOnlyWallet.fromJson(json);
      expect(wallet.isSupportedTaprootConfiguration, false);
    });

    test('non-taproot 지갑: false', () {
      final json = {'name': 'Normal', 'colorIndex': 0, 'iconIndex': 0, 'descriptor': singlesigDescriptor};
      final wallet = WatchOnlyWallet.fromJson(json);
      expect(wallet.isSupportedTaprootConfiguration, false);
    });
  });

  group('TaprootScriptPathSeedInfo', () {
    test('fromJson / toJson round-trip', () {
      final original = TaprootScriptPathSeedInfo(
        miniscript: 'and_v(v:pk(key_1),older(1000))',
        extendedPublicKeys: ['xpub1', 'xpub2'],
      );

      final json = original.toJson();
      final restored = TaprootScriptPathSeedInfo.fromJson(json);

      expect(restored.miniscript, 'and_v(v:pk(key_1),older(1000))');
      expect(restored.extendedPublicKeys, ['xpub1', 'xpub2']);
      expect(restored, original);
    });

    test('다른 miniscript 값도 파싱 가능', () {
      final info = TaprootScriptPathSeedInfo(miniscript: 'pk(key_2)', extendedPublicKeys: ['xpub1']);

      final json = info.toJson();
      expect(json['miniscript'], 'pk(key_2)');

      final restored = TaprootScriptPathSeedInfo.fromJson(json);
      expect(restored.miniscript, 'pk(key_2)');
      expect(restored.extendedPublicKeys, ['xpub1']);
    });
  });
}
