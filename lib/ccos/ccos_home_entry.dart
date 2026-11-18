import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:flutter/widgets.dart';

/// 오픈 스토어 기능이 켜서 제공하는 홈 바로가기
class CcosHomeShortcut {
  const CcosHomeShortcut({
    required this.id,
    required this.label,
    required this.iconPath,
    this.iconScale = 1,
    required this.launch,
    this.addToHomeOnActivate = false,
  });

  final String id;
  final String Function() label;
  final String iconPath;
  final double iconScale;
  final void Function(BuildContext context) launch;

  /// 기능을 추가할 때 홈에 바로 붙일지
  final bool addToHomeOnActivate;
}

/// 오픈 스토어 기능이 켜서 제공하는 홈 위젯
class CcosHomeWidget {
  const CcosHomeWidget({required this.definition});

  final HomeItemDefinition Function() definition;
}

/// 기능을 추가·제거할 때 홈이 실제로 붙이고 뗀 바로가기 이름. 스토어가 알림 문구를 고를 때 읽는다
class CcosHomeEntryLog {
  final Map<String, String> _added = {};
  final Map<String, String> _removed = {};

  void shortcutAdded(String featureId, String name) {
    _removed.remove(featureId);
    _added[featureId] = name;
  }

  void shortcutRemoved(String featureId, String name) {
    _added.remove(featureId);
    _removed[featureId] = name;
  }

  String? takeAdded(String featureId) => _added.remove(featureId);

  String? takeRemoved(String featureId) => _removed.remove(featureId);
}
