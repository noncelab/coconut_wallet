import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/address.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../services/shared_prefs_service_test.mocks.dart';

/// 실시간 구독 이벤트와 지갑별 동기화 큐 경로에서,
/// 섬(island, gap window 밖에 있던 사용 주소) 주소가 usedIndex 진행으로 gap 안에 들어왔을 때
/// 구독 범위가 해당 인덱스를 새 기준으로 다시 gap limit만큼 확장되는지,
/// 그리고 업데이트된 usedIndex/수신 주소 표시가 안전한지 검증한다.
void main() {
  const walletId = 902;

  group('SubscriptionService 라이브 이벤트 - 섬 흡수 시 gap window 재확장', () {
    setUp(() {
      ScriptSyncServiceMock.init();
    });

    tearDown(() {
      ScriptSyncServiceMock.realmManager?.reset();
      ScriptSyncServiceMock.realmManager?.dispose();
    });

    for (final isChange in [false, true]) {
      test(
        '50 new ${isChange ? 'change' : 'receive'} outputs are synchronized before publishing the balance',
        () async {
          final wallet = WalletMock.createSingleSigWalletItem(id: walletId);
          final realm = ScriptSyncServiceMock.realmManager!.realm;
          realm.write(() {
            realm.add(
              RealmWalletBase(
                wallet.id,
                wallet.colorIndex,
                wallet.iconIndex,
                wallet.descriptor,
                wallet.name,
                WalletType.singleSignature.name,
              ),
            );
          });
          final addresses = ScriptSyncServiceMock.addressRepository;
          await addresses.ensureAddressesInit(walletItemBase: wallet);
          await addresses.ensureAddressesExist(
            walletItemBase: wallet,
            cursor: 0,
            count: kSubscriptionGapLimit,
            isChange: isChange,
          );
          await addresses.updateWalletUsedIndex(wallet, 0, isChange: !isChange);
          await addresses.setWalletAddressUsed(wallet, 0, !isChange);
          addresses.updateAddressBalance(
            walletId: wallet.id,
            index: 0,
            isChange: !isChange,
            balance: Balance(1000000, 0),
          );
          ScriptSyncServiceMock.walletRepository.updateWalletBalance(wallet.id, Balance(1000000, 0));

          final input = wallet.walletBase.getAddress(0, isChange: !isChange);
          final outputs = List.generate(50, (i) => wallet.walletBase.getAddress(i, isChange: isChange));
          final funding = Transaction.withInputsAndOutputs(
            [TransactionInput.forPayment(List.filled(64, 'a').join(), 0)],
            [TransactionOutput.forPayment(1000000, input)],
            AddressType.p2wpkh,
          );
          final tx = Transaction.withInputsAndOutputs(
            [TransactionInput.forPayment(funding.transactionHash, 0)],
            outputs.map((address) => TransactionOutput.forPayment(19980, address)).toList(),
            AddressType.p2wpkh,
          );
          final callbacks = <String, Function(String, String?)>{};
          var broadcast = false;
          final electrum = ScriptSyncServiceMock.electrumService;
          when(electrum.getBalance(any, any)).thenAnswer((call) async {
            final address = call.positionalArguments[1] as String;
            if (address == input) return GetBalanceRes(confirmed: 1000000, unconfirmed: broadcast ? -1000000 : 0);
            return GetBalanceRes(confirmed: 0, unconfirmed: broadcast && outputs.contains(address) ? 19980 : 0);
          });
          when(electrum.getTransaction(tx.transactionHash)).thenAnswer((_) async => tx.serialize());
          when(electrum.getTransaction(funding.transactionHash)).thenAnswer((_) async => funding.serialize());
          when(
            electrum.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')),
          ).thenAnswer((_) async => [funding]);
          when(electrum.getHistory(any, any)).thenAnswer(
            (call) async =>
                broadcast && [input, ...outputs].contains(call.positionalArguments[1])
                    ? [GetTxHistoryRes(height: 0, txHash: tx.transactionHash)]
                    : <GetTxHistoryRes>[],
          );
          when(electrum.getUnspentList(any, any)).thenAnswer((call) async {
            final index = outputs.indexOf(call.positionalArguments[1] as String);
            return broadcast && index >= 0
                ? [ListUnspentRes(height: 0, txHash: tx.transactionHash, txPos: index, value: 19980)]
                : <ListUnspentRes>[];
          });
          when(
            electrum.subscribeScriptForWallet(any, any, walletId: wallet.id, onUpdate: anyNamed('onUpdate')),
          ).thenAnswer((call) async {
            final address = call.positionalArguments[1] as String;
            callbacks[address] = call.namedArguments[#onUpdate] as Function(String, String?);
            return address == input || (broadcast && outputs.contains(address)) ? 'used_$address' : null;
          });
          final subscriptions = SubscriptionService(
            electrum,
            ScriptSyncServiceMock.stateManager,
            addresses,
            SubscriptionRepository(ScriptSyncServiceMock.realmManager!),
            ScriptSyncServiceMock.createMockScriptSyncService(),
          );
          expect((await subscriptions.subscribeWallet(wallet)).isSuccess, isTrue);
          expect(outputs.where(callbacks.containsKey), hasLength(kSubscriptionGapLimit));

          broadcast = true;
          // Electrum only pushes the initial gap window; later outputs are returned by subscription responses.
          for (final address in outputs.take(kSubscriptionGapLimit)) {
            callbacks[address]!('scriptHash', 'split_$address');
          }
          callbacks[input]!('scriptHash', 'spent');
          await Future<void>.delayed(Duration.zero);
          await subscriptions.runExclusive(wallet.id, () async {});

          expect(ScriptSyncServiceMock.walletRepository.getWalletBalance(wallet.id)!.total, 999000);
          expect(ScriptSyncServiceMock.stateManager.state.registeredWallets[wallet.id]!.balanceSnapshot, 999000);
          expect(isChange ? wallet.changeUsedIndex : wallet.receiveUsedIndex, 49);
          final record =
              ScriptSyncServiceMock.transactionRepository.getTransactionRecord(wallet.id, tx.transactionHash)!;
          expect(record.transactionType, TransactionType.self);
          expect(record.amount, -record.fee);
          expect(record.fee, 1000);
          expect(ScriptSyncServiceMock.utxoRepository.getUtxoStateList(wallet.id), hasLength(50));
          for (final address in outputs.skip(kSubscriptionGapLimit)) {
            verify(electrum.getBalance(wallet.walletBase.addressType, address)).called(1);
            verify(electrum.getUnspentList(wallet.walletBase.addressType, address)).called(1);
          }
        },
      );
    }

    for (final failedStage in ['balance', 'history']) {
      for (final amount in [0, 99000]) {
        for (final queued in [false, true]) {
          test('unchanged subscription status retries $failedStage (amount: $amount, queued: $queued)', () async {
            final wallet = WalletMock.createSingleSigWalletItem(id: walletId);
            final realm = ScriptSyncServiceMock.realmManager!.realm;
            realm.write(() {
              realm.add(
                RealmWalletBase(
                  wallet.id,
                  wallet.colorIndex,
                  wallet.iconIndex,
                  wallet.descriptor,
                  wallet.name,
                  WalletType.singleSignature.name,
                ),
              );
            });
            final addresses = ScriptSyncServiceMock.addressRepository;
            await addresses.ensureAddressesInit(walletItemBase: wallet);
            addresses.updateAddressBalance(walletId: wallet.id, index: 0, isChange: false, balance: Balance(100000, 0));
            ScriptSyncServiceMock.walletRepository.updateWalletBalance(wallet.id, Balance(100000, 0));
            final first = wallet.walletBase.getAddress(0);
            var failing = true;
            final electrum = ScriptSyncServiceMock.electrumService;
            when(electrum.unsubscribeScript(any, any)).thenAnswer((_) async => true);
            when(electrum.getBalance(any, any)).thenAnswer((call) async {
              if (failing && failedStage == 'balance') {
                failing = false;
                throw StateError('connection interrupted');
              }
              return GetBalanceRes(confirmed: amount, unconfirmed: 0);
            });
            when(electrum.getHistory(any, any)).thenAnswer((call) async {
              if (failing && failedStage == 'history') {
                failing = false;
                throw StateError('connection interrupted');
              }
              return <GetTxHistoryRes>[];
            });
            when(electrum.getUnspentList(any, any)).thenAnswer((_) async => <ListUnspentRes>[]);
            when(
              electrum.subscribeScriptForWallet(any, any, walletId: wallet.id, onUpdate: anyNamed('onUpdate')),
            ).thenAnswer((call) async => call.positionalArguments[1] == first ? 'unchanged-status' : null);
            final repository = SubscriptionRepository(ScriptSyncServiceMock.realmManager!);
            final subscriptions = SubscriptionService(
              electrum,
              ScriptSyncServiceMock.stateManager,
              addresses,
              repository,
              ScriptSyncServiceMock.createMockScriptSyncService(),
            );
            final firstAttempt = subscriptions.subscribeWallet(wallet);
            final queuedRetry = queued ? subscriptions.subscribeWallet(wallet) : null;
            final firstResult = await firstAttempt;
            if (!queued) {
              expect(ScriptSyncServiceMock.stateManager.state.registeredWallets[wallet.id]!.balanceSnapshot, 100000);
            }
            expect(firstResult.isFailure, isTrue);
            expect((await (queuedRetry ?? subscriptions.subscribeWallet(wallet))).isSuccess, isTrue);
            expect(ScriptSyncServiceMock.stateManager.state.registeredWallets[wallet.id]!.balanceSnapshot, amount);
            expect(ScriptSyncServiceMock.stateManager.state.nodeSyncState, NodeSyncState.completed);
            verify(electrum.getBalance(wallet.walletBase.addressType, first)).called(2);
          });
        }
      }
    }

    for (final queued in [false, true]) {
      test('same-index retry extends after subscription failure (already queued: $queued)', () async {
        final wallet = WalletMock.createSingleSigWalletItem(id: walletId);
        final realm = ScriptSyncServiceMock.realmManager!.realm;
        realm.write(() {
          realm.add(
            RealmWalletBase(
              wallet.id,
              wallet.colorIndex,
              wallet.iconIndex,
              wallet.descriptor,
              wallet.name,
              WalletType.singleSignature.name,
            ),
          );
        });
        final addresses = ScriptSyncServiceMock.addressRepository;
        await addresses.ensureAddressesInit(walletItemBase: wallet);
        final first = wallet.walletBase.getAddress(19);
        final next = wallet.walletBase.getAddress(20);
        final callbacks = <String, Function(String, String?)>{};
        var broadcast = false;
        var failSubscription = true;
        final electrum = ScriptSyncServiceMock.electrumService;
        when(electrum.getBalance(any, any)).thenAnswer(
          (call) async => GetBalanceRes(
            confirmed: 0,
            unconfirmed: broadcast && [first, next].contains(call.positionalArguments[1]) ? 1000 : 0,
          ),
        );
        when(electrum.getHistory(any, any)).thenAnswer((_) async => <GetTxHistoryRes>[]);
        when(electrum.getUnspentList(any, any)).thenAnswer((_) async => <ListUnspentRes>[]);
        when(
          electrum.subscribeScriptForWallet(any, any, walletId: wallet.id, onUpdate: anyNamed('onUpdate')),
        ).thenAnswer((call) async {
          final address = call.positionalArguments[1] as String;
          if (broadcast && failSubscription && address == next) {
            failSubscription = false;
            throw StateError('disconnected');
          }
          callbacks[address] = call.namedArguments[#onUpdate] as Function(String, String?);
          return broadcast && [first, next].contains(address) ? 'used_$address' : null;
        });
        final subscriptions = SubscriptionService(
          electrum,
          ScriptSyncServiceMock.stateManager,
          addresses,
          SubscriptionRepository(ScriptSyncServiceMock.realmManager!),
          ScriptSyncServiceMock.createMockScriptSyncService(),
        );
        await subscriptions.subscribeWallet(wallet);

        broadcast = true;
        callbacks[first]!('scriptHash', 'pending');
        if (!queued) {
          await Future<void>.delayed(Duration.zero);
          await subscriptions.runExclusive(wallet.id, () async {});
          expect(wallet.receiveUsedIndex, 19);
          expect(callbacks.containsKey(next), isFalse);
          expect(ScriptSyncServiceMock.stateManager.state.registeredWallets[wallet.id]!.balanceSnapshot, 0);
        }
        callbacks[first]!('scriptHash', 'confirmed');
        await Future<void>.delayed(Duration.zero);
        await subscriptions.runExclusive(wallet.id, () async {});
        expect(wallet.receiveUsedIndex, 20);
        expect(ScriptSyncServiceMock.walletRepository.getWalletBalance(wallet.id)!.total, 2000);
        expect(ScriptSyncServiceMock.stateManager.state.registeredWallets[wallet.id]!.balanceSnapshot, 2000);
      });
    }

    test('섬(75)이 gap 안으로 들어오면 75+gapLimit까지 구독 윈도우가 확장돼야 한다', () async {
      final wallet = WalletMock.createSingleSigWalletItem(id: walletId, name: 'island_wallet');

      final sharedPrefsRepository = SharedPrefsRepository()..setSharedPreferencesForTest(MockSharedPreferences());
      when(sharedPrefsRepository.getInt(SharedPrefKeys.kNextIdField)).thenAnswer((_) => wallet.id);
      when(sharedPrefsRepository.setInt(SharedPrefKeys.kNextIdField, wallet.id + 1)).thenAnswer((_) async => true);

      await ScriptSyncServiceMock.walletRepository.addSinglesigWallet(
        WatchOnlyWallet(
          wallet.name,
          wallet.colorIndex,
          wallet.iconIndex,
          wallet.descriptor,
          null,
          null,
          WalletImportSource.coconutVault.name,
        ),
      );

      final addressRepository = ScriptSyncServiceMock.addressRepository;
      await addressRepository.ensureAddressesInit(walletItemBase: wallet);
      // 섬(75)과, 그 이후 재확장될 gap window(76~95)까지 주소를 미리 만들어둔다.
      await addressRepository.ensureAddressesExist(walletItemBase: wallet, cursor: 0, count: 120, isChange: false);

      // 35~40: 연속 사용 구간(잔액 있음)
      for (var i = 35; i <= 40; i++) {
        await addressRepository.setWalletAddressUsed(wallet, i, false);
        addressRepository.updateAddressBalance(
          walletId: wallet.id,
          index: i,
          isChange: false,
          balance: Balance(1000, 0),
        );
      }
      // 75: gap window 밖 사용 주소 (gap window(41~60) 밖에서 out-of-band로 이미 발견되어 사용 처리된 주소, 잔액 있음)
      await addressRepository.setWalletAddressUsed(wallet, 75, false);
      addressRepository.updateAddressBalance(
        walletId: wallet.id,
        index: 75,
        isChange: false,
        balance: Balance(2000, 0),
      );

      // usedIndex를 40으로 확정(DB에도 반영)
      await addressRepository.updateWalletUsedIndex(wallet, 40, isChange: false);
      wallet.receiveUsedIndex = 40;

      // 실제 Electrum 서버라면, 이미 사용 이력이 있는 주소는 구독 시점에 바로 non-null 상태를
      // 응답으로 돌려준다. 이 응답이 있어야 subscribedScriptMap에 status!=null로 기록되어
      // _scanAndSubscribeRange가 "이미 사용된 주소"로 인식한다(35~40, 75).
      final preUsedAddresses = <String>{
        for (var i = 35; i <= 40; i++) wallet.walletBase.getAddress(i, isChange: false),
        wallet.walletBase.getAddress(75, isChange: false),
      };

      final electrumService = ScriptSyncServiceMock.electrumService;
      final address55 = wallet.walletBase.getAddress(55, isChange: false);
      final address75 = wallet.walletBase.getAddress(75, isChange: false);
      when(electrumService.getBalance(any, any)).thenAnswer((invocation) async {
        final address = invocation.positionalArguments[1] as String;
        final confirmed =
            address == address75
                ? 2000
                : (preUsedAddresses.contains(address) ? 1000 : (address == address55 ? 500 : 0));
        return GetBalanceRes(confirmed: confirmed, unconfirmed: 0);
      });
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => <GetTxHistoryRes>[]);
      when(electrumService.getUnspentList(any, any)).thenAnswer((_) async => <ListUnspentRes>[]);
      final subscribedAddresses = <String>[];
      final onUpdateCallbacks = <String, Function(String, String?)>{};
      when(
        electrumService.subscribeScriptForWallet(any, any, walletId: wallet.id, onUpdate: anyNamed('onUpdate')),
      ).thenAnswer((invocation) async {
        final address = invocation.positionalArguments[1] as String;
        final onUpdate = invocation.namedArguments[#onUpdate] as Function(String, String?);
        onUpdateCallbacks[address] = onUpdate;
        subscribedAddresses.add(address);
        return preUsedAddresses.contains(address) ? 'initial_status_$address' : null;
      });

      final scriptSyncService = ScriptSyncServiceMock.createMockScriptSyncService();
      final subscriptionRepository = SubscriptionRepository(ScriptSyncServiceMock.realmManager!);
      final subscriptionService = SubscriptionService(
        electrumService,
        ScriptSyncServiceMock.stateManager,
        addressRepository,
        subscriptionRepository,
        scriptSyncService,
      );

      // Given: 초기 구독 (섬 75 + 41~60 gap window 포함)
      final result = await subscriptionService.subscribeWallet(wallet);
      expect(result.isSuccess, true);

      expect(subscribedAddresses.contains(address75), isTrue, reason: '섬(75)은 잔액이 있으므로 초기 구독에 포함돼야 한다.');
      for (var i = 61; i <= 95; i++) {
        if (i == 75) continue; // 75는 섬이라 이미 구독돼 있어야 정상
        final address = wallet.walletBase.getAddress(i, isChange: false);
        expect(subscribedAddresses.contains(address), isFalse, reason: 'index $i는 아직 gap window 밖이라 구독되면 안 된다.');
      }

      // When: index 55가 실시간으로 사용됨 (Electrum 서버로부터의 push 알림 시뮬레이션)
      final onUpdate55 = onUpdateCallbacks[address55];
      expect(onUpdate55, isNotNull, reason: 'index 55는 초기 gap window(41~60)에 포함되어 있어야 구독돼 있다.');
      onUpdate55!('dummyScriptHash', 'newTipStatusHash');

      await Future<void>.delayed(Duration.zero);
      await subscriptionService.runExclusive(wallet.id, () async {});
      verify(electrumService.getBalance(wallet.walletBase.addressType, address55)).called(1);
      verify(electrumService.getHistory(wallet.walletBase.addressType, address55)).called(1);
      verify(electrumService.getUnspentList(wallet.walletBase.addressType, address55)).called(1);

      // Then: 섬(75)이 새 baseline이 되었다면, 75 + kSubscriptionGapLimit(20) = 95까지 구독돼야 한다.
      final missingExtendedIndexes = <int>[];
      for (var i = 76; i <= 75 + kSubscriptionGapLimit; i++) {
        final address = wallet.walletBase.getAddress(i, isChange: false);
        if (!subscribedAddresses.contains(address)) {
          missingExtendedIndexes.add(i);
        }
      }

      // Then: 영속화된 usedReceiveIndex / 다음 수신 주소 index도 확인한다.
      final (persistedReceiveUsedIndex, _) = addressRepository.getUsedIndexes(wallet.id);
      final nextReceiveAddress = addressRepository.getReceiveAddress(wallet.id, wallet: wallet.walletBase);

      // 결과를 출력해서(테스트 로그) 실제 동작을 눈으로도 확인할 수 있게 한다.
      // ignore: avoid_print
      print(
        '[결과] gap window 확장 누락 index(76~95): $missingExtendedIndexes / '
        '영속화된 usedReceiveIndex: $persistedReceiveUsedIndex / '
        '다음 수신 주소 index: ${nextReceiveAddress.index}',
      );

      expect(missingExtendedIndexes, isEmpty, reason: '섬 흡수 후 gap window가 75 기준으로 재확장되어야 한다(현재 버그로 실패 예상).');
      expect(persistedReceiveUsedIndex, 75, reason: '영속화된 usedReceiveIndex가 섬 발견을 반영해 75여야 한다(현재 버그로 실패 예상).');

      // 안전성 체크: island의 다음 index(76)나 그 이상을 "다음 수신 주소"로 성급하게 보여주면 안 된다.
      expect(
        nextReceiveAddress.index,
        lessThanOrEqualTo(76),
        reason: '아직 사용 여부가 확인되지 않은 56~74 구간을 건너뛰고 island 다음(76 초과) 주소를 보여주면 안 된다.',
      );
    });
  });
}
