import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:flutter/widgets.dart';

enum FeatureContext { none, wallet }

enum FeatureSource { builtin, ccos }

/// All Features에서 이 순서로 묶어 보여 준다. safety는 epic3 이후 보여준다.
enum FeatureCategory { wallet, transactions, utxo, tools, safety, settings }

typedef FeatureLaunch = Future<void> Function(BuildContext context, WalletItemBase? wallet);

class FeatureItem {
  final String id;
  final String Function() label;
  final String Function()? shortLabel;
  final String? iconPath;
  final double iconScale;
  final List<String> keywords;

  /// 지금 언어의 검색어. 언어를 바꾸면 바뀌므로 찾을 때마다 읽는다. [keywords]는 언어와 상관없는 말(PIN, xpub 등)
  final List<String> Function()? localizedKeywords;
  final String? parentId;
  final FeatureContext context;
  final bool Function(WalletItemBase wallet)? isWalletSupported;
  final bool Function(BuildContext context)? isAvailable;
  final bool shortcutEligible;
  final FeatureSource source;
  final FeatureCategory? category;
  final FeatureLaunch? launch;

  const FeatureItem({
    required this.id,
    required this.label,
    this.shortLabel,
    this.iconPath,
    this.iconScale = 1,
    this.keywords = const [],
    this.localizedKeywords,
    this.parentId,
    this.context = FeatureContext.none,
    this.isWalletSupported,
    this.isAvailable,
    this.shortcutEligible = false,
    this.source = FeatureSource.builtin,
    this.category,
    this.launch,
  });

  bool get isTopLevel => parentId == null;

  String shortcutLabel() => (shortLabel ?? label)();

  bool supportsWallet(WalletItemBase wallet) => isWalletSupported?.call(wallet) ?? true;
}
