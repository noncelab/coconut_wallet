import 'dart:async';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/ark/ark_board.dart';
import 'package:coconut_wallet/model/ark/ark_payment.dart';
import 'package:coconut_wallet/model/ark/ark_snapshot.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/ark_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/model/ark/ark_balance.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/ark/ark_wallet_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mock/ark/ark_fixtures.dart';
import '../repository/realm/test_realm_manager.dart';

const _descriptor =
    "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";
const _fingerprint = 'D45AA182';

class _FakeWalletProvider extends Fake implements WalletProvider {
  _FakeWalletProvider(List<WalletItemBase> wallets) : walletItemListNotifier = ValueNotifier(wallets);

  @override
  final ValueNotifier<List<WalletItemBase>> walletItemListNotifier;

  @override
  List<WalletItemBase> get walletItemList => walletItemListNotifier.value;

  @override
  Future<T> runHotWalletLifecycleOperation<T>(Future<T> Function() operation) => operation();

  @override
  void setOffchainBalanceSource(int Function(int walletId)? offchainBalanceOf) {}

  @override
  final ValueNotifier<BlockTimestamp?> currentBlockHeightNotifier = ValueNotifier(null);
}

class _FakeArkWalletService extends Fake implements ArkWalletService {
  final Set<String> openWallets = {};
  final Set<String> onDisk = {};
  final List<String> calls = [];
  ArkSnapshot nextSnapshot = createArkSnapshot();
  Object? syncRoundsError;
  Completer<void>? syncRoundsGate;
  Object? moveError;
  int fundingAddressCalls = 0;
  int? requiredRefreshHeight;
  List<String> overdueVtxoIds = [];

  @override
  bool get isEnabled => true;

  @override
  bool isOpen(String fingerprint) => openWallets.contains(fingerprint.toLowerCase());

  @override
  Future<bool> exists(String fingerprint) async => onDisk.contains(fingerprint.toLowerCase());

  @override
  Future<void> open(String fingerprint, String seedHex) async {
    calls.add('open');
    openWallets.add(fingerprint.toLowerCase());
  }

  @override
  Future<void> create(String fingerprint, String seedHex, {required bool restore}) async {
    calls.add('create(restore: $restore)');
    openWallets.add(fingerprint.toLowerCase());
    onDisk.add(fingerprint.toLowerCase());
  }

  @override
  Future<List<String>> listFingerprints() async => onDisk.toList();

  @override
  Future<void> delete(String fingerprint) async {
    calls.add('delete');
    openWallets.remove(fingerprint.toLowerCase());
    onDisk.remove(fingerprint.toLowerCase());
  }

  @override
  Future<int?> nextRequiredRefreshHeight(String fingerprint) async => requiredRefreshHeight;

  @override
  Future<List<String>> vtxoIdsToRefresh(String fingerprint) async => overdueVtxoIds;

  @override
  Future<void> syncAndProgressRounds(String fingerprint) async {
    calls.add('syncAndProgressRounds');
    await syncRoundsGate?.future;
    if (syncRoundsError != null) throw syncRoundsError!;
  }

  @override
  Future<bark.BoardFundingInfo> boardFundingAddress(String fingerprint) async {
    fundingAddressCalls++;
    return bark.BoardFundingInfo(address: 'bcrt1pfunding$fundingAddressCalls', expiryHeight: 9000, keypairIndex: 7);
  }

  @override
  Future<bark.PendingBoard> boardPsbt(
    String fingerprint, {
    required String psbtBase64,
    required int keypairIndex,
    required int expiryHeight,
  }) async {
    calls.add('boardPsbt($psbtBase64, $keypairIndex, $expiryHeight)');
    return bark.PendingBoard(vtxoId: 'board:0', amountSats: 100000, txid: 'tx');
  }

  @override
  Future<int?> sendArkoorPayment(String fingerprint, String address, int amountSats) async {
    calls.add('ark($address, $amountSats)');
    return 11;
  }

  int staleTipRejections = 0;

  @override
  Future<int?> payLightningInvoice(String fingerprint, String invoice, {int? amountSats}) async {
    calls.add('invoice($invoice, $amountSats)');
    if (staleTipRejections > 0) {
      staleTipRejections--;
      throw ArkPaymentException(Exception('error making payment: bad user input: requested expiry is too low'));
    }
    return 12;
  }

  @override
  Future<int?> sendOnchainTracked(String fingerprint, String address, int amountSats) async {
    calls.add('onchain($address, $amountSats)');
    if (moveError != null) throw ArkPaymentException(moveError!);
    return 13;
  }

  @override
  Future<String> sendOnchain(String fingerprint, String address, int amountSats) async {
    calls.add('sendOnchain($address, $amountSats)');
    if (moveError != null) throw moveError!;
    return 'txid';
  }

  @override
  Future<void> sync(String fingerprint) async => calls.add('sync');

  @override
  Future<void> refreshDelegated(String fingerprint, List<String> vtxoIds) async =>
      calls.add('refreshDelegated(${vtxoIds.join(',')})');

  @override
  Future<ArkSnapshot> snapshot(String fingerprint, {String? address, int? addressIndex}) async {
    calls.add('snapshot(address: $address)');
    return nextSnapshot;
  }
}

SinglesigWalletItem _hotWallet(int id) => SinglesigWalletItem(
  id: id,
  name: 'Hot $id',
  colorIndex: 0,
  iconIndex: 0,
  descriptor: _descriptor,
  hotWalletMetadata: HotWalletMetadata(
    walletId: id,
    secureStorageKey: 'hot_wallet_secret_$id',
    masterFingerprint: _fingerprint,
    derivationPath: "m/84'/1'/0'",
    accountIndex: 0,
    backupVerified: true,
    enterPassphraseWhenSigning: false,
    createdAt: DateTime.utc(2026, 10, 19),
  ),
);

void main() {
  late TestRealmManager realmManager;
  late ArkRepository arkRepository;
  late _FakeArkWalletService arkService;
  late _FakeWalletProvider walletProvider;
  late ArkProvider arkProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // ignore: deprecated_member_use_from_same_package
    SharedPrefsRepository().setSharedPreferencesForTest(await SharedPreferences.getInstance());
    realmManager = await setupTestRealmManager();
    realmManager.realm.write(() {
      realmManager.realm.add(RealmWalletBase(1, 0, 0, _descriptor, 'Hot 1', WalletType.singleSignature.name));
      realmManager.realm.add(
        RealmHotWalletMetadata(
          1,
          'hot_wallet_secret_1',
          _fingerprint,
          "m/84'/1'/0'",
          0,
          true,
          false,
          DateTime.utc(2026, 10, 19),
          HotWalletLifecycleState.active.name,
        ),
      );
    });
    arkRepository = ArkRepository(realmManager);
    arkService = _FakeArkWalletService()..onDisk.add(_fingerprint.toLowerCase());
    walletProvider = _FakeWalletProvider([_hotWallet(1)]);
    arkProvider = ArkProvider(walletProvider, arkRepository, arkWalletService: arkService, startTimer: false);
    await pumpEventQueue();
  });

  tearDown(() async {
    // Let syncs started by an unlock finish before the Realm closes.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    arkProvider.dispose();
    realmManager.reset();
    realmManager.dispose();
  });

  test('a locked wallet shows its cached snapshot', () async {
    await arkRepository.saveSnapshot(1, createArkSnapshot());

    expect(arkProvider.isOpen(1), isFalse);
    expect(arkProvider.totalSats(1), 50000);
    expect(arkProvider.snapshot(1)!.vtxos, hasLength(1));
  });

  test('a sync writes the snapshot to Realm and keeps the shown address', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());
    await arkRepository.saveSnapshot(1, createArkSnapshot(address: 'tark1shown'));
    arkService.nextSnapshot = createArkSnapshot(
      address: 'tark1shown',
      vtxos: [createArkVtxo(), createArkVtxo(id: 'b:0')],
    );

    await arkProvider.syncNow(1);

    expect(arkService.calls, ['syncAndProgressRounds', 'snapshot(address: tark1shown)']);
    expect(arkRepository.getSnapshot(1)!.vtxos, hasLength(2));
    expect(arkProvider.snapshot(1)!.vtxos, hasLength(2));
  });

  test('a failed server sync still refreshes the cache from bark', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());
    arkService.syncRoundsError = Exception('server unreachable');

    await arkProvider.syncNow(1);

    expect(arkProvider.syncError(1), contains('server unreachable'));
    expect(arkRepository.getSnapshot(1), isNotNull);
  });

  test('a locked wallet is not synced', () async {
    await arkProvider.syncNow(1);

    expect(arkService.calls, isEmpty);
  });

  test('cancelling the unlock leaves the wallet locked and stops automatic prompts', () async {
    expect(arkProvider.shouldAutoUnlock(1), isTrue);

    final opened = await arkProvider.open(1, () async => null);

    expect(opened, isFalse);
    expect(arkProvider.isOpen(1), isFalse);
    expect(arkProvider.shouldAutoUnlock(1), isFalse);
    expect(arkService.calls, isEmpty);
  });

  test('unlocking opens the Ark wallet the user turned on', () async {
    expect(await arkProvider.open(1, () async => 'ab' * 64), isTrue);
    expect(arkService.calls.first, 'open');
    expect(arkProvider.isOpen(1), isTrue);
  });

  test('a hot wallet without Ark has no Ark side until turned on, then recovers this seed', () async {
    arkService.onDisk.clear();
    walletProvider.walletItemListNotifier.value = [_hotWallet(1)];
    await pumpEventQueue();

    expect(arkProvider.canUseArk(_hotWallet(1)), isTrue);
    expect(arkProvider.supportsArkById(1), isFalse);
    expect(arkProvider.shouldAutoUnlock(1), isFalse);

    expect(await arkProvider.turnOn(1, () async => 'ab' * 64), isTrue);
    expect(arkService.calls.first, 'create(restore: true)');
    expect(arkProvider.supportsArkById(1), isTrue);
  });

  test('Ark cannot be turned off while it holds funds', () async {
    await arkRepository.saveSnapshot(1, createArkSnapshot());

    expect(arkProvider.canTurnOff(1), isFalse);
    expect(() => arkProvider.turnOff(1), throwsStateError);
  });

  test('turning Ark off with no funds removes its data and cache', () async {
    await arkRepository.saveSnapshot(1, createArkSnapshot(balance: ArkBalance.zero));

    await arkProvider.turnOff(1);

    expect(arkService.calls, ['delete']);
    expect(arkProvider.supportsArkById(1), isFalse);
    expect(arkRepository.getSnapshot(1), isNull);
  });

  test('VTXOs within the notice window are due, others are not', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());
    walletProvider.currentBlockHeightNotifier.value = BlockTimestamp(4000, DateTime.utc(2026, 11, 12));
    arkService.nextSnapshot = createArkSnapshot(
      vtxos: [createArkVtxo(id: 'soon:0', expiryHeight: 4500), createArkVtxo(id: 'later:0', expiryHeight: 9000)],
    );

    await arkProvider.syncNow(1);

    final due = arkProvider.refreshDue(1);
    expect(due.vtxoIds, ['soon:0']);
    expect(due.blocksLeft, 500);
    expect(arkService.calls.where((call) => call.startsWith('refreshDelegated')), isEmpty);
  });

  test('past the refresh deadline, overdue VTXOs are refreshed automatically when allowed', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());
    walletProvider.currentBlockHeightNotifier.value = BlockTimestamp(4990, DateTime.utc(2026, 11, 12));
    arkService.requiredRefreshHeight = 4856;
    arkService.overdueVtxoIds = ['vtxo1:0'];

    await arkProvider.syncNow(1);

    expect(arkService.calls, contains('refreshDelegated(vtxo1:0)'));
  });

  test('no automatic refresh when the user turned it off', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());
    walletProvider.currentBlockHeightNotifier.value = BlockTimestamp(4990, DateTime.utc(2026, 11, 12));
    arkService.requiredRefreshHeight = 4856;
    arkService.overdueVtxoIds = ['vtxo1:0'];
    await arkProvider.setAutoRefreshOn(1, false);

    await arkProvider.syncNow(1);

    expect(arkService.calls.where((call) => call.startsWith('refreshDelegated')), isEmpty);
    expect(arkProvider.refreshDue(1).vtxoIds, ['vtxo1:0']);
  });

  test('concurrent unlock requests share one prompt', () async {
    var prompts = 0;
    Future<String?> unlock() async {
      prompts++;
      return 'ab' * 64;
    }

    final results = await Future.wait([arkProvider.open(1, unlock), arkProvider.open(1, unlock)]);

    expect(results, [true, true]);
    expect(prompts, 1);
  });

  test('a delegated refresh is followed by a light sync', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());

    await arkProvider.refreshDelegated(1, ['a:0', 'b:1']);

    expect(arkService.calls, ['refreshDelegated(a:0,b:1)', 'sync', 'snapshot(address: null)']);
  });

  test('a sync requested during a sync runs after it', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());
    arkService.syncRoundsGate = Completer<void>();

    final first = arkProvider.syncNow(1);
    await arkProvider.syncNow(1, withRounds: false);
    expect(arkService.calls, ['syncAndProgressRounds']);

    arkService.syncRoundsGate!.complete();
    await first;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(arkService.calls, [
      'syncAndProgressRounds',
      'snapshot(address: null)',
      'sync',
      'snapshot(address: tark1pwh9vsmezqqpjy9akejayl2vvcse6he97rn40g84xrlvrlnhayuuyefrp9nse2y3zqqpj)',
    ]);
  });

  test('the board funding address is reused until a board succeeds', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());

    final first = await arkProvider.boardFunding(1);
    final again = await arkProvider.boardFunding(1);
    expect(again.address, first.address);
    expect(arkService.fundingAddressCalls, 1);

    await arkProvider.board(1, unsignedPsbtBase64: 'cHNidP8=', funding: first);
    expect(arkService.calls.first, 'boardPsbt(cHNidP8=, 7, 9000)');

    final next = await arkProvider.boardFunding(1);
    expect(next.address, isNot(first.address));
    expect(arkService.fundingAddressCalls, 2);
  });

  test('a move bark parked is reported as pending, not failed', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());
    arkService.moveError = Exception(
      'offboard abc could not complete yet (parked in Broadcasting); it remains pending and will be retried on wallet sync',
    );

    expect(() => arkProvider.moveOnchain(1, 'bcrt1qdest', amountSats: 30000), throwsA(isA<ArkMovePendingException>()));
  });

  test('payments go out over the chosen rail and return their movement', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());

    expect(await arkProvider.pay(1, ArkPaymentRail.ark, destination: 'tark1x', amountSats: 5000), 11);
    expect(
      await arkProvider.pay(
        1,
        ArkPaymentRail.lightningInvoice,
        destination: 'lnbcrt1',
        amountSats: 3000,
        invoiceHasAmount: true,
      ),
      12,
    );
    expect(await arkProvider.pay(1, ArkPaymentRail.lightningInvoice, destination: 'lnbcrt2', amountSats: 3000), 12);

    expect(arkService.calls.where((call) => !call.startsWith('sync') && !call.startsWith('snapshot')), [
      'ark(tark1x, 5000)',
      // An invoice with an amount is paid as is; an amountless one gets the entered amount.
      'invoice(lnbcrt1, null)',
      'invoice(lnbcrt2, 3000)',
    ]);
  });

  test('a Lightning payment rejected for a stale chain tip is retried after a sync', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());
    arkService.staleTipRejections = 1;

    expect(await arkProvider.pay(1, ArkPaymentRail.lightningInvoice, destination: 'lnbcrt1', amountSats: 1000), 12);
    expect(arkService.calls.take(4), ['sync', 'invoice(lnbcrt1, 1000)', 'sync', 'invoice(lnbcrt1, 1000)']);
  });

  test('an on-chain payment bark parked is reported as pending', () async {
    arkService.openWallets.add(_fingerprint.toLowerCase());
    arkService.moveError = Exception('offboard x could not complete yet; it remains pending and will be retried');

    expect(
      () => arkProvider.pay(1, ArkPaymentRail.onchain, destination: 'bcrt1qx', amountSats: 30000),
      throwsA(isA<ArkMovePendingException>()),
    );
  });

  test('watch-only wallets have no Ark side', () async {
    final watchOnly = SinglesigWalletItem(id: 2, name: 'Watch', colorIndex: 0, iconIndex: 0, descriptor: _descriptor);
    walletProvider.walletItemListNotifier.value = [_hotWallet(1), watchOnly];

    expect(arkProvider.supportsArkById(2), isFalse);
    expect(arkProvider.snapshot(2), isNull);
    expect(arkProvider.totalSats(2), 0);
  });
}
