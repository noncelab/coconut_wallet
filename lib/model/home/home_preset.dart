import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';

/// 홈 구성을 한 번에 바꾸는 시작점
class HomePreset {
  final String id;
  final String Function() name;
  final String Function() description;

  /// 홈에 놓을 위젯·바로가기 정의 id
  /// 이 순서대로 그리드를 채운다
  final List<String> definitionIds;

  /// 크기를 고를 수 있는 위젯의 크기. 없으면 정의의 첫 크기
  final Map<String, HomeSpan> spans;

  const HomePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.definitionIds,
    this.spans = const {},
  });
}

/// Edit Home에서 프리셋을 적용하고 닫힐 때 넘기는 값
/// [previous]는 되돌릴 때 쓰는 적용 전 구성이다.
class HomePresetApplied {
  final HomePreset preset;
  final HomeConfiguration previous;

  const HomePresetApplied({required this.preset, required this.previous});
}
