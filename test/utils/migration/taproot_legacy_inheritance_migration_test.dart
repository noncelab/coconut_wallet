import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/utils/migration/taproot_legacy_inheritance_migration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/legacy_inheritance_fixtures.dart';

const _childXpub =
    "tpubDDHnNFFb1gf8qGYVejVx4GwzQPwcphirPssHFMWFcL9iajxm1wWd5ye22T7UQrVPjwwifJaCJGBAphuu8oePzYTCN7eZgm1KnyfNDmcfnsu";

String _withChecksum(String body) => '$body#${Checksum.getChecksum(body)}';

void _expectLegacyAddresses(String descriptor, LegacyInheritanceFixture fixture) {
  final wallet = TaprootWallet.fromDescriptor(descriptor);
  expect(wallet.policyList.single, isA<LegacyInheritancePolicy>());
  expect(wallet.getAddress(0), fixture.receive0);
  expect(wallet.getAddress(1), fixture.receive1);
  expect(wallet.getAddress(0, isChange: true), fixture.change0);
}

void main() {
  late NetworkType previousNetwork;

  setUpAll(() {
    previousNetwork = NetworkType.currentNetworkType;
    NetworkType.setNetworkType(NetworkType.testnet);
  });

  tearDownAll(() => NetworkType.setNetworkType(previousNetwork));

  for (final fixture in legacyInheritanceFixtures) {
    final label = '${fixture.parentMnemonics.length} parent(s), locktime ${fixture.locktime}';

    group(label, () {
      test('저장된 after 표기를 after_drop으로 바꾸고 coconut_lib 1.1.1 주소를 유지한다', () {
        final result = TaprootLegacyInheritanceMigration.migrate(
          descriptor: fixture.storedDescriptor,
          scriptPathSeedInfos: [
            TaprootScriptPathSeedInfo(miniscript: fixture.storedMiniscript, extendedPublicKeys: [_childXpub]),
          ],
        );

        expect(result.hasChanges, isTrue);
        expect(result.hasOlder, isFalse);
        expect(result.descriptor, contains('after_drop(${fixture.locktime})'));
        expect(result.scriptPathSeedInfos.single.miniscript, startsWith('and_v(after_drop(${fixture.locktime}),pk('));
        _expectLegacyAddresses(result.descriptor, fixture);
      });

      test('older 표기도 같은 지갑으로 바꾼다', () {
        final olderDescriptor = _withChecksum(
          fixture.storedDescriptor
              .split('#')
              .first
              .replaceFirst('after(${fixture.locktime})', 'older(${fixture.locktime})'),
        );
        final result = TaprootLegacyInheritanceMigration.migrate(
          descriptor: olderDescriptor,
          scriptPathSeedInfos: [
            TaprootScriptPathSeedInfo(
              miniscript: fixture.storedMiniscript.replaceFirst('after(', 'older('),
              extendedPublicKeys: [_childXpub],
            ),
          ],
        );

        expect(result.hasOlder, isTrue);
        _expectLegacyAddresses(result.descriptor, fixture);
      });

      test('다시 적용해도 바뀌지 않는다', () {
        final first = TaprootLegacyInheritanceMigration.migrate(
          descriptor: fixture.storedDescriptor,
          scriptPathSeedInfos: [
            TaprootScriptPathSeedInfo(miniscript: fixture.storedMiniscript, extendedPublicKeys: [_childXpub]),
          ],
        );
        final second = TaprootLegacyInheritanceMigration.migrate(
          descriptor: first.descriptor,
          scriptPathSeedInfos: first.scriptPathSeedInfos,
        );

        expect(second.hasChanges, isFalse);
        expect(second.hasOlder, isFalse);
        expect(second.descriptor, first.descriptor);
        expect(second.scriptPathSeedInfos, first.scriptPathSeedInfos);
      });
    });
  }

  test('수정 이후 표기(v:after)는 바꾸지 않고 다른 지갑으로 남긴다', () {
    final fixture = legacyInheritanceFixtures.firstWhere(
      (fixture) => fixture.parentMnemonics.length == 1 && fixture.locktime == 1780012800,
    );
    final internalKey = fixture.storedDescriptor.substring(3, fixture.storedDescriptor.indexOf(',{'));
    const miniscript = "and_v(v:after(1780012800),pk([B8688DF1/86'/1'/0']$_childXpub/<0;1>/*))";
    final descriptor = Descriptor.parse(_withChecksum('tr($internalKey,$miniscript)')).serialize();

    final result = TaprootLegacyInheritanceMigration.migrate(
      descriptor: descriptor,
      scriptPathSeedInfos: [
        TaprootScriptPathSeedInfo(miniscript: miniscript, extendedPublicKeys: [_childXpub]),
      ],
    );

    expect(result.hasChanges, isFalse);
    expect(result.descriptor, descriptor);
    final wallet = TaprootWallet.fromDescriptor(result.descriptor);
    expect(wallet.policyList.single, isNot(isA<LegacyInheritancePolicy>()));
    expect(wallet.getAddress(0), 'tb1pcnwfgvdym3sewa7cdccscmensvy45lfes4hla3j887ul0lxlzmzqk9n266');
  });
}
