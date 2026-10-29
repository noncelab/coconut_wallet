import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_split/utxo_split_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';

class _PreferenceProvider extends Fake implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
}

class _WalletProvider extends Fake implements WalletProvider {
  final WalletItemBase wallet;

  _WalletProvider(this.wallet);

  @override
  WalletItemBase getWalletById(int id) => wallet;
}

class _UtxoTagProvider extends Fake implements UtxoTagProvider {
  final Map<String, List<UtxoTag>> tagsByUtxoId = {};

  @override
  List<UtxoTag> getUtxoTagsByUtxoId(int walletId, String utxoId) => tagsByUtxoId[utxoId] ?? [];
}

/// 주소 생성 단계에서 빌드를 멈춰 "빌드 진행 중" 상태를 재현한다.
class _GatedAddressRepository extends AddressRepository {
  _GatedAddressRepository(super.realmManager);

  /// 이 횟수만큼의 호출은 [release]될 때까지 대기한다.
  int gatedCallCount = 0;
  final List<Completer<void>> _gates = [];
  final List<bool Function()?> shouldStopGeneratingCallbacks = [];
  final StreamController<int> _entered = StreamController<int>.broadcast();

  int get callCount => shouldStopGeneratingCallbacks.length;

  Future<int> nextEntered() => _entered.stream.first;

  void release(int callIndex) => _gates[callIndex].complete();

  @override
  Future<List<WalletAddress>> getWalletAddressList(
    WalletItemBase walletItemBase,
    int cursor,
    int count,
    bool isChange,
    bool showOnlyUnusedAddresses, {
    bool Function()? shouldStopGenerating,
  }) async {
    final callIndex = shouldStopGeneratingCallbacks.length;
    shouldStopGeneratingCallbacks.add(shouldStopGenerating);
    final gate = Completer<void>();
    _gates.add(gate);
    if (callIndex >= gatedCallCount) {
      gate.complete();
    }
    _entered.add(callIndex);
    await gate.future;
    return super.getWalletAddressList(
      walletItemBase,
      cursor,
      count,
      isChange,
      showOnlyUnusedAddresses,
      shouldStopGenerating: shouldStopGenerating,
    );
  }
}

Future<void> waitUntil(bool Function() condition, {Duration timeout = const Duration(seconds: 20)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition not met within $timeout');
    }
    await Future.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  NetworkType.setNetworkType(NetworkType.regtest);

  late TestRealmManager realmManager;
  late _GatedAddressRepository addressRepository;
  late _UtxoTagProvider tagProvider;
  final SinglesigWalletItem wallet = WalletMock.createSingleSigWalletItem();
  final List<UtxoSplitViewModel> createdViewModels = [];

  UtxoState createUtxo(int amount, {int index = 0, String? txHash}) => UtxoState(
    transactionHash: txHash ?? 'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
    index: index,
    amount: amount,
    blockHeight: 100,
    to: 'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66',
    derivationPath: "m/84'/1'/0'/0/0",
    timestamp: DateTime.now(),
  );

  UtxoTag createTag(String id) => UtxoTag(id: id, walletId: wallet.id, name: 'tag-$id', colorIndex: 0);

  UtxoSplitViewModel createViewModel({UsePreviewConfirmPrompt? prompt}) {
    final viewModel = UtxoSplitViewModel(
      wallet.id,
      _PreferenceProvider(),
      _WalletProvider(wallet),
      addressRepository,
      SendInfoProvider(),
      tagProvider,
      prompt ?? () async => false,
    );
    viewModel.feeRateController.text = '1';
    createdViewModels.add(viewModel);
    return viewModel;
  }

  setUp(() async {
    realmManager = await setupTestRealmManager();
    addressRepository = _GatedAddressRepository(realmManager);
    tagProvider = _UtxoTagProvider();

    realmManager.realm.write(() {
      realmManager.realm.add(
        RealmWalletBase(
          wallet.id,
          wallet.colorIndex,
          wallet.iconIndex,
          wallet.descriptor,
          wallet.name,
          WalletType.singleSignature.name,
          generatedReceiveIndex: 19,
          generatedChangeIndex: 19,
        ),
      );
      realmManager.realm.addAll<RealmWalletAddress>([
        for (final isChange in [false, true])
          for (int i = 0; i < 20; i++)
            RealmWalletAddress(
              getWalletAddressId(wallet.id, i, wallet.walletBase.getAddress(i, isChange: isChange)),
              wallet.id,
              wallet.walletBase.getAddress(i, isChange: isChange),
              i,
              isChange,
              "${wallet.walletBase.derivationPath}/${isChange ? 1 : 0}/$i",
              false,
              0,
              0,
              0,
            ),
      ]);
    });
  });

  tearDown(() {
    for (final viewModel in createdViewModels) {
      viewModel.dispose();
    }
    createdViewModels.clear();
    realmManager.dispose();
  });

  group('빌드 중 선택 변경', () {
    test('다른 UTXO로 바꾸면 진행 중인 빌드가 취소되고, 늦게 끝난 이전 빌드가 새 결과를 덮어쓰지 않는다', () async {
      final utxoA = createUtxo(100000, index: 0);
      final utxoB = createUtxo(200000, index: 1);
      final viewModel = createViewModel();
      addressRepository.gatedCallCount = 1;

      viewModel.setSelectedUtxoList([utxoA]);
      viewModel.setSplitMethod(SplitMethod.evenly);
      final firstEntered = addressRepository.nextEntered();
      viewModel.splitCountController.text = '3';
      await firstEntered;

      final staleShouldStopGenerating = addressRepository.shouldStopGeneratingCallbacks[0]!;
      expect(staleShouldStopGenerating(), isFalse);
      expect(viewModel.showSkeletonResultBox, isTrue);

      viewModel.setSelectedUtxoList([utxoB]);

      expect(staleShouldStopGenerating(), isTrue, reason: '선택 변경 즉시 주소 생성 작업에 취소가 전달돼야 한다');
      expect(viewModel.splitResult, isNull);
      expect(viewModel.showSkeletonResultBox, isFalse);

      viewModel.splitCountController.text = '2';
      await waitUntil(() => viewModel.splitResult != null);
      final newResult = viewModel.splitResult!;
      expect(newResult.isSuccess, isTrue);
      expect(newResult.transaction!.inputs.map((input) => input.index), [utxoB.index]);
      expect(newResult.splitAmountMap.values.fold<int>(0, (sum, count) => sum + count), 2);

      addressRepository.release(0);
      await Future.delayed(const Duration(milliseconds: 500));

      expect(identical(viewModel.splitResult, newResult), isTrue);
      expect(viewModel.showSkeletonResultBox, isFalse);
    });

    test('선택을 모두 비우면 진행 중인 빌드가 취소되고 결과·로딩 상태가 남지 않는다', () async {
      final viewModel = createViewModel();
      addressRepository.gatedCallCount = 1;

      viewModel.setSelectedUtxoList([createUtxo(100000)]);
      viewModel.setSplitMethod(SplitMethod.evenly);
      final firstEntered = addressRepository.nextEntered();
      viewModel.splitCountController.text = '3';
      await firstEntered;
      final staleShouldStopGenerating = addressRepository.shouldStopGeneratingCallbacks[0]!;

      viewModel.setSelectedUtxoList([]);

      expect(staleShouldStopGenerating(), isTrue);
      expect(viewModel.isUtxoSelected, isFalse);
      expect(viewModel.selectedMethod, isNull);

      addressRepository.release(0);
      await Future.delayed(const Duration(milliseconds: 500));

      expect(viewModel.splitResult, isNull);
      expect(viewModel.showSkeletonResultBox, isFalse);
      expect(addressRepository.callCount, 1);
    });

    test('큰 Tx 확인 팝업이 떠 있는 동안 선택을 바꾸면 그 답으로 빌드하지 않고, 새 선택에서 다시 묻는다', () async {
      final prompts = <Completer<bool>>[];
      final viewModel = createViewModel(
        prompt: () {
          final answer = Completer<bool>();
          prompts.add(answer);
          return answer.future;
        },
      );

      viewModel.setSelectedUtxoList([createUtxo(50000000, index: 0), createUtxo(50000000, index: 1)]);
      viewModel.setSplitMethod(SplitMethod.evenly);
      viewModel.splitCountController.text = '999';
      await waitUntil(() => prompts.length == 1);

      viewModel.setSelectedUtxoList([createUtxo(100000000, index: 2)]);
      prompts[0].complete(false);
      await Future.delayed(const Duration(milliseconds: 500));

      expect(viewModel.splitResult, isNull);
      expect(viewModel.showSkeletonResultBox, isFalse);
      expect(addressRepository.callCount, 0);

      viewModel.splitCountController.text = '1000';
      await waitUntil(() => prompts.length == 2);
      prompts[1].complete(true);
      await waitUntil(() => viewModel.usePreview);

      expect(addressRepository.callCount, 0);
    });
  });

  group('UTXO 선택', () {
    test('여러 UTXO의 태그를 중복 없이 처음 나온 순서대로 합친다', () {
      final utxoA = createUtxo(100000, index: 0);
      final utxoB = createUtxo(100000, index: 1);
      final utxoC = createUtxo(100000, index: 2);
      tagProvider.tagsByUtxoId[utxoA.utxoId] = [createTag('t1'), createTag('t2')];
      tagProvider.tagsByUtxoId[utxoB.utxoId] = [createTag('t2'), createTag('t3')];
      final viewModel = createViewModel();

      viewModel.setSelectedUtxoList([utxoA, utxoB, utxoC]);

      expect(viewModel.selectedUtxoTags.map((tag) => tag.id), ['t1', 't2', 't3']);
    });

    test('합계가 20000 sats 미만이면 나누기 방법이 해제되고 빌드가 시작되지 않는다', () async {
      final viewModel = createViewModel();
      viewModel.setSelectedUtxoList([createUtxo(100000)]);
      viewModel.setSplitMethod(SplitMethod.evenly);

      viewModel.setSelectedUtxoList([createUtxo(9999, index: 0), createUtxo(10000, index: 1)]);
      viewModel.splitCountController.text = '2';
      await Future.delayed(const Duration(milliseconds: 1300));

      expect(viewModel.hasSelectedUtxoAmountError, isTrue);
      expect(viewModel.selectedMethod, isNull);
      expect(viewModel.isSplitInputValid, isFalse);
      expect(viewModel.splitResult, isNull);
      expect(addressRepository.callCount, 0);
    });
  });

  group('큰 트랜잭션 확인 기준 (input + output > 1000)', () {
    test('input 2개 + output 998개(합 1000)는 확인 없이 바로 빌드한다', () async {
      var promptCount = 0;
      final viewModel = createViewModel(
        prompt: () async {
          promptCount++;
          return true;
        },
      );
      addressRepository.gatedCallCount = 1;

      viewModel.setSelectedUtxoList([createUtxo(50000000, index: 0), createUtxo(50000000, index: 1)]);
      viewModel.setSplitMethod(SplitMethod.evenly);
      final firstEntered = addressRepository.nextEntered();
      viewModel.splitCountController.text = '998';
      await firstEntered;

      expect(promptCount, 0);
      expect(viewModel.usePreview, isFalse);
    });

    test('input 2개 + output 999개(합 1001)는 확인을 묻고, 미리보기를 고르면 빌드하지 않는다', () async {
      var promptCount = 0;
      final viewModel = createViewModel(
        prompt: () async {
          promptCount++;
          return true;
        },
      );

      viewModel.setSelectedUtxoList([createUtxo(50000000, index: 0), createUtxo(50000000, index: 1)]);
      viewModel.setSplitMethod(SplitMethod.evenly);
      viewModel.splitCountController.text = '999';
      await waitUntil(() => viewModel.usePreview);

      expect(promptCount, 1);
      expect(viewModel.splitResult, isNull);
      expect(viewModel.showSkeletonResultBox, isFalse);
      expect(addressRepository.callCount, 0);
    });
  });
}
