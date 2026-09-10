import 'dart:async';
import 'dart:ui';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────
// Fixture constants (wallet_repository_test.dart와 동일한 값 사용)
// ─────────────────────────────────────────────
const _parentTaprootXpub =
    "tpubDDMbU29QrSafD2Ui4yGv31Xp3PPSMvudreoohYjR8xLTng7hbsjYwUTeRhiKULFqX16M5M8zZh9siw5i6RRyisc6LtWjr1FwBYTiZUGGYJN";
const _childTaprootXpub =
    "tpubDCp2emt17Ng6ujD8BC6ScL4vfwhN3nAJQ8kCqLjRQHxcFhWt6YK5Ws6UcKD6HgLCZuwU8DryKo7h2gpieLa7Q9YF1AqfL9XiF7349nHaLi8";
const _inheritanceMiniscript = "and_v(v:pk([70C4E9DE/86'/1'/0']$_childTaprootXpub/<0;1>/*),older(500000000))";
const _oneParentDescriptor = "tr([9B1441E4/86'/1'/0']$_parentTaprootXpub/<0;1>/*,{$_inheritanceMiniscript})#w0hf4lu5";

const _singlesigDescriptor =
    "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";

const _multisigDescriptor =
    "wsh(sortedmulti(2,[A3B2EB70/48'/1'/0'/2']Vpub5nPDj2f67vDX5FsPMTG9NJZEFWoZVCvdomuuXEtNdtbvMEW6R8Y4AfuvD1v8HEMJ5KV97Y2FkBcpiU1nTmVUEvx4oAUcyrMNayimtFvjGQs/<0;1>/*,[B697ED0C/48'/1'/0'/2']Vpub5m3o8CxnPauiate1UZLcQi45f6q5HnmtZ3tvP2cv5Vtm51LJt5Um51pjkeTYNjd1PZBJ18R5eaYQ8dZdhq2Fit39qNggpkVJyvHj8HzUUe4/<0;1>/*,[F75F5AB5/48'/1'/0'/2']Vpub5nMwPdpQ4ozaJdZQeD2A6A5ci9DwQN6pWKFF3GGuBAK2tewmCB7HMcYsb9iukL2KMNjAgb72HWicwo55kzmnNvyih767HwSUxcv9PPdY8qj/<0;1>/*))#qlqyc9ar";

// ─────────────────────────────────────────────
// Fake 구현체들
// ─────────────────────────────────────────────

class FakeWalletRepository extends Fake implements WalletRepository {
  List<WalletItemBase> walletItems = [];
  List<HotWalletMetadata> hotWalletMetadata = [];
  final List<int> deletedWalletIds = [];
  final List<(int, HotWalletLifecycleState)> lifecycleUpdates = [];
  Object? deleteError;

  int addTaprootWalletCallCount = 0;
  late TaprootWalletItem addTaprootWalletResult;
  WatchOnlyWallet? lastTaprootWallet;

  int addSinglesigWalletCallCount = 0;
  late SinglesigWalletItem addSinglesigWalletResult;

  int addHotWalletCallCount = 0;
  late SinglesigWalletItem addHotWalletResult;
  int promoteWatchOnlyWalletCallCount = 0;
  late SinglesigWalletItem promoteWatchOnlyWalletResult;

  int addMultisigWalletCallCount = 0;
  late MultisigWalletItem addMultisigWalletResult;

  int updateWalletUICallCount = 0;

  @override
  Future<List<WalletItemBase>> getWalletItemList() async => walletItems;

  @override
  List<HotWalletMetadata> getHotWalletMetadataList() => List.unmodifiable(hotWalletMetadata);

  @override
  HotWalletMetadata? getHotWalletMetadata(int walletId) =>
      hotWalletMetadata.where((metadata) => metadata.walletId == walletId).firstOrNull;

  @override
  bool containsWalletName(String name, {int? excludeWalletId}) =>
      walletItems.any((wallet) => wallet.id != excludeWalletId && wallet.name == name);

  @override
  bool containsHotWalletDescriptor(String descriptor) => hotWalletMetadata.any(
    (metadata) => walletItems.any((wallet) => wallet.id == metadata.walletId && wallet.descriptor == descriptor),
  );

  @override
  Future<TaprootWalletItem> addTaprootWallet(WatchOnlyWallet watchOnlyWallet) async {
    addTaprootWalletCallCount++;
    lastTaprootWallet = watchOnlyWallet;
    return addTaprootWalletResult;
  }

  @override
  Future<SinglesigWalletItem> addSinglesigWallet(WatchOnlyWallet watchOnlyWallet) async {
    addSinglesigWalletCallCount++;
    return addSinglesigWalletResult;
  }

  @override
  Future<SinglesigWalletItem> addHotWallet(
    WatchOnlyWallet wallet, {
    required String secureStorageKey,
    required bool backupVerified,
    required bool enterPassphraseWhenSigning,
    required DateTime createdAt,
    HotWalletLifecycleState lifecycleState = HotWalletLifecycleState.creating,
  }) async {
    addHotWalletCallCount++;
    hotWalletMetadata.add(
      HotWalletMetadata(
        walletId: addHotWalletResult.id,
        secureStorageKey: secureStorageKey,
        masterFingerprint: 'D45AA182',
        derivationPath: "m/84'/1'/0'",
        accountIndex: 0,
        backupVerified: backupVerified,
        enterPassphraseWhenSigning: enterPassphraseWhenSigning,
        createdAt: createdAt,
        lifecycleState: lifecycleState,
      ),
    );
    return addHotWalletResult;
  }

  @override
  Future<SinglesigWalletItem> promoteWatchOnlyWalletToHotWallet(
    int walletId, {
    required String expectedDescriptor,
    required String secureStorageKey,
    required bool backupVerified,
    required bool enterPassphraseWhenSigning,
    required DateTime createdAt,
  }) async {
    promoteWatchOnlyWalletCallCount++;
    walletItems[walletItems.indexWhere((wallet) => wallet.id == walletId)] = promoteWatchOnlyWalletResult;
    hotWalletMetadata.add(promoteWatchOnlyWalletResult.hotWalletMetadata!);
    return promoteWatchOnlyWalletResult;
  }

  @override
  Future<void> updateHotWalletLifecycleState(int walletId, HotWalletLifecycleState state) async {
    lifecycleUpdates.add((walletId, state));
    final index = hotWalletMetadata.indexWhere((metadata) => metadata.walletId == walletId);
    final current = hotWalletMetadata[index];
    hotWalletMetadata[index] = HotWalletMetadata(
      walletId: current.walletId,
      secureStorageKey: current.secureStorageKey,
      masterFingerprint: current.masterFingerprint,
      derivationPath: current.derivationPath,
      accountIndex: current.accountIndex,
      backupVerified: current.backupVerified,
      enterPassphraseWhenSigning: current.enterPassphraseWhenSigning,
      createdAt: current.createdAt,
      lifecycleState: state,
    );
    walletItems.removeWhere((wallet) => wallet.id == walletId);
    if (state == HotWalletLifecycleState.active && addHotWalletResult.id == walletId) {
      walletItems.add(addHotWalletResult);
    }
  }

  @override
  Future<void> deleteWallet(int walletId) async {
    deletedWalletIds.add(walletId);
    if (deleteError != null) throw deleteError!;
    walletItems.removeWhere((wallet) => wallet.id == walletId);
    hotWalletMetadata.removeWhere((metadata) => metadata.walletId == walletId);
  }

  @override
  Future<MultisigWalletItem> addMultisigWallet(WatchOnlyWallet watchOnlyWallet) async {
    addMultisigWalletCallCount++;
    return addMultisigWalletResult;
  }

  @override
  void updateWalletUI(int id, WatchOnlyWallet watchOnlyWallet) {
    updateWalletUICallCount++;
  }
}

class FakeAddressRepository extends Fake implements AddressRepository {
  FakeAddressRepository({this.error});

  final Object? error;
  int ensureAddressesInitCallCount = 0;

  @override
  Future<void> ensureAddressesInit({required WalletItemBase walletItemBase}) async {
    ensureAddressesInitCallCount++;
    if (error != null) throw error!;
  }
}

class FakeTransactionRepository extends Fake implements TransactionRepository {}

class FakeUtxoRepository extends Fake implements UtxoRepository {}

class FakePreferenceProvider extends Fake implements PreferenceProvider {
  final List<int> removedWalletIds = [];
  Completer<void>? walletOrderSaveGate;
  Completer<void>? favoriteWalletSaveGate;
  Object? walletOrderSaveError;
  Object? favoriteWalletSaveError;
  int setWalletOrderCallCount = 0;
  int setFavoriteWalletIdsCallCount = 0;
  @override
  Future<void> setWalletPreferences(List<WalletItemBase> walletItemList) async {}

  @override
  bool get isFakeBalanceActive => false;

  @override
  List<int> get walletOrder => [];

  @override
  Future<void> setWalletOrder(List<int> walletOrder) async {
    setWalletOrderCallCount++;
    await walletOrderSaveGate?.future;
    if (walletOrderSaveError != null) throw walletOrderSaveError!;
  }

  @override
  List<int> get favoriteWalletIds => [];

  @override
  Future<void> setFavoriteWalletIds(List<int> ids) async {
    setFavoriteWalletIdsCallCount++;
    await favoriteWalletSaveGate?.future;
    if (favoriteWalletSaveError != null) throw favoriteWalletSaveError!;
  }

  @override
  Future<void> removeWalletOrder(int walletId) async {
    removedWalletIds.add(walletId);
  }

  @override
  Future<void> removeFavoriteWalletId(int walletId) async {
    removedWalletIds.add(walletId);
  }

  @override
  Future<void> removeExcludedFromTotalBalanceWalletId(int walletId) async {
    removedWalletIds.add(walletId);
  }

  @override
  Future<void> removeManualUtxoSelectionWalletId(int walletId) async {
    removedWalletIds.add(walletId);
  }

  @override
  Future<void> changeIsBalanceHidden(bool isOn) async {}

  @override
  Future<void> clearFakeBalanceTotalAmount() async {}

  @override
  Future<void> toggleFakeBalanceActivation(bool isActive) async {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class FakeHotWalletSecretRepository extends Fake implements HotWalletSecretRepository {
  final Set<String> storedKeys;
  final List<String> deletedKeys = [];
  Completer<void>? getKeysGate;
  int getKeysCallCount = 0;
  int containsCallCount = 0;
  int cleanupAliasesCallCount = 0;
  Set<String>? lastAliasCleanupReferencedKeys;

  FakeHotWalletSecretRepository([Set<String>? storedKeys]) : storedKeys = storedKeys ?? {};

  @override
  Future<bool> contains(String storageKey) async {
    containsCallCount++;
    return storedKeys.contains(storageKey);
  }

  @override
  Future<List<String>> getSecretStorageKeys() async {
    getKeysCallCount++;
    await getKeysGate?.future;
    return storedKeys.toList();
  }

  @override
  Future<void> delete(String storageKey) async {
    deletedKeys.add(storageKey);
    storedKeys.remove(storageKey);
  }

  @override
  Future<void> cleanupOrphanHardwareAliases(Set<String> referencedStorageKeys) async {
    cleanupAliasesCallCount++;
    lastAliasCleanupReferencedKeys = Set<String>.of(referencedStorageKeys);
  }
}

class FakeSharedPrefsRepository extends Fake implements SharedPrefsRepository {
  final List<int> removedWalletIds = [];

  @override
  Future<void> removeWalletTargetSats(int walletId) async {
    removedWalletIds.add(walletId);
  }

  @override
  Future<void> removeFaucetHistory(int id) async {
    removedWalletIds.add(id);
  }
}

// ─────────────────────────────────────────────
// 테스트 Fixture 헬퍼
// ─────────────────────────────────────────────

SinglesigWalletItem _createSinglesigWalletListItem({
  int id = 1,
  String name = 'My Wallet',
  int colorIndex = 0,
  int iconIndex = 0,
  bool isHotWallet = false,
}) {
  return SinglesigWalletItem(
    id: id,
    name: name,
    colorIndex: colorIndex,
    iconIndex: iconIndex,
    descriptor: _singlesigDescriptor,
    hotWalletMetadata:
        isHotWallet
            ? HotWalletMetadata(
              walletId: id,
              secureStorageKey: 'local_wallet_seed_$id',
              masterFingerprint: 'D45AA182',
              derivationPath: "m/84'/1'/0'",
              accountIndex: 0,
              backupVerified: true,
              enterPassphraseWhenSigning: false,
              createdAt: DateTime.utc(2026, 7, 20),
            )
            : null,
  );
}

HotWalletMetadata _createHotWalletMetadata({
  int walletId = 1,
  String storageKey = 'local_wallet_seed_1',
  HotWalletLifecycleState lifecycleState = HotWalletLifecycleState.active,
}) {
  return HotWalletMetadata(
    walletId: walletId,
    secureStorageKey: storageKey,
    masterFingerprint: 'D45AA182',
    derivationPath: "m/84'/1'/0'",
    accountIndex: 0,
    backupVerified: true,
    enterPassphraseWhenSigning: false,
    createdAt: DateTime.utc(2026, 7, 20),
    lifecycleState: lifecycleState,
  );
}

WatchOnlyWallet _createSinglesigWatchOnlyWallet({
  String name = 'My Wallet',
  int colorIndex = 0,
  int iconIndex = 0,
  String? descriptor,
}) {
  return WatchOnlyWallet(
    name,
    colorIndex,
    iconIndex,
    descriptor ?? _singlesigDescriptor,
    null,
    null,
    WalletImportSource.coconutVault.name,
  );
}

final _multisigSigners = [
  MultisigSigner(name: 'Signer A', iconIndex: 0, colorIndex: 0, memo: ''),
  MultisigSigner(name: 'Signer B', iconIndex: 1, colorIndex: 1, memo: ''),
  MultisigSigner(name: 'Signer C', iconIndex: 2, colorIndex: 2, memo: ''),
];

MultisigWalletItem _createMultisigWalletListItem({
  int id = 1,
  String name = 'My Multisig',
  int colorIndex = 0,
  int iconIndex = 0,
}) {
  return MultisigWalletItem(
    id: id,
    name: name,
    colorIndex: colorIndex,
    iconIndex: iconIndex,
    descriptor: _multisigDescriptor,
    signers: List.of(_multisigSigners),
    requiredSignatureCount: 2,
  );
}

WatchOnlyWallet _createMultisigWatchOnlyWallet({
  String name = 'My Multisig',
  int colorIndex = 0,
  int iconIndex = 0,
  List<MultisigSigner>? signers,
}) {
  return WatchOnlyWallet(
    name,
    colorIndex,
    iconIndex,
    _multisigDescriptor,
    2,
    signers ?? List.of(_multisigSigners),
    WalletImportSource.coconutVault.name,
  );
}

WatchOnlyWallet _createTaprootWatchOnlyWallet({
  String name = 'Taproot Wallet',
  int colorIndex = 0,
  int iconIndex = 0,
  DateTime? createdAt,
}) {
  return WatchOnlyWallet.fromJson({
    'name': name,
    'colorIndex': colorIndex,
    'iconIndex': iconIndex,
    'descriptor': _oneParentDescriptor,
    'walletImportSource': WalletImportSource.coconutVault.name,
    if (createdAt != null) 'createdAt': createdAt.toIso8601String(),
    'keyPathSeedInfos': [_parentTaprootXpub],
    'scriptPathSeedInfos': [
      {
        'miniscript': _inheritanceMiniscript,
        'extendedPublicKeys': [_childTaprootXpub],
      },
    ],
  });
}

TaprootWalletItem _createTaprootWalletListItem({
  int id = 1,
  String name = 'Taproot Wallet',
  int colorIndex = 0,
  int iconIndex = 0,
}) {
  return TaprootWalletItem(
    id: id,
    name: name,
    colorIndex: colorIndex,
    iconIndex: iconIndex,
    descriptor: _oneParentDescriptor,
    keyPathSeedInfos: [_parentTaprootXpub],
    scriptPathSeedInfos: [
      TaprootScriptPathSeedInfo(miniscript: _inheritanceMiniscript, extendedPublicKeys: [_childTaprootXpub]),
    ],
  );
}

/// WalletProvider를 생성하고 생성자 내부의 비동기 초기화가 완료될 때까지 대기
Future<WalletProvider> _buildProvider(
  FakeWalletRepository walletRepository, {
  FakeAddressRepository? addressRepository,
  FakePreferenceProvider? preferenceProvider,
  FakeHotWalletSecretRepository? secretRepository,
  FakeSharedPrefsRepository? sharedPrefsRepository,
}) async {
  final provider = WalletProvider(
    addressRepository ?? FakeAddressRepository(),
    FakeTransactionRepository(),
    FakeUtxoRepository(),
    walletRepository,
    (_) async {},
    preferenceProvider ?? FakePreferenceProvider(),
    hotWalletSecretRepository: secretRepository ?? FakeHotWalletSecretRepository(),
    sharedPrefsRepository: sharedPrefsRepository ?? FakeSharedPrefsRepository(),
  );
  // 생성자 내 _loadWalletListFromDB().then(...) 완료 대기
  while (provider.walletLoadState != WalletLoadState.loadCompleted) {
    await Future<void>.delayed(Duration.zero);
  }
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return provider;
}

// ─────────────────────────────────────────────
// 테스트
// ─────────────────────────────────────────────

void main() {
  // ───────────────────────────────────────────
  // 탭루트
  // ───────────────────────────────────────────
  group('WalletProvider - syncFromCoconutVault (탭루트)', () {
    test('신규 지갑 추가 시 addTaprootWallet 호출 및 newWalletAdded 반환', () async {
      final createdAt = DateTime.utc(2026, 5, 20, 1, 2, 3);
      final walletRepo = FakeWalletRepository();
      walletRepo.addTaprootWalletResult = _createTaprootWalletListItem();

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(_createTaprootWatchOnlyWallet(createdAt: createdAt));

      expect(result.result, WalletSyncResult.newWalletAdded);
      expect(walletRepo.addTaprootWalletCallCount, 1);
      expect(walletRepo.lastTaprootWallet!.createdAtInVault, createdAt);

      provider.dispose();
    });

    test('기존 지갑 변경 없으면 existingWalletNoUpdate 반환', () async {
      final existingItem = _createTaprootWalletListItem();
      final walletRepo = FakeWalletRepository()..walletItems = [existingItem];

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(_createTaprootWatchOnlyWallet());

      expect(result.result, WalletSyncResult.existingWalletNoUpdate);
      expect(walletRepo.addTaprootWalletCallCount, 0);

      provider.dispose();
    });

    test('기존 지갑 이름 변경 시 updateWalletUI 호출 및 existingWalletUpdated 반환', () async {
      final existingItem = _createTaprootWalletListItem(name: 'Old Name');
      final walletRepo = FakeWalletRepository()..walletItems = [existingItem];

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(_createTaprootWatchOnlyWallet(name: 'New Name'));

      expect(result.result, WalletSyncResult.existingWalletUpdated);
      expect(walletRepo.updateWalletUICallCount, 1);
      expect(walletRepo.addTaprootWalletCallCount, 0);

      provider.dispose();
    });

    test('다른 지갑과 이름 충돌 시 existingName 반환', () async {
      final existingItem = _createSinglesigWalletListItem(name: 'Shared Name');
      final walletRepo = FakeWalletRepository()..walletItems = [existingItem];

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(_createTaprootWatchOnlyWallet(name: 'Shared Name'));

      expect(result.result, WalletSyncResult.existingName);
      expect(walletRepo.addTaprootWalletCallCount, 0);

      provider.dispose();
    });
  });

  // ───────────────────────────────────────────
  // 싱글시그
  // ───────────────────────────────────────────
  group('WalletProvider - syncFromCoconutVault (싱글시그)', () {
    test('신규 지갑 추가 시 addSinglesigWallet 호출 및 newWalletAdded 반환', () async {
      final walletRepo = FakeWalletRepository();
      walletRepo.addSinglesigWalletResult = _createSinglesigWalletListItem();

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(_createSinglesigWatchOnlyWallet());

      expect(result.result, WalletSyncResult.newWalletAdded);
      expect(walletRepo.addSinglesigWalletCallCount, 1);

      provider.dispose();
    });

    test('기존 지갑 변경 없으면 existingWalletNoUpdate 반환', () async {
      final existingItem = _createSinglesigWalletListItem();
      final walletRepo = FakeWalletRepository()..walletItems = [existingItem];

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(_createSinglesigWatchOnlyWallet());

      expect(result.result, WalletSyncResult.existingWalletNoUpdate);
      expect(walletRepo.addSinglesigWalletCallCount, 0);

      provider.dispose();
    });

    test('같은 descriptor의 핫월렛이 있으면 Watch-only 지갑을 추가하지 않고 알림 결과를 반환함', () async {
      final existingHotWallet = _createSinglesigWalletListItem(isHotWallet: true);
      final walletRepo = FakeWalletRepository()..walletItems = [existingHotWallet];
      walletRepo.addSinglesigWalletResult = _createSinglesigWalletListItem(id: 2, name: 'My Wallet Account 0');

      final provider = await _buildProvider(walletRepo);
      final result = await provider.syncFromCoconutVault(_createSinglesigWatchOnlyWallet());

      expect(result.result, WalletSyncResult.existingWalletDifferentType);
      expect(result.walletId, existingHotWallet.id);
      expect(walletRepo.addSinglesigWalletCallCount, 0);

      provider.dispose();
    });

    test('기존 지갑 이름 변경 시 updateWalletUI 호출 및 existingWalletUpdated 반환', () async {
      final existingItem = _createSinglesigWalletListItem(name: 'Old Name');
      final walletRepo = FakeWalletRepository()..walletItems = [existingItem];

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(_createSinglesigWatchOnlyWallet(name: 'New Name'));

      expect(result.result, WalletSyncResult.existingWalletUpdated);
      expect(walletRepo.updateWalletUICallCount, 1);
      expect(walletRepo.addSinglesigWalletCallCount, 0);

      provider.dispose();
    });

    test('이름 충돌 + 다른 MFP(다른 기기) → existingName 반환', () async {
      // MFP가 D45AA182인 기존 지갑
      final existingItem = _createSinglesigWalletListItem(name: 'My Wallet');
      final walletRepo = FakeWalletRepository()..walletItems = [existingItem];

      final provider = await _buildProvider(walletRepo);

      // 완전히 다른 MFP를 가진 새 지갑 (random 생성)
      final differentDescriptor = SingleSignatureVault.random().descriptor;
      final result = await provider.syncFromCoconutVault(
        _createSinglesigWatchOnlyWallet(name: 'My Wallet', descriptor: differentDescriptor),
      );

      expect(result.result, WalletSyncResult.existingName);
      expect(walletRepo.addSinglesigWalletCallCount, 0);

      provider.dispose();
    });

    test('이름 충돌 + 같은 MFP + 다른 account → 자동 이름 생성 후 newWalletAdded 반환', () async {
      // 같은 seed에서 account 0, 1 각각 생성 → MFP 동일, 주소 상이
      final seed = Seed.random();
      final account0Descriptor = SingleSignatureVault.fromSeed(seed, accountIndex: 0).descriptor;
      final account1Descriptor = SingleSignatureVault.fromSeed(seed, accountIndex: 1).descriptor;

      final existingItem = SinglesigWalletItem(
        id: 1,
        name: 'My Wallet',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: account0Descriptor,
      );
      final walletRepo = FakeWalletRepository()..walletItems = [existingItem];
      walletRepo.addSinglesigWalletResult = SinglesigWalletItem(
        id: 2,
        name: 'My Wallet Account 1',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: account1Descriptor,
      );

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(
        _createSinglesigWatchOnlyWallet(name: 'My Wallet', descriptor: account1Descriptor),
      );

      expect(result.result, WalletSyncResult.newWalletAdded);
      expect(walletRepo.addSinglesigWalletCallCount, 1);
      // 이름 충돌이 자동 해소되었음을 확인 (existingName이 아님)

      provider.dispose();
    });
  });

  group('WalletProvider - 핫월렛', () {
    test('SecureStorage reconciliation을 기다리지 않고 Realm의 active 지갑을 먼저 로드함', () async {
      final hotWallet = _createSinglesigWalletListItem(isHotWallet: true);
      final walletRepo =
          FakeWalletRepository()
            ..walletItems = [hotWallet]
            ..hotWalletMetadata = [_createHotWalletMetadata()];
      final secretRepository = FakeHotWalletSecretRepository({'local_wallet_seed_1'})..getKeysGate = Completer<void>();

      final provider = await _buildProvider(walletRepo, secretRepository: secretRepository);

      expect(provider.walletLoadState, WalletLoadState.loadCompleted);
      expect(provider.walletItemList, [hotWallet]);
      expect(secretRepository.getKeysCallCount, 1);
      expect(secretRepository.containsCallCount, 0);

      secretRepository.getKeysGate!.complete();
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      provider.dispose();
    });

    test('같은 descriptor의 Watch-only 지갑이 있어도 핫월렛을 별도로 추가함', () async {
      final existingWatchOnly = _createSinglesigWalletListItem();
      final walletRepo = FakeWalletRepository()..walletItems = [existingWatchOnly];
      walletRepo.addHotWalletResult = _createSinglesigWalletListItem(
        id: 2,
        name: 'My Wallet Account 0',
        isHotWallet: true,
      );

      final provider = await _buildProvider(walletRepo);
      final result = await provider.addHotWallet(
        _createSinglesigWatchOnlyWallet(),
        secureStorageKey: 'local_wallet_seed_new',
        backupVerified: true,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 7, 21),
      );

      expect(result.hasLocalKey, isTrue);
      expect(walletRepo.addHotWalletCallCount, 1);
      expect(walletRepo.lifecycleUpdates, [(2, HotWalletLifecycleState.active)]);
      expect(provider.walletItemList, hasLength(2));

      provider.dispose();
    });

    test('기존 Watch-only 삭제를 선택하면 같은 ID의 핫월렛으로 승격함', () async {
      final existingWatchOnly = _createSinglesigWalletListItem(id: 7, name: 'Existing Watch-only');
      final promotedWallet = _createSinglesigWalletListItem(id: 7, name: 'Existing Watch-only', isHotWallet: true);
      final walletRepo =
          FakeWalletRepository()
            ..walletItems = [existingWatchOnly]
            ..promoteWatchOnlyWalletResult = promotedWallet;
      final addressRepository = FakeAddressRepository();
      final preferenceProvider = FakePreferenceProvider();
      final sharedPrefsRepository = FakeSharedPrefsRepository();
      final provider = await _buildProvider(
        walletRepo,
        addressRepository: addressRepository,
        preferenceProvider: preferenceProvider,
        sharedPrefsRepository: sharedPrefsRepository,
      );

      final result = await provider.addHotWallet(
        _createSinglesigWatchOnlyWallet(name: 'New Restore Name'),
        secureStorageKey: 'local_wallet_seed_promoted',
        backupVerified: true,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 9, 9),
        watchOnlyWalletIdToPromote: existingWatchOnly.id,
      );

      expect(result.id, existingWatchOnly.id);
      expect(result.name, existingWatchOnly.name);
      expect(result.hasLocalKey, isTrue);
      expect(provider.walletItemList, [promotedWallet]);
      expect(walletRepo.promoteWatchOnlyWalletCallCount, 1);
      expect(walletRepo.addHotWalletCallCount, 0);
      expect(walletRepo.deletedWalletIds, isEmpty);
      expect(addressRepository.ensureAddressesInitCallCount, 0);
      expect(preferenceProvider.removedWalletIds, isEmpty);
      expect(sharedPrefsRepository.removedWalletIds, isEmpty);

      provider.dispose();
    });

    test('핫월렛 생성 완료 전에 지갑 순서와 즐겨찾기 저장을 모두 기다림', () async {
      final walletRepo = FakeWalletRepository()..addHotWalletResult = _createSinglesigWalletListItem(isHotWallet: true);
      final preferenceProvider =
          FakePreferenceProvider()
            ..walletOrderSaveGate = Completer<void>()
            ..favoriteWalletSaveGate = Completer<void>();
      final provider = await _buildProvider(walletRepo, preferenceProvider: preferenceProvider);
      var creationCompleted = false;

      final creationFuture = provider
          .addHotWallet(
            _createSinglesigWatchOnlyWallet(),
            secureStorageKey: 'local_wallet_seed_new',
            backupVerified: true,
            enterPassphraseWhenSigning: false,
            createdAt: DateTime.utc(2026, 7, 21),
          )
          .then((wallet) {
            creationCompleted = true;
            return wallet;
          });
      while (preferenceProvider.setWalletOrderCallCount == 0 || preferenceProvider.setFavoriteWalletIdsCallCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(creationCompleted, isFalse);
      preferenceProvider.walletOrderSaveGate!.complete();
      preferenceProvider.favoriteWalletSaveGate!.complete();
      await creationFuture;
      expect(creationCompleted, isTrue);

      provider.dispose();
    });

    test('활성화 후 환경설정 저장이 실패해도 사용 가능한 지갑과 secret을 유지함', () async {
      final activeWallet = _createSinglesigWalletListItem(isHotWallet: true);
      final walletRepo = FakeWalletRepository()..addHotWalletResult = activeWallet;
      final preferenceProvider = FakePreferenceProvider()..walletOrderSaveError = StateError('preference failed');
      final secretRepository = FakeHotWalletSecretRepository();
      final provider = await _buildProvider(
        walletRepo,
        preferenceProvider: preferenceProvider,
        secretRepository: secretRepository,
      );
      secretRepository.storedKeys.add('hot_wallet_secret_preferences');

      final result = await provider.addHotWallet(
        _createSinglesigWatchOnlyWallet(),
        secureStorageKey: 'hot_wallet_secret_preferences',
        backupVerified: false,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 9, 10),
      );

      expect(result.id, activeWallet.id);
      expect(provider.walletItemList, [activeWallet]);
      expect(walletRepo.lifecycleUpdates, [(activeWallet.id, HotWalletLifecycleState.active)]);
      expect(secretRepository.storedKeys, {'hot_wallet_secret_preferences'});
      expect(secretRepository.deletedKeys, isEmpty);

      provider.dispose();
    });

    test('이미 같은 핫월렛이 있으면 중복 추가하지 않음', () async {
      final existingHotWallet = _createSinglesigWalletListItem(isHotWallet: true);
      final walletRepo = FakeWalletRepository()..walletItems = [existingHotWallet];

      final provider = await _buildProvider(walletRepo);

      expect(
        () => provider.addHotWallet(
          _createSinglesigWatchOnlyWallet(),
          secureStorageKey: 'local_wallet_seed_new',
          backupVerified: true,
          enterPassphraseWhenSigning: false,
          createdAt: DateTime.utc(2026, 7, 21),
        ),
        throwsStateError,
      );
      expect(walletRepo.addHotWalletCallCount, 0);

      provider.dispose();
    });

    test('주소 초기화가 실패하면 creating metadata와 secret을 모두 정리함', () async {
      final walletRepo = FakeWalletRepository();
      walletRepo.addHotWalletResult = _createSinglesigWalletListItem(isHotWallet: true);
      final secretRepository = FakeHotWalletSecretRepository({'local_wallet_seed_new'});
      final provider = await _buildProvider(
        walletRepo,
        addressRepository: FakeAddressRepository(error: StateError('address init failed')),
        secretRepository: secretRepository,
      );

      await expectLater(
        provider.addHotWallet(
          _createSinglesigWatchOnlyWallet(),
          secureStorageKey: 'local_wallet_seed_new',
          backupVerified: true,
          enterPassphraseWhenSigning: false,
          createdAt: DateTime.utc(2026, 7, 21),
        ),
        throwsA(isA<StateError>()),
      );

      expect(walletRepo.hotWalletMetadata, isEmpty);
      expect(walletRepo.deletedWalletIds, [1]);
      expect(secretRepository.storedKeys, isEmpty);
      expect(provider.walletItemList, isEmpty);

      provider.dispose();
    });

    test('앱 시작 시 creating 지갑과 연결된 secret·설정을 정리함', () async {
      final walletRepo =
          FakeWalletRepository()
            ..hotWalletMetadata = [_createHotWalletMetadata(lifecycleState: HotWalletLifecycleState.creating)];
      final secretRepository = FakeHotWalletSecretRepository({'local_wallet_seed_1'});
      final preferenceProvider = FakePreferenceProvider();
      final sharedPrefsRepository = FakeSharedPrefsRepository();

      final provider = await _buildProvider(
        walletRepo,
        preferenceProvider: preferenceProvider,
        secretRepository: secretRepository,
        sharedPrefsRepository: sharedPrefsRepository,
      );

      expect(provider.walletItemList, isEmpty);
      expect(walletRepo.hotWalletMetadata, isEmpty);
      expect(secretRepository.storedKeys, isEmpty);
      expect(preferenceProvider.removedWalletIds, contains(1));
      expect(sharedPrefsRepository.removedWalletIds, contains(1));

      provider.dispose();
    });

    test('active metadata에 연결된 secret이 없으면 recoveryRequired로 변경하고 목록에서 제외함', () async {
      final hotWallet = _createSinglesigWalletListItem(isHotWallet: true);
      final walletRepo =
          FakeWalletRepository()
            ..walletItems = [hotWallet]
            ..hotWalletMetadata = [_createHotWalletMetadata()];

      final provider = await _buildProvider(walletRepo);

      expect(provider.walletItemList, isEmpty);
      expect(walletRepo.hotWalletMetadata.single.lifecycleState, HotWalletLifecycleState.recoveryRequired);

      provider.dispose();
    });

    test('recoveryRequired 지갑의 secret이 복구되면 active로 복귀시키고 목록에 포함함', () async {
      final hotWallet = _createSinglesigWalletListItem(isHotWallet: true);
      final walletRepo =
          FakeWalletRepository()
            ..addHotWalletResult = hotWallet
            ..hotWalletMetadata = [_createHotWalletMetadata(lifecycleState: HotWalletLifecycleState.recoveryRequired)];

      final provider = await _buildProvider(
        walletRepo,
        secretRepository: FakeHotWalletSecretRepository({'local_wallet_seed_1'}),
      );

      expect(walletRepo.hotWalletMetadata.single.lifecycleState, HotWalletLifecycleState.active);
      expect(provider.walletItemList, [hotWallet]);

      provider.dispose();
    });

    test('앱 시작 시 Realm에서 참조하지 않는 orphan secret을 정리함', () async {
      final secretRepository = FakeHotWalletSecretRepository({'hot_wallet_secret_orphan'});

      final provider = await _buildProvider(FakeWalletRepository(), secretRepository: secretRepository);

      expect(secretRepository.storedKeys, isEmpty);
      expect(secretRepository.deletedKeys, ['hot_wallet_secret_orphan']);

      provider.dispose();
    });

    test('앱 시작 시 현재 Realm metadata가 참조하는 key를 기준으로 orphan alias 정리를 요청함', () async {
      final hotWallet = _createSinglesigWalletListItem(isHotWallet: true);
      final walletRepo =
          FakeWalletRepository()
            ..walletItems = [hotWallet]
            ..hotWalletMetadata = [_createHotWalletMetadata()];
      final secretRepository = FakeHotWalletSecretRepository({'local_wallet_seed_1'});

      final provider = await _buildProvider(walletRepo, secretRepository: secretRepository);
      for (var i = 0; i < 5 && secretRepository.cleanupAliasesCallCount == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(secretRepository.cleanupAliasesCallCount, 1);
      expect(secretRepository.lastAliasCleanupReferencedKeys, {'local_wallet_seed_1'});
      provider.dispose();
    });

    test('삭제 중 Realm 삭제가 실패하면 deleting 상태로 숨기고 다음 시작에서 정리함', () async {
      final hotWallet = _createSinglesigWalletListItem(isHotWallet: true);
      final walletRepo =
          FakeWalletRepository()
            ..addHotWalletResult = hotWallet
            ..walletItems = [hotWallet]
            ..hotWalletMetadata = [_createHotWalletMetadata()];
      final secretRepository = FakeHotWalletSecretRepository({'local_wallet_seed_1'});
      final provider = await _buildProvider(walletRepo, secretRepository: secretRepository);
      walletRepo.deleteError = StateError('realm delete failed');

      await expectLater(provider.deleteWallet(1), throwsA(isA<StateError>()));

      expect(walletRepo.hotWalletMetadata.single.lifecycleState, HotWalletLifecycleState.deleting);
      expect(provider.walletItemList, isEmpty);
      expect(secretRepository.storedKeys, {'local_wallet_seed_1'});
      provider.dispose();

      walletRepo.deleteError = null;
      final restartedProvider = await _buildProvider(walletRepo, secretRepository: secretRepository);

      expect(walletRepo.hotWalletMetadata, isEmpty);
      expect(secretRepository.storedKeys, isEmpty);
      expect(restartedProvider.walletItemList, isEmpty);

      restartedProvider.dispose();
    });
  });

  // ───────────────────────────────────────────
  // 멀티시그
  // ───────────────────────────────────────────
  group('WalletProvider - syncFromCoconutVault (멀티시그)', () {
    test('신규 지갑 추가 시 addMultisigWallet 호출 및 newWalletAdded 반환', () async {
      final walletRepo = FakeWalletRepository();
      walletRepo.addMultisigWalletResult = _createMultisigWalletListItem();

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(_createMultisigWatchOnlyWallet());

      expect(result.result, WalletSyncResult.newWalletAdded);
      expect(walletRepo.addMultisigWalletCallCount, 1);

      provider.dispose();
    });

    test('기존 지갑 변경 없으면 existingWalletNoUpdate 반환', () async {
      final existingItem = _createMultisigWalletListItem();
      final walletRepo = FakeWalletRepository()..walletItems = [existingItem];

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(_createMultisigWatchOnlyWallet());

      expect(result.result, WalletSyncResult.existingWalletNoUpdate);
      expect(walletRepo.addMultisigWalletCallCount, 0);

      provider.dispose();
    });

    test('이름 충돌 시 existingName 반환', () async {
      final existingItem = _createSinglesigWalletListItem(name: 'Shared Name');
      final walletRepo = FakeWalletRepository()..walletItems = [existingItem];

      final provider = await _buildProvider(walletRepo);

      final result = await provider.syncFromCoconutVault(_createMultisigWatchOnlyWallet(name: 'Shared Name'));

      expect(result.result, WalletSyncResult.existingName);
      expect(walletRepo.addMultisigWalletCallCount, 0);

      provider.dispose();
    });
  });
}
