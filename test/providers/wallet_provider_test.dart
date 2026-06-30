import 'dart:ui';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/taproot_script_path_seed_info.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
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
  List<WalletListItemBase> walletItems = [];

  int addTaprootWalletCallCount = 0;
  late TaprootWalletListItem addTaprootWalletResult;
  WatchOnlyWallet? lastTaprootWallet;

  int addSinglesigWalletCallCount = 0;
  late SinglesigWalletListItem addSinglesigWalletResult;

  int addMultisigWalletCallCount = 0;
  late MultisigWalletListItem addMultisigWalletResult;

  int updateWalletUICallCount = 0;

  @override
  Future<List<WalletListItemBase>> getWalletItemList() async => walletItems;

  @override
  Future<TaprootWalletListItem> addTaprootWallet(WatchOnlyWallet watchOnlyWallet) async {
    addTaprootWalletCallCount++;
    lastTaprootWallet = watchOnlyWallet;
    return addTaprootWalletResult;
  }

  @override
  Future<SinglesigWalletListItem> addSinglesigWallet(WatchOnlyWallet watchOnlyWallet) async {
    addSinglesigWalletCallCount++;
    return addSinglesigWalletResult;
  }

  @override
  Future<MultisigWalletListItem> addMultisigWallet(WatchOnlyWallet watchOnlyWallet) async {
    addMultisigWalletCallCount++;
    return addMultisigWalletResult;
  }

  @override
  void updateWalletUI(int id, WatchOnlyWallet watchOnlyWallet) {
    updateWalletUICallCount++;
  }
}

class FakeAddressRepository extends Fake implements AddressRepository {
  @override
  Future<void> ensureAddressesInit({required WalletListItemBase walletItemBase}) async {}
}

class FakeTransactionRepository extends Fake implements TransactionRepository {}

class FakeUtxoRepository extends Fake implements UtxoRepository {}

class FakePreferenceProvider extends Fake implements PreferenceProvider {
  @override
  Future<void> setWalletPreferences(List<WalletListItemBase> walletItemList) async {}

  @override
  bool get isFakeBalanceActive => false;

  @override
  List<int> get walletOrder => [];

  @override
  Future<void> setWalletOrder(List<int> walletOrder) async {}

  @override
  List<int> get favoriteWalletIds => [];

  @override
  Future<void> setFavoriteWalletIds(List<int> ids) async {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

// ─────────────────────────────────────────────
// 테스트 Fixture 헬퍼
// ─────────────────────────────────────────────

SinglesigWalletListItem _createSinglesigWalletListItem({
  int id = 1,
  String name = 'My Wallet',
  int colorIndex = 0,
  int iconIndex = 0,
}) {
  return SinglesigWalletListItem(
    id: id,
    name: name,
    colorIndex: colorIndex,
    iconIndex: iconIndex,
    descriptor: _singlesigDescriptor,
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

MultisigWalletListItem _createMultisigWalletListItem({
  int id = 1,
  String name = 'My Multisig',
  int colorIndex = 0,
  int iconIndex = 0,
}) {
  return MultisigWalletListItem(
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

TaprootWalletListItem _createTaprootWalletListItem({
  int id = 1,
  String name = 'Taproot Wallet',
  int colorIndex = 0,
  int iconIndex = 0,
}) {
  return TaprootWalletListItem(
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
Future<WalletProvider> _buildProvider(FakeWalletRepository walletRepository) async {
  final provider = WalletProvider(
    FakeAddressRepository(),
    FakeTransactionRepository(),
    FakeUtxoRepository(),
    walletRepository,
    (_) async {},
    FakePreferenceProvider(),
  );
  // 생성자 내 _loadWalletListFromDB().then(...) 완료 대기
  await Future.delayed(Duration.zero);
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

      final existingItem = SinglesigWalletListItem(
        id: 1,
        name: 'My Wallet',
        colorIndex: 0,
        iconIndex: 0,
        descriptor: account0Descriptor,
      );
      final walletRepo = FakeWalletRepository()..walletItems = [existingItem];
      walletRepo.addSinglesigWalletResult = SinglesigWalletListItem(
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
