import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/home_safety_banner.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_status_widget_view.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// 위급이면 사건 상세(배너와 같은 곳), 아니면 Wallet Health
void _open(BuildContext context, HomeItem _) {
  final critical = safetyCriticalAlertOf(context.read<SafetyProvider?>()?.report, (_) => '');
  critical == null ? WalletHealthScreen.open(context) : critical.open(context);
}

/// Safety Status 위젯 2×2·4×2. 크기마다 다른 위젯(id)이다.
List<HomeItemDefinition> safetyHomeWidgets() => [
  for (final (id, span) in [
    (HomeItemIds.safetyStatusSmall, HomeSpan.small),
    (HomeItemIds.safetyStatusWide, HomeSpan.wide),
  ])
    BuiltinHomeWidget(
      id: id,
      span: span,
      category: HomeItemCategory.safety,
      name: () => t.wallet_health.widget.name,
      onTap: _open,
      builder: (context, viewModel, item) => SafetyStatusWidgetView(span: span),
    ),
];
