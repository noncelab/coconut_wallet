import 'package:coconut_wallet/ccos/ccos_home_entry.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// 오픈 스토어가 기능을 보여 줄 때 묻는 상태. 기능마다 [CcosFeatureStatusRegistry]에 알려 준다
class CcosFeatureStatus {
  const CcosFeatureStatus({this.inUse = false, this.removeBlockedReason, this.beforeRemove});

  final bool inUse;

  /// 제거할 수 없을 때 사용자에게 보여 줄 이유
  final String? removeBlockedReason;

  /// 제거하기 전에 해야 할 일. 있으면 스토어가 제거 전에 확인을 받는다
  final Future<void> Function()? beforeRemove;

  bool get canRemove => removeBlockedReason == null;
}

typedef CcosFeatureStatusReporter = CcosFeatureStatus Function({required bool isActivated});

class CcosFeatureStatusRegistry extends ChangeNotifier {
  final Map<String, CcosFeatureStatusReporter> _reporters = {};
  final List<Listenable> _sources = [];

  /// 기능을 추가·제거할 때 홈이 실제로 붙이고 뗀 바로가기
  final CcosHomeEntryLog homeEntries = CcosHomeEntryLog();

  void register(String featureId, CcosFeatureStatusReporter reporter, {Listenable? changes}) {
    _reporters[featureId] = reporter;
    if (changes != null) {
      changes.addListener(notifyListeners);
      _sources.add(changes);
    }
  }

  final List<Future<void> Function()> _entered = [];
  final List<Future<void> Function()> _reset = [];

  /// 앱 진입 인증을 지난 뒤와 앱 초기화(비밀번호 분실) 때 기능이 할 일
  void onAppLifecycle({Future<void> Function()? entered, Future<void> Function()? reset}) {
    if (entered != null) _entered.add(entered);
    if (reset != null) _reset.add(reset);
  }

  Future<void> appEntered() => _runAll(_entered);

  Future<void> appReset() => _runAll(_reset);

  Future<void> _runAll(List<Future<void> Function()> hooks) async {
    for (final hook in hooks) {
      try {
        await hook();
      } catch (error) {
        Logger.error('CcosFeatureStatusRegistry: app lifecycle hook failed: $error');
      }
    }
  }

  CcosFeatureStatus statusOf(String featureId, {required bool isActivated}) =>
      _reporters[featureId]?.call(isActivated: isActivated) ?? const CcosFeatureStatus();

  @override
  void dispose() {
    for (final source in _sources) {
      source.removeListener(notifyListeners);
    }
    super.dispose();
  }
}
