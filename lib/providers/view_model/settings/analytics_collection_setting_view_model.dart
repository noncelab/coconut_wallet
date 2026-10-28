import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/foundation.dart';

/// 앱 사용 익명 통계 수집 설정 행의 저장 중 상태. 수집 정책과 변경 직렬화는 [AnalyticsService]가 맡는다.
class AnalyticsCollectionSettingViewModel extends ChangeNotifier {
  final AnalyticsService _analyticsService;
  bool _isSaving = false;
  bool _isDisposed = false;

  AnalyticsCollectionSettingViewModel(this._analyticsService);

  ValueListenable<bool> get isCollectionEnabled => _analyticsService.collectionEnabledListenable;
  bool get isSaving => _isSaving;

  /// 변경하지 못했으면 false를 돌려준다. 저장 중에 다시 들어온 호출은 진행 중인 변경을 건드리지 않고 무시한다.
  Future<bool> setCollectionEnabled(bool enabled) async {
    if (_isSaving) return true;
    _isSaving = true;
    notifyListeners();
    try {
      await _analyticsService.setCollectionEnabled(enabled);
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
