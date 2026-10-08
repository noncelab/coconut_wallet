import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:flutter/widgets.dart';

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
}
