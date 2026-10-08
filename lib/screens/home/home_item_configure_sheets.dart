import 'package:provider/provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:collection/collection.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/screens/home/shortcut_configure_sheet.dart';
import 'package:coconut_wallet/screens/home/widget_configure_sheet.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/widgets.dart';

/// Edit Home과 홈 길게 누르기 메뉴가 함께 쓰는 위젯·바로가기 설정 시트
class HomeItemConfigureSheets {
  /// 크기를 고르는 위젯의 미리보기. 홈 위젯 데이터가 없는 곳(테스트 등)에서는 미리보기를 빼고 연다.
  static Widget Function(HomeSpan span)? previewFor(
    BuildContext context,
    HomeItemDefinition definition, {
    HomeItem? item,
  }) {
    if (definition.settings.sizes.isEmpty) return null;
    final data = context.read<HomeWidgetsViewModel?>();
    if (data == null) return null;
    return (span) => ChangeNotifierProvider.value(
      value: data,
      child: Builder(
        builder:
            (context) => definition.build(
              context,
              HomeItem(
                id: 'preview-${definition.id}',
                definitionId: definition.id,
                kind: definition.kind,
                order: 0,
                span: span,
                configuration: item?.configuration ?? const {},
              ),
            ),
      ),
    );
  }

  static Future<ShortcutWalletContext?> openShortcut(
    BuildContext context,
    HomeViewModel viewModel,
    ShortcutDefinition definition, {
    bool isNew = true,
  }) {
    return CommonBottomSheets.showBottomSheet_100<ShortcutWalletContext>(
      context: context,
      screenName: '/shortcut-configure-sheet',
      isDismissible: true,
      backgroundColor: context.coconutColors.surfaceBottomSheet,
      child: ShortcutConfigureSheet(
        feature: definition.feature,
        wallets: viewModel.wallets,
        current: viewModel.shortcutWalletContext,
        isNew: isNew,
      ),
    );
  }

  /// 홈에 있는 항목의 설정을 바꾼다. 설정이 없는 항목은 아무것도 하지 않는다.
  static Future<void> configure(
    BuildContext context,
    HomeViewModel viewModel,
    HomeItemDefinition definition,
    HomeItem item,
  ) async {
    if (!viewModel.canConfigure(definition)) return;
    if (definition is ShortcutDefinition) {
      final walletContext = await openShortcut(context, viewModel, definition, isNew: false);
      if (walletContext != null) viewModel.updateShortcutWalletContext(walletContext);
      return;
    }
    final settings = await WidgetConfigureSheet.open(
      context,
      definition: definition,
      wallets: viewModel.wallets,
      initial: HomeWidgetSettings.fromConfiguration(item.configuration),
      initialSpan: item.span,
      previewBuilder: previewFor(context, definition, item: item),
    );
    if (settings == null) return;
    final span = settings.span;
    if (span != null && span != item.span) viewModel.resizeItem(item.id, span);
    final configuration = settings.toConfiguration();
    if (!const DeepCollectionEquality().equals(configuration, item.configuration)) {
      viewModel.updateItemConfiguration(item.id, configuration);
    }
  }
}
