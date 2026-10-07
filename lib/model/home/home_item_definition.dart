import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:flutter/widgets.dart';

abstract class HomeItemDefinition {
  final String id;
  final HomeItemKind kind;
  final List<HomeSpan> supportedSpans;
  final String category;
  final bool needsConfigureBeforeAdd;
  final bool requiresWalletContext;
  final bool allowsMultipleInstances;

  const HomeItemDefinition({
    required this.id,
    required this.kind,
    required this.supportedSpans,
    required this.category,
    this.needsConfigureBeforeAdd = false,
    this.requiresWalletContext = false,
    this.allowsMultipleInstances = false,
  });

  String displayName() => id;

  Widget build(BuildContext context, HomeItem item);
}
