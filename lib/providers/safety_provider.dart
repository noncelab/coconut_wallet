import 'dart:async';

import 'package:coconut_wallet/analytics/safety_analytics.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/shared_preference/safety_store.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/app_version_service.dart';
import 'package:coconut_wallet/services/model/response/app_version_response.dart';
import 'package:coconut_wallet/services/safety/incident_detector.dart';
import 'package:coconut_wallet/services/safety/safety_engine.dart';
import 'package:coconut_wallet/services/safety/safety_inputs_collector.dart';
import 'package:coconut_wallet/services/safety/server_cert_probe.dart';
import 'package:coconut_wallet/services/safety/wallet_verification.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef SafetyAlertItem = ({String key, SafetyIncident? incident, SafetyCheckResult? check, bool unread});

class SafetyProvider extends ChangeNotifier {
  SafetyProvider({
    required WalletProvider walletProvider,
    required NodeProvider nodeProvider,
    required AuthProvider authProvider,
    required ConnectivityProvider connectivityProvider,
    required RealmManager realmManager,
    required AnalyticsService analytics,
    SafetyStore? store,
    Future<AppUpdateStatus> Function()? checkAppUpdate,
    Future<ServerCertObservation?> Function(NodeProvider)? probeServerCert,
    DateTime Function()? now,
    Duration debounce = const Duration(milliseconds: 400),
  }) : _wallets = walletProvider,
       _node = nodeProvider,
       _auth = authProvider,
       _connectivity = connectivityProvider,
       _analytics = analytics,
       _store = store ?? SafetyStore(SharedPrefsRepository()),
       _checkAppUpdate = checkAppUpdate ?? _defaultCheckAppUpdate,
       _probeServerCert = probeServerCert,
       _certProbe = probeServerCert == null ? ServerCertProbe() : null,
       _now = now ?? DateTime.now,
       _debounce = debounce,
       _collector = SafetyInputsCollector(
         walletProvider: walletProvider,
         nodeProvider: nodeProvider,
         authProvider: authProvider,
         connectivityProvider: connectivityProvider,
         realmManager: realmManager,
       ) {
    _state = _store!.load();
    _vibratedIncidents.addAll(_state.incidents.map((incident) => incident.id));
    final cachedCert = _state.serverCert;
    if (cachedCert != null &&
        cachedCert.host == nodeProvider.host &&
        cachedCert.port == nodeProvider.port &&
        nodeProvider.ssl) {
      _observedServer = _serverIdentity;
      _serverCert = ServerCertObservation(
        applicable: true,
        pinned: nodeProvider.pinnedCertFingerprint,
        actual: cachedCert.fingerprint,
        endValidity: cachedCert.endValidity,
        caValid: cachedCert.caValid,
      );
    }
    walletProvider.walletLoadStateNotifier.addListener(_schedule);
    walletProvider.walletItemListNotifier.addListener(_schedule);
    walletProvider.addListener(_schedule);
    authProvider.addListener(_schedule);
    connectivityProvider.addListener(_schedule);
    nodeProvider.addListener(_onNodeChanged);
    nodeProvider.currentBlockNotifier.addListener(_schedule);
    _syncSubscription = nodeProvider.syncStateStream.listen(_onSync);
    _walletSubscription = walletProvider.lifecycleEvents.listen(_onWalletEvent);
    _schedule();
    unawaited(_checkExternal().catchError((_) {}));
  }

  @visibleForTesting
  SafetyProvider.fixed(this._report, {SafetyState? state})
    : _wallets = null,
      _node = null,
      _auth = null,
      _connectivity = null,
      _analytics = null,
      _store = null,
      _collector = null,
      _checkAppUpdate = _defaultCheckAppUpdate,
      _probeServerCert = null,
      _certProbe = null,
      _now = DateTime.now,
      _debounce = const Duration(milliseconds: 400) {
    _state = state ?? SafetyState.initial();
  }

  final WalletProvider? _wallets;
  final NodeProvider? _node;
  final AuthProvider? _auth;
  final ConnectivityProvider? _connectivity;
  final AnalyticsService? _analytics;
  final SafetyStore? _store;
  final SafetyInputsCollector? _collector;
  final Future<AppUpdateStatus> Function() _checkAppUpdate;
  final Future<ServerCertObservation?> Function(NodeProvider)? _probeServerCert;
  final ServerCertProbe? _certProbe;
  final DateTime Function() _now;
  final Duration _debounce;
  late SafetyState _state;
  WalletHealthReport? _report;
  bool _isChecking = false;
  bool _disposed = false;
  bool _refreshPending = false;
  Timer? _timer;
  Future<void>? _refreshFuture, _checkFuture, _externalFuture;
  StreamSubscription<NodeSyncState>? _syncSubscription;
  StreamSubscription<WalletLifecycleEvent>? _walletSubscription;
  DateTime? _successfulSyncAt;
  (String, int, bool, String?)? _successfulSyncServer;
  AppUpdateStatus _appUpdate = AppUpdateStatus.unknown;
  ServerCertObservation? _serverCert;
  (String, int, bool, String?)? _observedServer;
  final Set<String> _vibratedIncidents = {};

  WalletHealthReport? get report => _report;
  bool get isChecking => _isChecking;
  SafetyState get state => _state;

  List<SafetyAlertItem> get alertItems {
    final report = _report;
    if (report == null) return const [];
    final items = <SafetyAlertItem>[];
    for (final incident in [...report.criticalIncidents, ...report.infoIncidents]) {
      final key = 'incident:${incident.id}';
      items.add((key: key, incident: incident, check: null, unread: !_state.readItemIds.contains(key)));
    }
    for (final check in report.reviewItems) {
      if (check.id == SafetyCheckId.unrecognizedOutgoing ||
          (check.severity != SafetySeverity.critical && check.severity != SafetySeverity.actionNeeded)) {
        continue;
      }
      items.add((key: check.key, incident: null, check: check, unread: !_state.readItemIds.contains(check.key)));
    }
    items.sort((a, b) {
      int priority(SafetyAlertItem item) =>
          item.incident != null ? (item.incident!.isCritical ? 0 : 2) : item.check!.severity.index;
      return priority(a).compareTo(priority(b));
    });
    return items;
  }

  bool get hasUnreadAlerts =>
      alertItems.any((item) => item.unread && (item.incident?.isCritical == true || item.check != null));
  bool get showsHomeHint => !_state.hintDismissed && (_report?.walletCount ?? 0) > 0;
  bool isCaution(int walletId) => _state.cautionWalletIds.contains(walletId);

  SafetyIncident? incidentFor(int walletId, String txid) {
    for (final incident in _state.incidents) {
      if (incident.walletId == walletId && incident.txid == txid) return incident;
    }
    return null;
  }

  void _schedule() {
    if (_disposed) return;
    if (_successfulSyncAt != null && (!_hasCompletedSync || _successfulSyncServer != _serverIdentity)) {
      _successfulSyncAt = null;
    }
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(refresh().catchError((_) {})));
  }

  (String, int, bool, String?) get _serverIdentity => (_node!.host, _node.port, _node.ssl, _node.pinnedCertFingerprint);

  void _onNodeChanged() {
    _schedule();
    if (_observedServer != _serverIdentity) {
      _certProbe?.cancel();
      unawaited(_checkExternal().catchError((_) {}));
    }
  }

  bool get _hasCompletedSync =>
      _wallets!.walletLoadStateNotifier.value == WalletLoadState.loadCompleted &&
      _node!.isConnected &&
      _connectivity!.isInternetOn &&
      _node.state.nodeSyncState == NodeSyncState.completed &&
      _node.state.registeredWallets.isNotEmpty;

  void _onSync(NodeSyncState sync) {
    _successfulSyncAt = sync == NodeSyncState.completed && _hasCompletedSync ? _now() : null;
    _successfulSyncServer = _serverIdentity;
    _schedule();
  }

  void _onWalletEvent(WalletLifecycleEvent event) {
    if (event is WalletRemoved) {
      unawaited(_removeWallet(event.walletId).catchError((_) {}));
    } else {
      _schedule();
    }
  }

  Future<void> _removeWallet(int walletId) async {
    await _store!.removeWallet(walletId);
    if (_disposed) return;
    final previous = _state;
    _state = _store.load();
    final previousReport = _report;
    await refresh();
    if (!_disposed && previous != _state && previousReport == _report) notifyListeners();
  }

  Future<void> refresh() {
    if (_disposed || _collector == null) return Future.value();
    _timer?.cancel();
    _refreshPending = true;
    if (_refreshFuture != null) return _refreshFuture!;
    final done = Completer<void>();
    final future = _refreshFuture = done.future;
    done.complete(_evaluateLoop());
    return future;
  }

  Future<void> _evaluateLoop() async {
    try {
      while (_refreshPending && !_disposed) {
        _refreshPending = false;
        if (_wallets!.walletLoadStateNotifier.value != WalletLoadState.loadCompleted) return;
        final syncAt = _successfulSyncAt;
        if (syncAt != null &&
            _hasCompletedSync &&
            _successfulSyncServer == _serverIdentity &&
            _node!.currentBlockHeight > 0) {
          _successfulSyncAt = null;
          await _store!.update((s) => s.copyWith(lastSuccessfulSyncAt: syncAt));
        }
        if (_disposed) return;
        _state = _store!.load();
        var inputs = _collector!.collect(state: _state, now: _now(), appUpdate: _appUpdate, serverCert: _serverCert);
        final delta = IncidentDetector.detect(inputs);
        if (!delta.isEmpty) {
          await _store.update(delta.applyTo);
          if (_disposed) return;
          _state = _store.load();
          inputs = inputs.withState(_state);
        }
        final next = SafetyEngine.evaluate(inputs);
        for (final incident in next.criticalIncidents) {
          if (_vibratedIncidents.add(incident.id)) vibrateForIncident();
        }
        final changed = next != _report;
        _report = next;
        if (changed) notifyListeners();
      }
    } finally {
      _refreshFuture = null;
    }
  }

  @protected
  void vibrateForIncident() => vibrateMedium();

  Future<void> checkAgain() {
    if (_checkFuture != null) return _checkFuture!;
    final done = Completer<void>();
    final future = _checkFuture = done.future.whenComplete(() => _checkFuture = null);
    done.complete(_runCheck());
    return future;
  }

  Future<void> _runCheck() async {
    if (_disposed) return;
    _isChecking = true;
    notifyListeners();
    _analytics?.logSafetyCheckStarted();
    final minimum = Future<void>.delayed(const Duration(milliseconds: 1200));
    try {
      try {
        await _node?.reconnectIfNeeded();
      } catch (_) {
        // 재연결 실패 시에도 저장된 데이터로 점검한다.
      }
      await _checkExternal();
      await refresh();
    } finally {
      await minimum;
      if (!_disposed) {
        _isChecking = false;
        _analytics?.logSafetyCheckCompleted();
        notifyListeners();
      }
    }
  }

  Future<void> _checkExternal() => _externalFuture ??= _runExternalChecks().whenComplete(() => _externalFuture = null);

  Future<void> _runExternalChecks() async {
    if (_node == null || _disposed) return;
    do {
      final identity = _serverIdentity;
      if (_observedServer != identity) _serverCert = null;
      _observedServer = identity;
      await Future.wait([
        () async {
          try {
            final status = await _checkAppUpdate();
            if (!_disposed) _appUpdate = status;
          } catch (_) {
            if (!_disposed) _appUpdate = AppUpdateStatus.unknown;
          }
        }(),
        () async {
          try {
            final observation = await (_probeServerCert?.call(_node) ?? _certProbe!.probe(_node));
            if (_disposed || identity != _serverIdentity) return;
            if (observation?.actual != null || observation?.applicable == false || _serverCert == null) {
              _serverCert = observation;
            }
            if (observation?.applicable == true && observation?.actual != null) {
              await _store!.update(
                (s) => s.copyWith(
                  serverCert: ServerCertRecord(
                    host: identity.$1,
                    port: identity.$2,
                    fingerprint: observation!.actual!,
                    endValidity: observation.endValidity,
                    caValid: observation.caValid,
                    observedAt: _now(),
                  ),
                ),
              );
            }
          } catch (_) {
            // 같은 서버의 마지막 관찰은 오프라인에서도 유지한다.
          }
        }(),
      ]);
    } while (!_disposed && _observedServer != _serverIdentity);
    _schedule();
  }

  Future<void> _change(SafetyState Function(SafetyState) change) async {
    if (_disposed) return;
    final previous = _state;
    final previousReport = _report;
    _state = _store == null ? change(_state) : await _store.update(change);
    if (_disposed) return;
    await refresh();
    if (!_disposed && previous != _state && previousReport == _report) notifyListeners();
  }

  SafetyIncident _incident(SafetyState state, String id, {bool allowBaseline = false}) {
    for (final incident in state.incidents) {
      if (incident.id == id) return incident;
    }
    final separator = id.indexOf(':');
    final walletId = separator < 0 ? null : int.tryParse(id.substring(0, separator));
    final txid = separator < 0 ? '' : id.substring(separator + 1);
    final baseline = state.baselines[walletId];
    // 사건이 아닌 검토 항목: 기준점의 최근 출금, 앱이 만들지 않은 자기 앞 전송
    final reviewItem =
        baseline != null &&
        (baseline.pendingSentAtBaseline.contains(txid) || baseline.unexpectedSelfTxids.contains(txid));
    if (!allowBaseline || id != '$walletId:$txid' || !reviewItem || state.recognizedTxids.contains(txid)) {
      throw StateError('Unknown incident');
    }
    return SafetyIncident(walletId: walletId!, txid: txid, detectedAt: _now());
  }

  Future<void> recognizeIncident(String id) => _change((s) {
    final incident = _incident(s, id, allowBaseline: true);
    final next = incident.recognize(_now());
    // 기준점의 대기 출금은 사건을 만들지 않고 검토 항목만 닫는다.
    return s.copyWith(
      incidents: [
        for (final i in s.incidents)
          if (i.txid == next.txid && i.isOpen) i.recognize(next.resolvedAt!) else i,
      ],
      recognizedTxids: {...s.recognizedTxids, incident.txid},
    );
  });

  Future<void> markIncidentUnrecognized(String id, IncidentResponseMode mode) async {
    var started = false;
    await _change((s) {
      final incident = _incident(s, id, allowBaseline: true);
      final next = incident.respond(mode);
      started = incident.state == IncidentState.detected;
      return s.copyWith(
        incidents: [
          for (final i in s.incidents)
            if (i.id == id) next else i,
          if (!s.incidents.any((i) => i.id == id)) next,
        ],
      );
    });
    if (started) _analytics?.logIncidentResponseStarted(mode);
  }

  Future<void> setIncidentGuideStep(String id, int step, {DateTime? assistStartedAt}) {
    if (step < 0) throw ArgumentError.value(step, 'step');
    return _change((s) {
      final next = _incident(s, id).withGuideStep(step, assistStartedAt: assistStartedAt);
      return s.copyWith(
        incidents: [
          for (final i in s.incidents)
            if (i.id == id) next else i,
        ],
      );
    });
  }

  Future<void> completeIncident(String id) async {
    IncidentResponseMode? mode;
    await _change((s) {
      final incident = _incident(s, id);
      final next = incident.complete(_now());
      mode = incident.responseMode;
      return s.copyWith(
        incidents: [
          for (final i in s.incidents)
            if (i.id == id) next else i,
        ],
      );
    });
    if (mode != null) _analytics?.logIncidentResponseCompleted(mode!);
  }

  Future<void> setCaution(int walletId, bool caution) => _change((s) {
    final ids = {...s.cautionWalletIds};
    caution ? ids.add(walletId) : ids.remove(walletId);
    return s.copyWith(cautionWalletIds: ids);
  });

  Future<void> recordPassphraseVerified(int walletId) =>
      _change((s) => s.copyWith(passphraseVerifiedAt: {...s.passphraseVerifiedAt, walletId: _now()}));

  Future<void> recordWatchOnlyVerification(
    int walletId, {
    required VerificationMethod method,
    required VerificationResult result,
    int? matchedIndex,
  }) {
    if (matchedIndex != null && (matchedIndex < 0 || matchedIndex > 19)) throw ArgumentError.value(matchedIndex);
    final hash = WalletVerification.descriptorHash(_wallets!.getWalletById(walletId).descriptor);
    return _change(
      (s) => s.copyWith(
        watchOnlyVerifications: {
          ...s.watchOnlyVerifications,
          walletId: WatchOnlyVerification(
            method: method,
            result: result,
            matchedIndex: matchedIndex,
            descriptorHash: hash,
            at: _now(),
          ),
        },
      ),
    );
  }

  Future<void> recordBsmsVerification(int walletId, {required bool matched, required String configHash}) => _change(
    (s) =>
        s.copyWith(bsms: {...s.bsms, walletId: BsmsVerification(matched: matched, configHash: configHash, at: _now())}),
  );

  Future<void> setRecommendedDone(RecommendedCheckId id, bool done) => _change((s) {
    final values = {...s.recommendedDoneAt};
    done ? values[id.key] = _now() : values.remove(id.key);
    return s.copyWith(recommendedDoneAt: values);
  });

  Future<void> markAlertsRead() {
    final keys = alertItems.map((item) => item.key).toSet();
    return _change((s) => s.copyWith(readItemIds: {...s.readItemIds, ...keys}));
  }

  Future<void> dismissHomeHint() => _change((s) => s.copyWith(hintDismissed: true));

  static Future<AppUpdateStatus> _defaultCheckAppUpdate() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final response = await AppVersion().getLatestAppVersion();
      return response is AppVersionResponse
          ? compareAppVersions(package.version, response.latestVersion)
          : AppUpdateStatus.unknown;
    } catch (_) {
      return AppUpdateStatus.unknown;
    }
  }

  @visibleForTesting
  static AppUpdateStatus compareAppVersions(String current, String latest) {
    // shortcut: 정식 배포 버전만 비교, 시험판 배포를 지원하면 SemVer 비교로 확장
    final pattern = RegExp(r'^([0-9]+)\.([0-9]+)\.([0-9]+)(?:\+[0-9]+)?$');
    final currentMatch = pattern.firstMatch(current.trim());
    final latestMatch = pattern.firstMatch(latest.trim());
    if (currentMatch == null || latestMatch == null) return AppUpdateStatus.unknown;
    for (var i = 1; i <= 3; i++) {
      final currentPart = int.tryParse(currentMatch.group(i)!);
      final latestPart = int.tryParse(latestMatch.group(i)!);
      if (currentPart == null || latestPart == null) return AppUpdateStatus.unknown;
      final comparison = latestPart.compareTo(currentPart);
      if (comparison > 0) return AppUpdateStatus.available;
      if (comparison < 0) return AppUpdateStatus.upToDate;
    }
    return AppUpdateStatus.upToDate;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _certProbe?.dispose();
    _wallets?.walletLoadStateNotifier.removeListener(_schedule);
    _wallets?.walletItemListNotifier.removeListener(_schedule);
    _wallets?.removeListener(_schedule);
    _auth?.removeListener(_schedule);
    _connectivity?.removeListener(_schedule);
    _node?.removeListener(_onNodeChanged);
    _node?.currentBlockNotifier.removeListener(_schedule);
    unawaited(_syncSubscription?.cancel());
    unawaited(_walletSubscription?.cancel());
    super.dispose();
  }
}
