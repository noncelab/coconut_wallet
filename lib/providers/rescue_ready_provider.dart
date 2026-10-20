import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/safety_store.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/safety/assist/safety_assist_screen.dart';
import 'package:coconut_wallet/services/fee_service.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/safety/safety_assist.dart';
import 'package:coconut_wallet/services/safety/sweep_builder.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

/// 비상 이동 준비 화면의 지갑 행 상태(UI_SPEC §10.8)
enum RescueStatus {
  notSet,

  /// 목적지 지갑이 사용 주의·사건·같은 니모닉이 됐거나 저장한 주소가 더는 맞지 않음
  invalidDestination,

  /// 구독이 끝나 자동 재계산이 멈춤. 초안·지금 이동은 그대로
  paused,

  /// 목적지는 있고 아직 첫 초안 전
  pending,

  /// 수수료를 한 번도 못 받아 초안을 못 만듦
  failed,
  ready,
  noBalance,
  tooSmall,
  unavailable,
}

/// Premium 비상 이동 준비: 지갑별 비상 목적지와, 동기화마다 다시 계산하는 이동 초안 요약.
/// 초안은 [RescueDraftSummary]만 저장한다. PSBT를 만들거나 서명·전송·앱 생성 txid 기록을 하지 않는다
class RescueReadyProvider extends ChangeNotifier {
  RescueReadyProvider({
    required WalletProvider walletProvider,
    required NodeProvider nodeProvider,
    required EntitlementService entitlement,
    SafetyStore? store,
    Future<RecommendedFee?> Function()? fetchFees,
    Duration feeRefreshInterval = const Duration(minutes: 5),
    @visibleForTesting DateTime Function()? now,
    @visibleForTesting int derivedAddressDepth = 1000,
  }) : _wallets = walletProvider,
       _node = nodeProvider,
       _entitlement = entitlement,
       _store = store ?? SafetyStore(SharedPrefsRepository()),
       _fetchFees = fetchFees ?? FeeService().getRecommendedFees,
       _feeRefreshInterval = feeRefreshInterval,
       _now = now ?? DateTime.now,
       _derivedAddressDepth = derivedAddressDepth {
    _wasActive = entitlement.state.value.isActive;
    entitlement.state.addListener(_onEntitlement);
    walletProvider.walletItemListNotifier.addListener(_onWallets);
    _syncSubscription = nodeProvider.syncStateStream.listen(_onSync);
    _walletSubscription = walletProvider.lifecycleEvents.listen(_onWalletEvent);
  }

  final WalletProvider _wallets;
  final NodeProvider _node;
  final EntitlementService _entitlement;
  final SafetyStore _store;
  final Future<RecommendedFee?> Function() _fetchFees;
  final Duration _feeRefreshInterval;
  final DateTime Function() _now;
  final int _derivedAddressDepth;
  StreamSubscription<NodeSyncState>? _syncSubscription;
  StreamSubscription<WalletLifecycleEvent>? _walletSubscription;
  late bool _wasActive;
  bool _disposed = false, _recomputing = false, _recomputeAgain = false, _moving = false;

  /// 마지막으로 받은 정상 빠른 수수료(sat/vB, [SweepFee.isSane]). 새 값이 없거나 비정상이면 이 값을 쓴다
  double? _feeRate;

  /// 마지막 요청에서 고른 수수료(정상 새 값·마지막 정상 값·노드 추정). 스로틀 동안 이 값을 쓴다
  double? _chosenFeeRate;

  /// 마지막으로 수수료를 요청한 시각(성공·실패 모두). 5분 스로틀 기준
  DateTime? _feeAttemptAt;

  /// 마지막 재계산에서 쓸 수수료가 하나도 없었음
  bool _feeFailed = false;

  /// 수수료가 너무 큰 초안의 [RescueDraftSummary.blocker]. 상태는 [RescueStatus.unavailable]
  static const feeTooHighBlocker = 'feeTooHigh';

  bool get isPremiumActive => _entitlement.state.value.isActive;

  /// 구독 없음·만료. 확인 중(verifying)·결제 대기는 아니다(앱을 열 때마다 "멈춤"·Premium 안내가 깜박이지 않게)
  bool get lacksPremium {
    final status = _entitlement.state.value.status;
    return status == PremiumStatus.expired || status == PremiumStatus.none;
  }

  /// 막힘 없는 초안 + 잔액 없음 등 막힌 초안. 목적지를 다시 정해야 하는 지갑은 빠진다
  Map<int, RescueDraftSummary> get drafts {
    final state = _store.load();
    return {
      for (final e in state.rescue.entries)
        if (e.value.draft != null && _targetOf(e.key, e.value.destination, state) != null) e.key: e.value.draft!,
    };
  }

  /// Wallet Health "비상 이동 준비됨 · n개 지갑"
  int get readyWalletCount => drafts.values.where((d) => d.blocker == null).length;

  RescueDestination? destinationOf(int walletId) => _store.load().rescue[walletId]?.destination;

  /// 막힘 없는 초안이 있음("준비된 이동 있음" 카드·지금 이동 버튼). 구독이 끝나도 그대로
  bool canMoveNow(int walletId) {
    final draft = drafts[walletId];
    return draft != null && draft.blocker == null;
  }

  /// 이 지갑에 열린 위급 사건이 있음(사고 때만 지금 이동을 보인다)
  bool hasCriticalIncident(int walletId) => _hasCriticalIncident(walletId, _store.load());

  RescueStatus statusOf(int walletId) {
    final state = _store.load();
    final entry = state.rescue[walletId];
    if (entry == null) return RescueStatus.notSet;
    if (_targetOf(walletId, entry.destination, state) == null) return RescueStatus.invalidDestination;
    if (lacksPremium) return RescueStatus.paused;
    final draft = entry.draft;
    if (draft == null) return _feeFailed ? RescueStatus.failed : RescueStatus.pending;
    return switch (draft.blocker) {
      null => RescueStatus.ready,
      'noInputs' => RescueStatus.noBalance,
      'belowDust' || 'insufficientForFee' => RescueStatus.tooSmall,
      _ => RescueStatus.unavailable,
    };
  }

  /// 목적지 이름(지갑 이름 또는 주소 앞뒤). 목적지가 없으면 null
  String? destinationLabel(int walletId) {
    final d = destinationOf(walletId);
    final destId = d?.walletId;
    if (destId != null) return _walletById(destId)?.name;
    final address = d?.address;
    return address == null ? null : shortenAddress(address);
  }

  /// 목적지 시트 후보(UI_SPEC §10.7·§10.8, Assist와 같은 순서). 이 지갑·같은 니모닉·사용 주의·위급 사건·검증 불일치 지갑은
  /// 빠진다. "볼트에서 새 지갑"은 안내 → 지갑 추가 스캔을 거친 뒤 그 지갑을 목적지로 저장한다(화면이 맡는다)
  List<AssistDestination> destinationOptions(int walletId) {
    final source = _walletById(walletId);
    if (source == null) return const [];
    final state = _store.load();
    return [
      for (final d in SafetyAssist.destinations(
        incidentWallet: source,
        wallets: _wallets.walletItemList,
        safetyState: state,
        rescueDestination: state.rescue[walletId]?.destination,
      ))
        // 받기 주소를 제외 지갑도 가진 지갑(같은 디스크립터의 핫·보기 전용 사본)도 보이지 않게 같은 검사를 한다
        if (d.wallet == null ||
            _target(source, RescueDestination(walletId: d.wallet!.id, setAt: _now()), state) != null)
          d,
    ];
  }

  /// 직접 입력 주소 검사. [format]은 형식·네트워크 오류, [ownedByExcluded]는 이 지갑·제외 지갑의 주소
  ({AddressValidationError? format, bool ownedByExcluded}) checkAddress(int walletId, String address) {
    final format = AddressValidator.validateAddress(address.trim(), NetworkType.currentNetworkType);
    if (format != null) return (format: format, ownedByExcluded: false);
    final source = _walletById(walletId);
    final target =
        source == null
            ? null
            : _target(source, RescueDestination(address: address.trim(), setAt: _now()), _store.load());
    return (format: null, ownedByExcluded: target == null);
  }

  /// 목적지 정하기·바꾸기는 Premium 활성일 때만(새 자동화). null = 정하지 않음(목적지와 초안 삭제)은 구독과 무관하게 언제나.
  /// 초안은 다음 동기화 때 만든다
  Future<void> setDestination(int walletId, RescueDestination? d) async {
    if (d != null && !isPremiumActive) throw StateError('Premium is not active');
    var next = d;
    if (next != null) {
      final source = _walletById(walletId);
      final target = source == null ? null : _target(source, next, _store.load());
      if (target == null) throw ArgumentError('Destination is not allowed for this wallet');
      if (next.address != null) {
        if (await derivesFromExcludedWallet(walletId, target.address)) {
          throw ArgumentError('Destination derives from an excluded wallet');
        }
        next = RescueDestination(address: target.address, setAt: next.setAt);
      }
    }
    final saved = next;
    await _store.update(
      (s) => s.copyWith(
        rescue: {
          for (final e in s.rescue.entries)
            if (e.key != walletId) e.key: e.value,
          if (saved != null) walletId: (destination: saved, draft: null),
        },
      ),
    );
    if (!_disposed) notifyListeners();
  }

  /// 사용자가 시작하는 이동. 구독이 끝나도 동작한다(새로 시작하는 자동화가 아님).
  /// Safety Assist 흐름이 지금 수수료와 열린 위급 사건의 충돌로 다시 계획해 검토 화면 → 기존 보내기 확인으로 간다.
  /// 서명·전송은 거기서 사용자가 한다
  Future<void> moveNow(BuildContext context, int walletId) async {
    if (_moving) return;
    _moving = true;
    try {
      final state = _store.load();
      final source = _walletById(walletId);
      final destination = state.rescue[walletId]?.destination;
      if (source == null || destination == null) return;
      // 목적지가 그사이 사용 주의·사건·같은 니모닉·검증 불일치가 됐거나, 주소가 맞지 않거나 제외 지갑에서 나온 주소면 옮기지 않는다
      final target = _target(source, destination, state);
      final invalid =
          target == null || (destination.address != null && await derivesFromExcludedWallet(walletId, target.address));
      if (!context.mounted) return;
      if (invalid) {
        CoconutToast.showToast(
          context: context,
          text: t.premium.rescue.destination_invalid,
          isVisibleIcon: true,
          iconPath: CommonStateIconPath.triangleWarning,
          level: CoconutToastLevel.warning,
        );
        return;
      }
      // 누른 순간의 목적지를 넘긴다. 수수료는 Safety Assist가 지금 다시 받고, 못 받으면 마지막 수수료
      await SafetyAssistFlow.moveNow(
        context,
        walletId: walletId,
        destination: destination,
        fallbackFeeRate: _feeRate ?? state.rescue[walletId]?.draft?.feeRate,
      );
    } finally {
      _moving = false;
    }
  }

  WalletItemBase? _walletById(int id) => _wallets.walletItemList.firstWhereOrNull((w) => w.id == id);

  bool _hasCriticalIncident(int walletId, SafetyState state) =>
      state.incidents.any((i) => i.walletId == walletId && i.isCritical);

  ({String address, WalletItemBase? wallet})? _targetOf(int walletId, RescueDestination d, SafetyState state) {
    final source = _walletById(walletId);
    return source == null ? null : _target(source, d, state);
  }

  /// 보낼 주소(Safety Assist와 같은 마지막 확인). 지갑 목적지는 지금 받기 주소, 직접 입력은 지금 네트워크 주소로 정규화.
  /// 이 주소를 가진 지갑이 하나라도 이 지갑·같은 MFP·같은 키·사용 주의·위급 사건·검증 불일치(와 같은 키) 지갑이면 null.
  /// 초안·상태·저장·지금 이동이 모두 이 검사를 쓴다. 만들어 둔 주소 목록 밖은 [derivesFromExcludedWallet]가 저장·이동 때 본다
  ({String address, WalletItemBase? wallet})? _target(WalletItemBase source, RescueDestination d, SafetyState state) =>
      SafetyAssist.verifiedTarget(_wallets, source: source, destination: d, state: state);

  /// 직접 입력·저장한 주소가 제외 지갑의 앞 받기·잔돈 주소에서 나왔는지(별도 isolate, 저장·이동할 때 한 번만)
  Future<bool> derivesFromExcludedWallet(int walletId, String address) async {
    final source = _walletById(walletId);
    if (source == null) return true;
    return SafetyAssist.derivesFromExcludedWallet(
      _wallets,
      incidentWallet: source,
      address: address,
      safetyState: _store.load(),
      depth: _derivedAddressDepth,
    );
  }

  /// 빠른 수수료(Safety Assist와 같은 규칙): 새 값 → 마지막 정상 값 → 노드 추정. 없거나 비정상(1,000 sat/vB 초과·
  /// 마지막 정상 값의 10배 초과)이면 다음 것. 마지막 요청(실패 포함)에서 [_feeRefreshInterval] 안이면 다시 요청하지 않는다
  Future<double?> _fastFee() async {
    final at = _feeAttemptAt;
    if (at != null && _now().difference(at) < _feeRefreshInterval) return _chosenFeeRate;
    _feeAttemptAt = _now();
    double? fresh, node;
    try {
      fresh = (await _fetchFees())?.fastestFee;
    } catch (_) {}
    if (!SweepFee.isSane(fresh, lastGood: _feeRate) && !SweepFee.isSane(_feeRate)) {
      try {
        final result = await _node.getRecommendedFees();
        if (result.isSuccess) node = result.value.fastestFee;
      } catch (_) {}
    }
    final chosen = SweepFee.choose(fresh: fresh, lastGood: _feeRate, node: node);
    if (chosen?.source == FeeRateSource.fresh) _feeRate = chosen!.rate;
    return _chosenFeeRate = chosen?.rate ?? _chosenFeeRate;
  }

  void _onEntitlement() {
    final active = isPremiumActive;
    if (active && !_wasActive) unawaited(_recompute());
    _wasActive = active;
    if (!_disposed) notifyListeners();
  }

  void _onWallets() {
    unawaited(_recompute());
    if (!_disposed) notifyListeners();
  }

  void _onSync(NodeSyncState sync) {
    // F6: 구독하면 지금 상태를 재생하고 오프라인 시작도 completed라서 연결·등록 지갑으로 거른다
    if (sync == NodeSyncState.completed && _node.isConnected && _node.state.registeredWallets.isNotEmpty) {
      unawaited(_recompute());
    }
  }

  void _onWalletEvent(WalletLifecycleEvent event) {
    if (event is! WalletRemoved) return;
    // 그 지갑을 가리키는 목적지도 지운다(SafetyProvider도 같은 정리를 하지만 순서와 무관하게 결과가 같다)
    unawaited(
      _store.update((s) => s.withoutWallet(event.walletId)).then((_) {
        if (!_disposed) notifyListeners();
      }, onError: (_) {}),
    );
  }

  /// Premium 활성일 때만. 돌고 있으면 끝난 뒤 한 번 더
  Future<void> _recompute() async {
    if (_disposed || !isPremiumActive) return;
    if (_wallets.walletLoadStateNotifier.value != WalletLoadState.loadCompleted) return;
    if (_recomputing) {
      _recomputeAgain = true;
      return;
    }
    _recomputing = true;
    try {
      do {
        _recomputeAgain = false;
        await _recomputeOnce();
      } while (_recomputeAgain && !_disposed && isPremiumActive);
    } catch (e) {
      Logger.error('RescueReadyProvider: recompute failed: ${e.runtimeType}');
    } finally {
      _recomputing = false;
    }
  }

  Future<void> _recomputeOnce() async {
    final state = _store.load();
    final targets = [
      for (final e in state.rescue.entries)
        if (_walletById(e.key) case final wallet?) (wallet: wallet, destination: e.value.destination),
    ];
    if (targets.isEmpty) return;

    final feeRate = await _fastFee();
    if (_disposed) return;
    _feeFailed = feeRate == null;
    if (feeRate == null) {
      notifyListeners();
      return;
    }

    final preparedAt = _now();
    final drafts = <int, ({RescueDestination destination, RescueDraftSummary draft})>{};
    for (final t in targets) {
      final target = _target(t.wallet, t.destination, state);
      if (target == null) continue; // 목적지를 다시 정해야 함(행 상태로 보인다)
      String? blocker;
      SweepPlan? plan;
      try {
        plan = SweepBuilder.plan(
          wallet: t.wallet,
          utxos: _wallets.getUtxoList(t.wallet.id),
          conflicts: const [],
          fastFeeRate: feeRate,
        );
        // 수수료가 옮기는 금액의 20%를 넘으면 그대로 보내지 않는다(Safety Assist와 같은 규칙)
        blocker = plan.blocker?.name ?? (SweepFee.isExcessive(plan) ? feeTooHighBlocker : null);
      } catch (e) {
        Logger.error('RescueReadyProvider: plan failed: ${e.runtimeType}');
        blocker = 'error';
      }
      drafts[t.wallet.id] = (
        destination: t.destination,
        draft: RescueDraftSummary(
          destinationAddress: target.address,
          amount: plan?.amount ?? 0,
          fee: plan?.fee ?? 0,
          inputCount: plan?.inputs.length ?? 0,
          feeRate: plan?.feeRate ?? 0,
          preparedAt: preparedAt,
          blocker: blocker,
        ),
      );
    }

    if (drafts.isNotEmpty) {
      // 계산하는 동안 목적지를 바꾸거나 끈 지갑은 건드리지 않는다
      await _store.update(
        (s) => s.copyWith(
          rescue: {
            for (final e in s.rescue.entries)
              e.key:
                  drafts[e.key]?.destination == e.value.destination
                      ? (destination: e.value.destination, draft: drafts[e.key]!.draft)
                      : e.value,
          },
        ),
      );
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _entitlement.state.removeListener(_onEntitlement);
    _wallets.walletItemListNotifier.removeListener(_onWallets);
    unawaited(_syncSubscription?.cancel());
    unawaited(_walletSubscription?.cancel());
    super.dispose();
  }
}
