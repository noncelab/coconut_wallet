import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:flutter/widgets.dart';

/// 홈 위젯 타일은 크기가 고정이라 글자 확대를 이 배율에서 멈춘다(라벨 관리 등 앱의 다른 고정 크기 영역과 같은 1.2).
const kHomeTileMaxTextScale = 1.2;

/// Edit Home 위젯 탭에서 이 순서로 묶어 보여 준다. safety 제외(epic3)
enum HomeItemCategory { balance, wallets, activities, hodl, safety, shortcut }

abstract class HomeItemDefinition {
  final String id;
  final HomeItemKind kind;
  final List<HomeSpan> supportedSpans;
  final HomeItemCategory category;
  final bool needsConfigureBeforeAdd;
  final bool requiresWalletContext;
  final bool allowsMultipleInstances;
  final HomeWidgetSettingsSpec settings;

  const HomeItemDefinition({
    required this.id,
    required this.kind,
    required this.supportedSpans,
    required this.category,
    this.needsConfigureBeforeAdd = false,
    this.requiresWalletContext = false,
    this.allowsMultipleInstances = false,
    this.settings = const HomeWidgetSettingsSpec(),
  });

  String displayName() => id;

  Widget build(BuildContext context, HomeItem item);

  /// 홈 그리드·위젯 카탈로그·설정 미리보기가 그리는 타일. 글자 확대는 [kHomeTileMaxTextScale]에서 멈춘다.
  Widget buildTile(HomeItem item) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: kHomeTileMaxTextScale,
    child: Builder(builder: (context) => build(context, item)),
  );
}
