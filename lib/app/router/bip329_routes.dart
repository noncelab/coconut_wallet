import 'package:coconut_wallet/app/router/bip329_route_args.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_export_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_import_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_management_screen.dart';
import 'package:flutter/widgets.dart';

Map<String, WidgetBuilder> buildBip329Routes() {
  return {
    '/label-management': (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as LabelManagementRouteArgs? ?? const LabelManagementRouteArgs();
      return LabelManagementScreen(
        walletId: args.walletId,
        showImportMemosFromOtherWalletsOption: args.showImportMemosFromOtherWalletsOption,
      );
    },
    '/label-import': (context) {
      final args = ModalRoute.of(context)?.settings.arguments as LabelImportRouteArgs? ?? const LabelImportRouteArgs();
      return LabelImportScreen(
        walletId: args.walletId,
        showImportMemosFromOtherWalletsOption: args.showImportMemosFromOtherWalletsOption,
      );
    },
    '/label-export': (context) {
      final args = ModalRoute.of(context)?.settings.arguments as LabelExportRouteArgs? ?? const LabelExportRouteArgs();
      return LabelExportScreen(initialSelectedWalletId: args.walletId);
    },
  };
}
