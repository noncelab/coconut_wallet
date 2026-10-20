import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/analytics/safety_analytics.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/utils/hash_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show PricingPhaseWrapper, PurchaseStateWrapper, SubscriptionOfferDetailsWrapper;
import 'package:in_app_purchase_android/in_app_purchase_android.dart'
    show GooglePlayProductDetails, GooglePlayPurchaseDetails;
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart' show AppStoreProduct2Details;
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart'
    show SK2Product, SK2SubscriptionOfferPaymentMode, SK2SubscriptionOfferType, SK2SubscriptionPeriodUnit;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 오류는 종류와 코드만 남긴다(PlatformException details에 서명된 영수증(JWS)이 들어 있을 수 있다)
@visibleForTesting
String premiumErrorTag(Object e) => switch (e) {
  PlatformException(:final code) => 'PlatformException($code)',
  InAppPurchaseException(:final code) => 'InAppPurchaseException($code)',
  IAPError(:final code) => 'IAPError($code)',
  _ => e.runtimeType.toString(),
};

/// 소유 조회에서 거래 하나가 말해 주는 것
enum _Evidence { owned, pending, unreadable, none }

/// 사용자가 시작한 구매 하나. 시작할 때 이미 가진 거래([priorKeys])는 이 구매의 결과로 보지 않는다
class _Attempt {
  _Attempt(this.config, this.priorKeys);

  final PremiumProductConfig config;
  final Set<String> priorKeys;
  final completer = Completer<PurchaseOutcome>();
}

/// 승인 대기로 끝난 사용자 구매. 앱을 다시 켠 뒤 승인돼도 한 번만 기록하려고 저장한다(거래 id·토큰은 해시로만)
class _PendingPurchase {
  _PendingPurchase({required this.productId, required this.period, required this.priorTags, required this.at});

  final String productId;
  final PremiumPeriod? period;
  final Set<String> priorTags;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'productId': productId,
    'period': period?.name,
    'prior': priorTags.toList(),
    'at': at.millisecondsSinceEpoch,
  };

  static _PendingPurchase? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final productId = json['productId'];
    final prior = json['prior'];
    final at = json['at'];
    if (productId is! String) return null;
    return _PendingPurchase(
      productId: productId,
      period: PremiumPeriod.values.asNameMap()[json['period']],
      priorTags: prior is List ? prior.whereType<String>().toSet() : const <String>{},
      at: at is num ? DateTime.fromMillisecondsSinceEpoch(at.toInt()) : DateTime.now(),
    );
  }
}

/// App Store·Google Play 구독을 in_app_purchase umbrella로 확인한다(iOS·Android 공통). 서버 검증 없음.
/// 권한은 성공한 소유 조회(restorePurchases) 결과로만 정한다: iOS는 검증된 Transaction.currentEntitlements만 돌려주고
/// Android는 purchaseState가 purchased인 구매만 인정한다. 스트림의 purchased는 다시 조회하라는 신호일 뿐이다
/// (StoreKit 직접 구매 이벤트는 검증되지 않은 거래일 수 있다). 조회가 실패하면 열린 쪽으로 가지 않는다(확인 중).
/// 다시 조회하는 때: 시작, purchased·취소·오류 이벤트, 앱이 다시 앞으로 올 때, iOS 만료 시각, 확인(acknowledge) 재시도.
/// 캐시는 '써 본 적 있음(만료 표시)'·Android 플랜·승인 대기 구매 기록에만 쓰고 잠금 해제에는 쓰지 않는다.
class InAppPurchaseEntitlementService with WidgetsBindingObserver implements EntitlementService {
  InAppPurchaseEntitlementService({
    InAppPurchase? iap,
    AnalyticsService? analytics,
    @visibleForTesting bool? debugOverrideAllowed,
    @visibleForTesting Duration restoreSettle = const Duration(seconds: 1),
    @visibleForTesting Duration ackRetryDelay = const Duration(seconds: 10),
    @visibleForTesting Future<bool> Function(Uri url)? launch,
  }) : _analytics = analytics,
       _debugOverrideAllowed = debugOverrideAllowed,
       _restoreSettle = restoreSettle,
       _ackRetryBase = ackRetryDelay,
       _ackDelay = ackRetryDelay,
       _launch = launch ?? ((url) => launchUrl(url, mode: LaunchMode.externalApplication)) {
    // 앱 시작 때 만들어지므로(lazy: false) 절대 throw하지 않는다: 저장값이 깨졌거나 스토어 플러그인이 없으면 '없음'으로 둔다
    _readCache();
    _debugOverride = _overrideAllowed && _readDebugOverride();
    _publish();
    try {
      final store = iap ?? InAppPurchase.instance;
      _subscription = store.purchaseStream.listen(_onPurchases, onError: _onStreamError, onDone: _onStreamDone);
      _iap = store;
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
      unawaited(_start());
    } catch (e) {
      Logger.error('[Premium] init: ${premiumErrorTag(e)}');
      _iap = null;
      unawaited(_subscription?.cancel());
      _subscription = null;
      _setStore(const PremiumState(PremiumStatus.none));
    }
  }

  final AnalyticsService? _analytics;
  final bool? _debugOverrideAllowed;
  final Duration _restoreSettle;
  final Duration _ackRetryBase;
  final Future<bool> Function(Uri url) _launch;
  final _prefs = SharedPrefsRepository();
  final _state = ValueNotifier(const PremiumState(PremiumStatus.verifying));

  /// null = 스토어를 쓸 수 없다(플러그인 시작 실패)
  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _observing = false;

  /// 스토어가 확인해 준 상태(강제 켜기와 별개)
  PremiumState _storeState = const PremiumState(PremiumStatus.verifying);

  /// 지난번에 확인한 사용 중·만료 상태. null = 써 본 적 없음
  PremiumState? _cached;
  _PendingPurchase? _pendingPurchase;
  bool _debugOverride = false;
  bool _isAvailable = false;
  bool _disposed = false;
  final _storeProducts = <PremiumProductConfig, ProductDetails>{};
  _Attempt? _attempt;
  Future<void>? _querying;
  Future<void>? _queuedQuery;

  /// 진행 중인 소유 조회가 받은 거래
  List<PurchaseDetails>? _restoredBatch;
  bool _lateRetried = false;

  /// 마지막으로 성공한 소유 조회에서 인정된 거래(iOS 거래 id / Android 구매 토큰). 조회가 실패하면 비운다
  final _ownedKeys = <String>{};
  bool _queried = false;

  /// 완료(iOS finish / Android acknowledge) 중인 거래, 확인을 기다리는 Android 거래(재시도·재개·복원 때 비운다),
  /// 끝난 iOS 거래(finish는 되돌릴 일이 없어 이번 실행 동안 다시 하지 않는다)
  final _completing = <String>{};
  final _attempted = <String>{};
  final _finished = <String>{};
  Duration _ackDelay;
  Timer? _ackRetry;

  /// 구매 완료 이벤트를 남긴 거래
  final _logged = <String>{};
  Timer? _expiryTimer;

  /// 이보다 오래된 승인 대기는 이 앱의 구매로 보지 않는다(Ask to Buy·Play 대기 결제는 며칠 안에 끝난다)
  static const _pendingTtl = Duration(days: 7);
  static const _ackRetryMax = Duration(minutes: 15);

  bool get _overrideAllowed => _debugOverrideAllowed ?? premiumDebugOverrideAllowed();

  @override
  ValueListenable<PremiumState> get state => _state;

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get debugOverride => _debugOverride && _overrideAllowed;

  /// 시작할 때 스토어에서 권한을 다시 받는다. 그전까지는 verifying(캐시가 사용 중이어도 열지 않음)
  Future<void> _start() async {
    final iap = _iap;
    if (iap == null) return;
    try {
      _isAvailable = await iap.isAvailable();
    } catch (e) {
      Logger.error('[Premium] isAvailable: ${premiumErrorTag(e)}');
    }
    try {
      await _query();
    } catch (e) {
      Logger.error('[Premium] restore: ${premiumErrorTag(e)}');
      // 스토어를 확인하지 못했다: 써 본 적 없으면 '없음', 있으면 확인 중으로 둔다
      if (_storeState.status == PremiumStatus.verifying && _cached == null) {
        _setStore(const PremiumState(PremiumStatus.none));
      }
    }
  }

  /// 사용자가 누른 복원. 확인(acknowledge)을 미뤄 둔 구매도 바로 다시 시도한다
  @override
  Future<void> restore() {
    _attempted.clear();
    return _query();
  }

  /// 조용한 소유 조회(iOS는 currentEntitlements, AppStore.sync 아님). 진행 중이면 끝난 뒤 한 번 더 한다
  Future<void> _query() {
    final running = _querying;
    if (running == null) return _querying = _queryOwnership().whenComplete(() => _querying = null);
    return _queuedQuery ??= running.then((_) {}, onError: (Object _) {}).then((_) {
      _queuedQuery = null;
      return _query();
    });
  }

  /// 새로 확인했으면 true
  Future<bool> _silentQuery() async {
    try {
      await _query();
      return true;
    } catch (e) {
      Logger.error('[Premium] restore: ${premiumErrorTag(e)}');
      return false;
    }
  }

  Future<void> _queryOwnership() async {
    final iap = _iap;
    if (iap == null) throw StateError('store unavailable');
    final batch = _restoredBatch = [];
    try {
      await iap.restorePurchases();
      // ponytail: iOS는 복원 완료 응답이 복원 거래 이벤트보다 먼저 올 수 있어 잠깐 기다린다. 늦게 온 거래는 한 번 더 조회한다
      await Future<void>.delayed(_restoreSettle);
    } catch (_) {
      // 새로 확인하지 못했다: 지난 증거로 확인하지 않고, 쓰던 권한은 확인 중으로 닫는다(실패가 열린 쪽으로 가지 않게)
      _ownedKeys.clear();
      if (_storeState.status == PremiumStatus.active) _setStore(const PremiumState(PremiumStatus.verifying));
      rethrow;
    } finally {
      _restoredBatch = null;
    }
    if (!_disposed) _apply(batch);
  }

  /// 성공한 소유 조회 결과로만 상태를 정한다
  void _apply(List<PurchaseDetails> batch) {
    _queried = true;
    if (batch.isNotEmpty) _lateRetried = false;
    final ours = batch.where((p) => _isOurs(p.productID)).toList();
    final evidence = [for (final p in ours) _evidenceOf(p)];
    final owned = [
      for (final (i, p) in ours.indexed)
        if (evidence[i] == _Evidence.owned) p,
    ];
    _ownedKeys
      ..clear()
      ..addAll(owned.map(_txKey));
    if (owned.isNotEmpty) {
      final best = owned.reduce(_laterOf);
      final expiresAt = _expiresAtOf(best);
      _setStore(
        PremiumState(
          PremiumStatus.active,
          expiresAt: expiresAt,
          productId: best.productID,
          period: _periodOf(best.productID),
        ),
      );
      _watchExpiry(expiresAt);
    } else if (evidence.contains(_Evidence.pending)) {
      _setStore(PremiumState(PremiumStatus.pending, productId: ours[evidence.indexOf(_Evidence.pending)].productID));
    } else if (evidence.contains(_Evidence.unreadable)) {
      // R11: 만료일을 읽지 못하면 열지 않고 확인 중으로 둔다
      _setStore(const PremiumState(PremiumStatus.verifying));
    } else {
      final cached = _cached;
      _setStore(
        cached == null
            ? const PremiumState(PremiumStatus.none)
            : PremiumState(
              PremiumStatus.expired,
              expiresAt: cached.expiresAt,
              productId: cached.productId,
              period: cached.period,
            ),
      );
    }
    _settleFromOwnership(owned);
    _acknowledge(owned);
  }

  /// 소유 조회로 사용자 구매를 끝내고 한 번 기록한다: 스트림 이벤트를 놓쳤어도, 앱을 다시 켠 뒤 승인됐어도.
  /// 구매를 시작할 때 이미 가진 거래와 갱신은 이 구매의 결과로 보지 않는다
  void _settleFromOwnership(List<PurchaseDetails> owned) {
    final attempt = _attempt;
    if (attempt != null) {
      final bought = owned.firstWhereOrNull(
        (p) => p.productID == attempt.config.storeId && !_isRenewal(p) && !attempt.priorKeys.contains(_txKey(p)),
      );
      if (bought != null) {
        _logOnce(_txKey(bought), attempt.config.period);
        _settle(PurchaseOutcome.purchased);
      }
    }
    final pending = _pendingPurchase;
    if (pending == null) return;
    final stale = DateTime.now().difference(pending.at) >= _pendingTtl;
    final approved =
        stale
            ? null
            : owned.firstWhereOrNull(
              (p) => p.productID == pending.productId && !_isRenewal(p) && !pending.priorTags.contains(_tag(_txKey(p))),
            );
    if (approved == null && !stale) return;
    // 소비했다는 것을 먼저 저장한다(다시 켜도 같은 구매를 또 세지 않게)
    _pendingPurchase = null;
    _saveCache();
    if (approved != null) _logOnce(_txKey(approved), pending.period);
  }

  /// 기간만 보낸다(거래 id·토큰은 보내지 않는다)
  void _logOnce(String key, PremiumPeriod? period) {
    if (period == null || !_logged.add(key)) return;
    _analytics?.logPremiumPurchaseCompleted(period);
  }

  /// Android: 확인(acknowledge)하지 않은 구매는 3일 뒤 환불된다. 확인되지 않은 채로 남으면 점점 길게 기다려 다시 시도한다
  /// (앱이 다시 앞으로 오거나 복원을 누르면 바로). 바로 되풀이하지 않고, 확인되거나 소유가 사라지거나 닫히면 멈춘다
  void _acknowledge(List<PurchaseDetails> owned) {
    final unacknowledged = owned.where((p) => p.pendingCompletePurchase).toList();
    for (final p in unacknowledged) {
      unawaited(_completeOnce(p));
    }
    if (unacknowledged.isEmpty) {
      _ackRetry?.cancel();
      _ackRetry = null;
      _ackDelay = _ackRetryBase;
    } else {
      _scheduleAckRetry();
    }
  }

  /// 확인 대기는 조회가 실패해도 남는다: 실패하면 다음 단계(점점 길게, 최대 15분)로 다시 잡는다.
  /// 성공한 조회가 확인됨·소유 없음을 보여 주거나([_acknowledge]) 닫히면 멈춘다
  void _scheduleAckRetry() {
    if (_disposed || (_ackRetry?.isActive ?? false)) return;
    final delay = _ackDelay;
    _ackDelay = delay * 2 > _ackRetryMax ? _ackRetryMax : delay * 2;
    _ackRetry = Timer(delay, () async {
      _attempted.clear();
      if (!await _silentQuery()) _scheduleAckRetry();
    });
  }

  /// 플랫폼별로 있어야 할 증거가 있을 때만 owned(없거나 이상하면 열지 않는다)
  static _Evidence _evidenceOf(PurchaseDetails p) {
    if (p is GooglePlayPurchaseDetails) {
      // 복원은 바깥 상태를 restored로 덮어쓰므로 안쪽 purchaseState를 본다. 미지정 상태는 열지 않는다
      return switch (p.billingClientPurchase.purchaseState) {
        PurchaseStateWrapper.purchased => _Evidence.owned,
        PurchaseStateWrapper.pending => _Evidence.pending,
        _ => _Evidence.none,
      };
    }
    final json = _transactionJson(p);
    if (json == null) return _Evidence.unreadable;
    if (json['revocationDate'] != null) return _Evidence.none;
    if (_configsOf(p.productID).first.kind == PremiumProductKind.oneTimePurchase) return _Evidence.owned;
    final expiresAt = _msToDate(json['expiresDate']);
    if (expiresAt == null) return _Evidence.unreadable;
    return expiresAt.isAfter(DateTime.now()) ? _Evidence.owned : _Evidence.none;
  }

  /// 더 늦게 끝나는 쪽(만료일 없음 = Android·일회 구매가 가장 늦다)
  static PurchaseDetails _laterOf(PurchaseDetails a, PurchaseDetails b) {
    final aEnds = _expiresAtOf(a);
    final bEnds = _expiresAtOf(b);
    if (aEnds == null) return a;
    if (bEnds == null) return b;
    return bEnds.isAfter(aEnds) ? b : a;
  }

  /// 만료 시각이 오면 닫고 다시 조회한다(갱신됐으면 새 거래가 온다). 앱이 멈춰 있던 동안은 앞으로 올 때 조회한다
  void _watchExpiry(DateTime? expiresAt) {
    _expiryTimer?.cancel();
    _expiryTimer =
        expiresAt == null
            ? null
            : Timer(expiresAt.difference(DateTime.now()) + const Duration(seconds: 1), () {
              // 갱신을 새로 확인하기 전까지 닫는다(조회가 실패해도 열린 채로 두지 않는다)
              if (_storeState.status == PremiumStatus.active) _setStore(const PremiumState(PremiumStatus.verifying));
              unawaited(_silentQuery());
            });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _disposed) return;
    // 밖에서 해지·환불·만료됐을 수 있고, 확인(acknowledge)되지 않은 구매는 이때 바로 다시 시도한다
    _attempted.clear();
    unawaited(_silentQuery());
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    if (_disposed) return;
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.restored:
          final batch = _restoredBatch;
          if (batch != null) {
            batch.add(p);
          } else if (_isOurs(p.productID) && !_lateRetried) {
            _lateRetried = true;
            unawaited(_silentQuery());
          }
        case PurchaseStatus.purchased:
          if (_isOurs(p.productID)) unawaited(_confirm(p));
        case PurchaseStatus.pending:
          _onPending(p);
        case PurchaseStatus.canceled:
          _onEnded(p, PurchaseOutcome.cancelled);
        case PurchaseStatus.error:
          Logger.error('[Premium] purchase error: ${p.error?.code}');
          _onEnded(p, PurchaseOutcome.failed);
      }
    }
  }

  /// purchased는 검증되지 않았을 수 있다(StoreKit 직접 구매): 새로 성공한 소유 조회로 인정된 거래만 완료한다.
  /// 구매 결과·기록은 조회([_settleFromOwnership])가 정하고, 여기서는 조회로 끝나지 않은 이 구매의 새 거래만 다룬다
  Future<void> _confirm(PurchaseDetails p) async {
    final key = _txKey(p);
    final attempt = _attempt;
    // 쓰던 거래가 무효가 됐다(환불·만료): 새로 확인할 때까지 닫는다
    if (_storeState.status == PremiumStatus.active && _ownedKeys.contains(key) && _evidenceOf(p) != _Evidence.owned) {
      _setStore(const PremiumState(PremiumStatus.verifying));
    }
    final fresh = await _silentQuery();
    if (_disposed) return;
    if (fresh && key.isNotEmpty && _ownedKeys.contains(key)) unawaited(_completeOnce(p));
    if (attempt == null || !identical(_attempt, attempt)) return;
    // 지난 거래·다른 상품·갱신은 이 구매와 무관하다
    if (p.productID != attempt.config.storeId || _isRenewal(p) || attempt.priorKeys.contains(key)) return;
    if (fresh) {
      _settle(PurchaseOutcome.failed); // 새로 조회해도 인정되지 않은 직접 구매(검증 실패)
    } else {
      _rememberPending(attempt); // 확인하지 못했다: 확인되면 자동으로 켜지고, 그때 한 번 기록한다
      _settle(PurchaseOutcome.pending);
    }
  }

  void _rememberPending(_Attempt attempt) {
    _pendingPurchase = _PendingPurchase(
      productId: attempt.config.storeId,
      period: attempt.config.period,
      priorTags: attempt.priorKeys.map(_tag).toSet(),
      at: DateTime.now(),
    );
    _saveCache();
  }

  void _onPending(PurchaseDetails p) {
    final attempt = _attempt;
    if (attempt != null && attempt.config.storeId == p.productID) {
      _rememberPending(attempt);
      _settle(PurchaseOutcome.pending);
    }
    if (_isOurs(p.productID) && !_storeState.isActive) {
      _setStore(PremiumState(PremiumStatus.pending, productId: p.productID));
    }
  }

  void _onEnded(PurchaseDetails p, PurchaseOutcome outcome) {
    final attempt = _attempt;
    // Android 취소·오류 이벤트는 상품 id가 비어 온다
    if (attempt != null && (p.productID.isEmpty || attempt.config.storeId == p.productID)) _settle(outcome);
    if (p.productID.isNotEmpty && _pendingPurchase?.productId == p.productID) {
      _pendingPurchase = null; // 승인 대기가 거절·취소됐다
      _saveCache();
    }
    // 승인 대기 표시는 스토어에 다시 물어 정리한다
    if (_storeState.status == PremiumStatus.pending) unawaited(_silentQuery());
  }

  void _settle(PurchaseOutcome outcome) {
    final attempt = _attempt;
    _attempt = null;
    if (attempt != null && !attempt.completer.isCompleted) attempt.completer.complete(outcome);
  }

  void _onStreamError(Object e) {
    Logger.error('[Premium] purchaseStream: ${premiumErrorTag(e)}');
    _settle(PurchaseOutcome.failed);
  }

  void _onStreamDone() => _settle(PurchaseOutcome.failed);

  /// 거래마다 완료는 한 번에 하나, 주기마다 한 번. Android 결과 코드는 umbrella에 안 보이므로
  /// 새 소유 조회의 isAcknowledged로 확인한다(안 됐으면 [_acknowledge]가 재시도를 잡는다)
  Future<void> _completeOnce(PurchaseDetails p) async {
    final iap = _iap;
    final key = _txKey(p);
    if (iap == null || key.isEmpty || _completing.contains(key) || _finished.contains(key) || !_attempted.add(key)) {
      return;
    }
    _completing.add(key);
    var ok = false;
    try {
      await iap.completePurchase(p);
      ok = true;
    } catch (e) {
      Logger.error('[Premium] completePurchase: ${premiumErrorTag(e)}');
    } finally {
      _completing.remove(key);
    }
    if (p is GooglePlayPurchaseDetails) {
      if (!_disposed) unawaited(_silentQuery());
    } else if (ok) {
      _finished.add(key);
    }
  }

  /// 거래 하나를 가리키는 값: Android는 구매 토큰, iOS는 거래 id
  static String _txKey(PurchaseDetails p) =>
      p is GooglePlayPurchaseDetails ? p.verificationData.serverVerificationData : p.purchaseID ?? '';

  /// 저장용 거래 표시(원래 값은 저장하지 않는다)
  static String _tag(String key) => generateHashString(key).substring(0, 16);

  /// iOS 자동 갱신 거래(사용자가 산 것이 아님). Android 구매 JSON엔 이유가 없고, 갱신은 같은 토큰이라 [_Attempt.priorKeys]로 걸러진다
  static bool _isRenewal(PurchaseDetails p) => _transactionJson(p)?['transactionReason'] == 'RENEWAL';

  static List<PremiumProductConfig> _configsOf(String productId) =>
      kPremiumProducts.where((c) => c.storeId == productId).toList();

  static bool _isOurs(String productId) => kPremiumProducts.any((c) => c.storeId == productId);

  PremiumPeriod? _periodOf(String productId) {
    final configs = _configsOf(productId);
    if (configs.length == 1) return configs.single.period;
    // Android 구매에는 base plan이 없다: 진행 중인 구매, 승인 대기 기록, 지난번 기록 순
    if (_attempt?.config.storeId == productId) return _attempt!.config.period;
    if (_pendingPurchase?.productId == productId) return _pendingPurchase!.period;
    return _cached?.productId == productId ? _cached!.period : null;
  }

  /// iOS(StoreKit 2)는 localVerificationData가 거래 JSON(expiresDate·revocationDate·transactionReason, ms). Android 구매 JSON엔 만료일이 없다
  static Map<String, dynamic>? _transactionJson(PurchaseDetails p) {
    try {
      final json = jsonDecode(p.verificationData.localVerificationData);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }

  static DateTime? _expiresAtOf(PurchaseDetails p) => _msToDate(_transactionJson(p)?['expiresDate']);

  static DateTime? _msToDate(Object? ms) => ms is num ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()) : null;

  void _setStore(PremiumState next) {
    if (_disposed) return;
    _storeState = next;
    if (next.status == PremiumStatus.active || next.status == PremiumStatus.expired) {
      _cached = next;
      _saveCache();
    }
    if (next.status != PremiumStatus.active) _watchExpiry(null);
    _publish();
  }

  void _publish() => _state.value = debugOverride ? const PremiumState(PremiumStatus.active) : _storeState;

  /// 깨졌거나 다른 형식의 값은 없는 것으로(생성이 throw하지 않게)
  void _readCache() {
    try {
      if (!_prefs.isInitialized) return;
      final raw = _prefs.getStringOrNull(SharedPrefKeys.kPremiumEntitlementCache);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final status = PremiumStatus.values.asNameMap()[json['status']];
      if (status != null) {
        _cached = PremiumState(
          status,
          expiresAt: _msToDate(json['expiresAt']),
          productId: json['productId'] as String?,
          period: PremiumPeriod.values.asNameMap()[json['period']],
        );
      }
      _pendingPurchase = _PendingPurchase.fromJson(json['pending']);
    } catch (e) {
      Logger.error('[Premium] cache: ${premiumErrorTag(e)}');
    }
  }

  bool _readDebugOverride() {
    try {
      return _prefs.isInitialized && _prefs.getBool(SharedPrefKeys.kPremiumDebugOverride);
    } catch (e) {
      Logger.error('[Premium] debug override: ${premiumErrorTag(e)}');
      return false;
    }
  }

  void _saveCache() {
    if (!_prefs.isInitialized) return;
    final cached = _cached;
    final pending = _pendingPurchase;
    final json = {
      if (cached != null) ...{
        'status': cached.status.name,
        'productId': cached.productId,
        'period': cached.period?.name,
        'expiresAt': cached.expiresAt?.millisecondsSinceEpoch,
      },
      if (pending != null) 'pending': pending.toJson(),
    };
    unawaited(_writeCache(jsonEncode(json)));
  }

  Future<void> _writeCache(String json) async {
    try {
      await _prefs.setString(SharedPrefKeys.kPremiumEntitlementCache, json);
    } catch (e) {
      Logger.error('[Premium] cache: ${premiumErrorTag(e)}');
    }
  }

  @override
  Future<List<PremiumProduct>> loadProducts() async {
    final iap = _iap;
    if (iap == null) {
      _isAvailable = false;
      return const [];
    }
    try {
      _isAvailable = await iap.isAvailable();
      if (!_isAvailable) return const [];
      final response = await iap.queryProductDetails(kPremiumProducts.map((c) => c.storeId).toSet());
      if (response.error != null) Logger.error('[Premium] queryProductDetails: ${response.error!.code}');
      _storeProducts.clear();
      final products = <PremiumProduct>[];
      for (final config in kPremiumProducts) {
        final details = _storeProductFor(config, response.productDetails);
        if (details == null) continue;
        _storeProducts[config] = details;
        products.add(
          PremiumProduct(config: config, price: _recurringPrice(details), freeTrialDays: await _freeTrialDays(details)),
        );
      }
      return products;
    } catch (e) {
      Logger.error('[Premium] loadProducts: ${premiumErrorTag(e)}');
      return const [];
    }
  }

  /// Android 구독은 base plan·혜택마다 따로 온다: 이 base plan의 무료 체험 혜택(받을 수 있는 것만 온다), 없으면 기본 요금제
  static ProductDetails? _storeProductFor(PremiumProductConfig config, List<ProductDetails> all) {
    final candidates = all.where((d) => d.id == config.storeId);
    if (config.basePlanId == null) return candidates.firstOrNull;
    final offers = candidates.whereType<GooglePlayProductDetails>().where(
      (d) => _offerOf(d)?.basePlanId == config.basePlanId,
    );
    return offers.firstWhereOrNull((d) => _offerOf(d)!.offerId != null && _trialPhaseOf(d) != null) ??
        offers.firstWhereOrNull((d) => _offerOf(d)!.offerId == null);
  }

  static SubscriptionOfferDetailsWrapper? _offerOf(GooglePlayProductDetails d) {
    final index = d.subscriptionIndex;
    return index == null ? null : d.productDetails.subscriptionOfferDetails?[index];
  }

  static PricingPhaseWrapper? _trialPhaseOf(GooglePlayProductDetails d) =>
      _offerOf(d)?.pricingPhases.firstWhereOrNull((phase) => phase.priceAmountMicros == 0);

  /// 스토어 가격 문자열 그대로. Android 체험 혜택은 첫 단계가 무료라 마지막(정기 결제) 단계 가격을 쓴다
  static String _recurringPrice(ProductDetails d) =>
      d is GooglePlayProductDetails ? _offerOf(d)?.pricingPhases.last.formattedPrice ?? d.price : d.price;

  static Future<int?> _freeTrialDays(ProductDetails d) async {
    if (d is GooglePlayProductDetails) {
      final phase = _trialPhaseOf(d);
      final days = phase == null ? null : _isoDays(phase.billingPeriod);
      return days == null ? null : days * phase!.billingCycleCount;
    }
    if (d is AppStoreProduct2Details) {
      final offer = d.sk2Product.subscription?.promotionalOffers.firstWhereOrNull(
        (o) =>
            o.type == SK2SubscriptionOfferType.introductory &&
            o.paymentMode == SK2SubscriptionOfferPaymentMode.freeTrial,
      );
      final unitDays = switch (offer?.period.unit) {
        SK2SubscriptionPeriodUnit.day => 1,
        SK2SubscriptionPeriodUnit.week => 7,
        _ => null,
      };
      if (offer == null || unitDays == null) return null;
      try {
        // 이미 체험한 사용자에게는 체험 문구를 보이지 않는다
        if (!await SK2Product.isIntroductoryOfferEligible(d.id)) return null;
      } catch (e) {
        return null;
      }
      return unitDays * offer.period.value * offer.periodCount;
    }
    return null;
  }

  /// ponytail: 체험 기간은 일·주 단위만 'N일'로 보여 준다(월·년 체험은 표시 안 함 → 콘솔에서 일·주로 설정)
  static int? _isoDays(String period) {
    final match = RegExp(r'^P(\d+)([DW])$').firstMatch(period);
    return match == null ? null : int.parse(match[1]!) * (match[2] == 'W' ? 7 : 1);
  }

  @override
  Future<PurchaseOutcome> purchase(PremiumProduct product) async {
    final iap = _iap;
    final details = _storeProducts[product.config];
    if (iap == null || _disposed || !_isAvailable || details == null) return PurchaseOutcome.unavailable;
    final running = _attempt;
    if (running != null) return running.completer.future;
    // 이미 가진 거래를 알아야 새 구매와 구분한다: 시작 조회가 아직이면 먼저 조회한다
    if (!_queried) await _silentQuery();
    final started = _attempt;
    if (started != null) return started.completer.future;
    if (_disposed) return PurchaseOutcome.unavailable;
    final attempt = _attempt = _Attempt(product.config, {..._ownedKeys});
    try {
      // 구독도 이 플러그인에선 비소모성 구매로 산다(Android는 고른 혜택의 offerToken을 쓴다)
      if (!await iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details))) {
        if (identical(_attempt, attempt)) _settle(PurchaseOutcome.failed);
      }
    } catch (e) {
      Logger.error('[Premium] buyNonConsumable: ${premiumErrorTag(e)}');
      if (identical(_attempt, attempt)) _settle(PurchaseOutcome.failed);
    }
    return attempt.completer.future;
  }

  @override
  Future<void> openManageSubscriptions() async {
    final Uri uri;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final packageName = (await PackageInfo.fromPlatform()).packageName;
      uri = Uri.https('play.google.com', '/store/account/subscriptions', {
        'package': packageName,
        'sku': kPlayStorePremiumProducts.first.storeId,
      });
    } else {
      uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    }
    if (!await _launch(uri)) throw StateError('subscription management did not open');
  }

  @override
  Future<void> setDebugOverride(bool enabled) async {
    if (!_overrideAllowed || _disposed) return;
    _debugOverride = enabled;
    _publish();
    if (_prefs.isInitialized) await _prefs.setBool(SharedPrefKeys.kPremiumDebugOverride, enabled);
  }

  @override
  void dispose() {
    _disposed = true;
    _settle(PurchaseOutcome.failed);
    _expiryTimer?.cancel();
    _ackRetry?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _state.dispose();
  }
}
