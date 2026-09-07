class LabelManagementRouteArgs {
  final int? walletId;
  final bool showImportMemosFromOtherWalletsOption;

  const LabelManagementRouteArgs({this.walletId, this.showImportMemosFromOtherWalletsOption = true});
}

class LabelImportRouteArgs {
  final int? walletId;
  final bool showImportMemosFromOtherWalletsOption;

  const LabelImportRouteArgs({this.walletId, this.showImportMemosFromOtherWalletsOption = true});
}

class LabelExportRouteArgs {
  final int? walletId;

  const LabelExportRouteArgs({this.walletId});
}
