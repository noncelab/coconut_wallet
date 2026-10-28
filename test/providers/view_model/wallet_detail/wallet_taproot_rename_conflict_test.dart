import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_appearance_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_edit_view_model.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Same strings as test/model/wallet/taproot_wallet_list_item_test.dart.
const _parentTaprootXpub =
    'tpubDDMbU29QrSafD2Ui4yGv31Xp3PPSMvudreoohYjR8xLTng7hbsjYwUTeRhiKULFqX16M5M8zZh9siw5i6RRyisc6LtWjr1FwBYTiZUGGYJN';
const _childTaprootXpub =
    'tpubDCp2emt17Ng6ujD8BC6ScL4vfwhN3nAJQ8kCqLjRQHxcFhWt6YK5Ws6UcKD6HgLCZuwU8DryKo7h2gpieLa7Q9YF1AqfL9XiF7349nHaLi8';
const _inheritanceMiniscript = "and_v(v:pk([70C4E9DE/86'/1'/0']$_childTaprootXpub/<0;1>/*),after(500000000))";
const _oneParentDescriptor = "tr([9B1441E4/86'/1'/0']$_parentTaprootXpub/<0;1>/*,{$_inheritanceMiniscript})#652j50l8";

// Same singlesig descriptor as WalletMock.createSingleSigWalletItem.
const _singlesigDescriptor =
    "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";

const _accountZeroName = 'One Parent Taproot';
const _accountOneName = 'Account One Taproot';
const _watchName = 'Shared Watch';
const _hotName = 'Hot Sibling';
const _freshName = 'Fresh Taproot';

class _WalletRepository extends Fake implements WalletRepository {
  _WalletRepository(this.items);

  final List<WalletItemBase> items;

  @override
  Future<List<WalletItemBase>> getWalletItemList() async => items;

  @override
  List<HotWalletMetadata> getHotWalletMetadataList() => const [];
}

class _AddressRepository extends Fake implements AddressRepository {}

class _TransactionRepository extends Fake implements TransactionRepository {}

class _UtxoRepository extends Fake implements UtxoRepository {}

class _Secrets extends Fake implements HotWalletSecretRepository {
  @override
  Future<List<String>> getSecretStorageKeys() async => const [];
}

class _Preferences extends Fake implements PreferenceProvider {
  @override
  Future<void> setWalletPreferences(List<WalletItemBase> walletItemList) async {}
}

class _Appearances extends Fake implements WalletAppearanceProvider {
  @override
  WalletBackground? backgroundOf(int walletId) => null;
}

String _descriptorForAccount(int account) {
  final body = _oneParentDescriptor.split('#').first.replaceAll("86'/1'/0'", "86'/1'/$account'");
  return '$body#${Checksum.getChecksum(body)}';
}

TaprootWalletItem _taprootItem({
  required int id,
  required String name,
  required String descriptor,
  required String miniscript,
}) {
  return TaprootWalletItem(
    id: id,
    name: name,
    colorIndex: 2,
    iconIndex: 3,
    descriptor: descriptor,
    keyPathSeedInfos: const [_parentTaprootXpub],
    scriptPathSeedInfos: [
      TaprootScriptPathSeedInfo(miniscript: miniscript, extendedPublicKeys: const [_childTaprootXpub]),
    ],
  );
}

SinglesigWalletItem _watchItem() {
  return SinglesigWalletItem(id: 3, name: _watchName, colorIndex: 1, iconIndex: 1, descriptor: _singlesigDescriptor);
}

SinglesigWalletItem _hotItem() {
  return SinglesigWalletItem(
    id: 4,
    name: _hotName,
    colorIndex: 1,
    iconIndex: 2,
    descriptor: _singlesigDescriptor,
    hotWalletMetadata: HotWalletMetadata(
      walletId: 4,
      secureStorageKey: 'taproot-rename-hot',
      masterFingerprint: 'D45AA182',
      derivationPath: "m/84'/1'/0'",
      accountIndex: 0,
      backupVerified: true,
      enterPassphraseWhenSigning: false,
      createdAt: DateTime.utc(2026, 5, 20),
    ),
  );
}

int _accountIndex(WalletItemBase item) {
  final segments = (item.walletBase as TaprootWallet).derivationPath.split('/');
  return int.parse(segments[3].replaceAll(RegExp(r"['hH]"), ''));
}

Future<WalletProvider> _openProvider(List<WalletItemBase> items) async {
  final provider = WalletProvider(
    _AddressRepository(),
    _TransactionRepository(),
    _UtxoRepository(),
    _WalletRepository(items),
    (_) async {},
    _Preferences(),
    hotWalletSecretRepository: _Secrets(),
  );
  while (provider.walletLoadState != WalletLoadState.loadCompleted) {
    await Future<void>.delayed(Duration.zero);
  }
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return provider;
}

void main() {
  late NetworkType previousNetwork;
  late WalletProvider provider;
  late TaprootWalletItem accountZero;
  late TaprootWalletItem accountOne;
  late SinglesigWalletItem watchWallet;
  late SinglesigWalletItem hotWallet;
  final accountOneMiniscript = _inheritanceMiniscript.replaceAll("86'/1'/0'", "86'/1'/1'");

  setUpAll(() async {
    previousNetwork = NetworkType.currentNetworkType;
    NetworkType.setNetworkType(NetworkType.testnet);
    accountZero = _taprootItem(
      id: 1,
      name: _accountZeroName,
      descriptor: _oneParentDescriptor,
      miniscript: _inheritanceMiniscript,
    );
    accountOne = _taprootItem(
      id: 8,
      name: _accountOneName,
      descriptor: _descriptorForAccount(1),
      miniscript: accountOneMiniscript,
    );
    watchWallet = _watchItem();
    hotWallet = _hotItem();
    provider = await _openProvider([accountZero, accountOne, watchWallet, hotWallet]);
  });

  tearDownAll(() {
    provider.dispose();
    NetworkType.setNetworkType(previousNetwork);
  });

  WalletAppearanceViewModel appearanceOf(int id) {
    return WalletAppearanceViewModel(id, provider, _Preferences(), _Appearances());
  }

  WalletInfoEditViewModel infoEditOf(int id) {
    return WalletInfoEditViewModel(id, provider);
  }

  group('editable Taproot rename', () {
    test('appearance updateName accepts a unique name and rejects a real conflict', () {
      expect(_accountIndex(accountOne), 1);
      expect(accountOne.descriptor, _descriptorForAccount(1));
      expect(accountOne.keyPathSeedInfos, [_parentTaprootXpub]);
      expect(accountOne.scriptPathSeedInfos.single.extendedPublicKeys, [_childTaprootXpub]);
      expect(accountOne.scriptPathSeedInfos.single.miniscript, accountOneMiniscript);
      expect(accountOne.walletImportSource, WalletImportSource.coconutVault);

      final viewModel = appearanceOf(accountOne.id);
      expect(viewModel.canEditName, isTrue);
      expect(viewModel.tabs, contains(WalletAppearanceTab.wallet));

      var notifications = 0;
      viewModel.addListener(() => notifications++);
      viewModel.updateName(_freshName);

      expect(notifications, 1);
      expect(viewModel.name, _freshName);
      expect(viewModel.isNameDuplicated, isFalse);
      expect(viewModel.isNameValid, isTrue);
      expect(accountOne.descriptor, _descriptorForAccount(1));
      expect(accountOne.name, _accountOneName);
      expect(accountOne.keyPathSeedInfos, [_parentTaprootXpub]);
      expect(accountOne.scriptPathSeedInfos.single.miniscript, accountOneMiniscript);

      viewModel.updateName(_watchName);
      expect(viewModel.isNameDuplicated, isTrue);
      expect(viewModel.isNameValid, isFalse);
      expect(accountOne.descriptor, _descriptorForAccount(1));

      viewModel.updateName(_accountOneName);
      expect(viewModel.isNameDuplicated, isFalse);
      expect(notifications, 3);
    });

    test('info edit checkValidity accepts a unique Taproot name and rejects a conflict', () {
      final viewModel = infoEditOf(accountOne.id);
      expect(viewModel.walletName, _accountOneName);

      var notifications = 0;
      viewModel.addListener(() => notifications++);
      viewModel.checkValidity(_freshName);

      expect(notifications, 1);
      expect(viewModel.isNameDuplicated, isFalse);
      expect(viewModel.isSameAsCurrentName, isFalse);
      expect(viewModel.canUpdateName, isTrue);
      expect(accountOne.descriptor, _descriptorForAccount(1));
      expect(accountOne.name, _accountOneName);
      expect(accountOne.keyPathSeedInfos, [_parentTaprootXpub]);
      expect(accountOne.scriptPathSeedInfos.single.extendedPublicKeys, [_childTaprootXpub]);

      viewModel.checkValidity(_watchName);
      expect(viewModel.isNameDuplicated, isTrue);
      expect(viewModel.canUpdateName, isFalse);

      viewModel.checkValidity('  $_accountOneName  ');
      expect(viewModel.isSameAsCurrentName, isTrue);
      expect(viewModel.isNameDuplicated, isFalse);
      expect(notifications, 3);
    });
  });

  group('WalletProvider.resolveWalletNameConflict', () {
    test('account 0 fixture checksum round-trips and is not an editable vault name', () {
      expect(_descriptorForAccount(0), _oneParentDescriptor);
      expect(_accountIndex(accountZero), 0);
      expect(accountZero.descriptor, _oneParentDescriptor);
      expect(accountZero.keyPathSeedInfos, [_parentTaprootXpub]);
      expect(accountZero.scriptPathSeedInfos.single.miniscript, _inheritanceMiniscript);
      expect(accountZero.scriptPathSeedInfos.single.extendedPublicKeys, [_childTaprootXpub]);

      final viewModel = appearanceOf(accountZero.id);
      expect(viewModel.canEditName, isFalse);
      expect(viewModel.canEditPalette, isFalse);
      expect(viewModel.tabs, isNot(contains(WalletAppearanceTab.wallet)));
    });

    test('isSingleSig true parses the fixture tr() descriptor and throws', () {
      expect(
        () => provider.resolveWalletNameConflict(
          desiredName: _freshName,
          descriptor: _oneParentDescriptor,
          isSingleSig: true,
          excludeWalletId: accountZero.id,
        ),
        throwsA(anything),
      );
    });

    test('isSingleSig false keeps a unique Taproot name and rejects a duplicate', () {
      expect(
        provider.resolveWalletNameConflict(
          desiredName: _freshName,
          descriptor: accountOne.descriptor,
          isSingleSig: false,
          excludeWalletId: accountOne.id,
        ),
        _freshName,
      );
      expect(
        provider.resolveWalletNameConflict(
          desiredName: _watchName,
          descriptor: accountOne.descriptor,
          isSingleSig: false,
          excludeWalletId: accountOne.id,
        ),
        isNull,
      );
      expect(
        provider.resolveWalletNameConflict(
          desiredName: _accountZeroName,
          descriptor: accountOne.descriptor,
          isSingleSig: false,
          excludeWalletId: accountZero.id,
        ),
        _accountZeroName,
      );
      expect(accountZero.descriptor, _oneParentDescriptor);
      expect(accountOne.descriptor, _descriptorForAccount(1));
    });

    test('same-address hot and watch singlesig wallets may share a name', () {
      expect(watchWallet.walletBase.getAddress(0), hotWallet.walletBase.getAddress(0));
      expect(watchWallet.descriptor, _singlesigDescriptor);
      expect(hotWallet.descriptor, _singlesigDescriptor);
      expect(hotWallet.hasLocalKey, isTrue);
      expect(watchWallet.hasLocalKey, isFalse);

      expect(
        provider.resolveWalletNameConflict(
          desiredName: _hotName,
          descriptor: _singlesigDescriptor,
          isSingleSig: true,
          excludeWalletId: watchWallet.id,
        ),
        _hotName,
      );
      expect(
        provider.resolveWalletNameConflict(
          desiredName: _watchName,
          descriptor: _singlesigDescriptor,
          isSingleSig: true,
          excludeWalletId: hotWallet.id,
        ),
        _watchName,
      );
      expect(
        provider.resolveWalletNameConflict(
          desiredName: _accountZeroName,
          descriptor: _singlesigDescriptor,
          isSingleSig: true,
          excludeWalletId: watchWallet.id,
        ),
        isNull,
      );
    });
  });

  group('singlesig rename still uses the real conflict helper', () {
    test('appearance lets a hot wallet take the same-address watch name and rejects another wallet', () {
      final viewModel = appearanceOf(hotWallet.id);
      expect(viewModel.canEditName, isTrue);

      var notifications = 0;
      viewModel.addListener(() => notifications++);
      viewModel.updateName(_watchName);
      expect(notifications, 1);
      expect(viewModel.isNameDuplicated, isFalse);

      viewModel.updateName(_accountZeroName);
      expect(viewModel.isNameDuplicated, isTrue);
      expect(hotWallet.descriptor, _singlesigDescriptor);
      expect(hotWallet.name, _hotName);
    });

    test('info edit on the watch wallet keeps same-address sharing and exclude-self', () {
      final viewModel = infoEditOf(watchWallet.id);
      viewModel.checkValidity(_hotName);
      expect(viewModel.isNameDuplicated, isFalse);
      expect(viewModel.canUpdateName, isTrue);

      viewModel.checkValidity(_watchName);
      expect(viewModel.isNameDuplicated, isFalse);
      expect(viewModel.isSameAsCurrentName, isTrue);

      viewModel.checkValidity(_accountOneName);
      expect(viewModel.isNameDuplicated, isTrue);
      expect(watchWallet.descriptor, _singlesigDescriptor);
      expect(watchWallet.name, _watchName);
    });
  });
}
