import 'package:coconut_lib/coconut_lib.dart';

abstract final class AppIconPath {
  static const String _brandAppBase = 'assets/svg/brand/app';

  static bool get isTestnet => NetworkType.currentNetworkType.isTestnet;
  static bool get isMainnet => !isTestnet;
  static String get _networkSuffix => isTestnet ? 'regtest' : 'mainnet';

  static String get coconut => '$_brandAppBase/coconut-$_networkSuffix.svg';
  static String get coconutVault => '$_brandAppBase/coconut-vault-$_networkSuffix.svg';
}

abstract final class BrandIconPath {
  static const String arrowRightLg = 'assets/svg/brand/motifs/arrow-right-lg.svg';
  static const String coconutPlanet = 'assets/svg/brand/motifs/coconut-planet.svg';
  static const String coconutCore = 'assets/svg/brand/motifs/coconut-core.svg';
  static const String coconutOrbit = 'assets/svg/brand/motifs/coconut-orbit.svg';
}

abstract final class CommonActionIconPath {
  static const String addCircle = 'assets/svg/common/actions/add-circle.svg';
  static const String arrowReload = 'assets/svg/common/actions/arrow-reload.svg';
  static const String check = 'assets/svg/common/actions/check.svg';
  static const String close = 'assets/svg/common/actions/close.svg';
  static const String closeBold = 'assets/svg/common/actions/close-bold.svg';
  static const String copy = 'assets/svg/common/actions/copy.svg';
  static const String delete = 'assets/svg/common/actions/delete.svg';
  static const String download = 'assets/svg/common/actions/download.svg';
  static const String editOutlined = 'assets/svg/common/actions/edit-outlined.svg';
  static const String eraser = 'assets/svg/common/actions/eraser.svg';
  static const String export = 'assets/svg/common/actions/export.svg';
  static const String movableButton = 'assets/svg/common/actions/movable-button.svg';
  static const String openScanner = 'assets/svg/common/actions/open-scanner.svg';
  static const String paste = 'assets/svg/common/actions/paste.svg';
  static const String plus = 'assets/svg/common/actions/plus.svg';
  static const String removeMinus = 'assets/svg/common/actions/remove-minus.svg';
  static const String scan = 'assets/svg/common/actions/scan.svg';
  static const String trash = 'assets/svg/common/actions/trash.svg';
}

abstract final class CommonCommunicationIconPath {
  static const String bell = 'assets/svg/common/communication/bell.svg';
  static const String clip = 'assets/svg/common/communication/clip.svg';
  static const String githubLogo = 'assets/svg/common/communication/github-logo.svg';
  static const String githubLogoWhite = 'assets/svg/common/communication/github-logo-white.svg';
  static const String user = 'assets/svg/common/communication/user.svg';
  static const String usersGroup = 'assets/svg/common/communication/users-group.svg';
}

abstract final class CommonDividerIconPath {
  static const String rowDivider = 'assets/svg/common/dividers/row-divider.svg';
}

abstract final class CommonFormIconPath {
  static const String circle = 'assets/svg/common/form/circle.svg';
  static const String circleCheck = 'assets/svg/common/form/circle-check.svg';
  static const String circleCheckFilled = 'assets/svg/common/form/circle-check-filled.svg';
  static const String circleCheckOutline = 'assets/svg/common/form/circle-check-outline.svg';
  static const String circleMinus = 'assets/svg/common/form/circle-minus.svg';
  static const String circlePick = 'assets/svg/common/form/circle-pick.svg';
  static const String textFieldClear = 'assets/svg/common/form/text-field-clear.svg';
}

abstract final class CommonMenuIconPath {
  static const String hamburger = 'assets/svg/common/menu/hamburger.svg';
  static const String kebab = 'assets/svg/common/menu/kebab.svg';
}

abstract final class CommonNavigationIconPath {
  static const String arrowBack = 'assets/svg/common/navigation/arrow-back.svg';
  static const String arrowCircleDown = 'assets/svg/common/navigation/arrow-circle-down.svg';
  static const String arrowDown = 'assets/svg/common/navigation/arrow-down.svg';
  static const String arrowRight = 'assets/svg/common/navigation/arrow-right.svg';
  static const String arrowRightMd = 'assets/svg/common/navigation/arrow-right-md.svg';
  static const String arrowTopDown = 'assets/svg/common/navigation/arrow-top-down.svg';
  static const String back = 'assets/svg/common/navigation/back.svg';
  static const String caretDown = 'assets/svg/common/navigation/caret-down.svg';
  static const String circleArrowRight = 'assets/svg/common/navigation/circle-arrow-right.svg';
}

abstract final class CommonSecurityIconPath {
  static const String faceId = 'assets/svg/common/security/face-id.svg';
  static const String fingerprint = 'assets/svg/common/security/fingerprint.svg';
  static const String lock = 'assets/svg/common/security/lock_simple.svg';
  static const String unlock = 'assets/svg/common/security/unlock_simple.svg';
}

abstract final class CommonStateIconPath {
  static const String circleHelp = 'assets/svg/common/state/circle-help.svg';
  static const String circleInfo = 'assets/svg/common/state/circle-info.svg';
  static const String circleWarning = 'assets/svg/common/state/circle-warning.svg';
  static const String completionCheck = 'assets/svg/common/state/completion-check.svg';
  static const String questionMark = 'assets/svg/common/state/question-mark.svg';
  static const String searchNotFound = 'assets/svg/common/state/search-not-found.svg';
  static const String shieldWarning = 'assets/svg/common/state/shield-warning.svg';
  static const String starFilled = 'assets/svg/common/state/star-filled.svg';
  static const String starOutlined = 'assets/svg/common/state/star-outlined.svg';
  static const String starOutlinedBold = 'assets/svg/common/state/star-outlined-bold.svg';
  static const String starSmall = 'assets/svg/common/state/star-small.svg';
  static const String statusComplete = 'assets/svg/common/state/status-complete.svg';
  static const String statusFailure = 'assets/svg/common/state/status-failure.svg';
  static const String statusIdle = 'assets/svg/common/state/status-idle.svg';
  static const String statusImpossible = 'assets/svg/common/state/status-impossible.svg';
  static const String statusLoading = 'assets/svg/common/state/status-loading.svg';
  static const String stopSign = 'assets/svg/common/state/stop-sign.svg';
  static const String triangleWarning = 'assets/svg/common/state/triangle-warning.svg';
}

abstract final class CommonVisibilityIconPath {
  static const String eye = 'assets/svg/common/visibility/eye.svg';
  static const String eyeCrossed = 'assets/svg/common/visibility/eye-crossed.svg';
}

abstract final class FeatureConnectivityIconPath {
  static const String cloudDisconnected = 'assets/svg/features/connectivity/cloud-disconnected.svg';
  static const String offlineMode = 'assets/svg/features/connectivity/offline-mode.svg';
  static const String onlineMode = 'assets/svg/features/connectivity/online-mode.svg';
}

abstract final class FeatureSettingsIconPath {
  static const String analysis = 'assets/svg/features/settings/analysis.svg';
  static const String broom = 'assets/svg/features/settings/broom.svg';
  static const String handShake = 'assets/svg/features/settings/hand-shake.svg';
  static const String puzzlePiece = 'assets/svg/features/settings/puzzle-piece.svg';
  static const String settings = 'assets/svg/features/settings/settings.svg';
  static const String widget = 'assets/svg/features/settings/widget.svg';
}

abstract final class FeatureTagIconPath {
  static const String tag = 'assets/svg/features/tags/tag.svg';
}

abstract final class FeatureTaprootIconPath {
  static const String child = 'assets/svg/features/taproot/child.svg';
  static const String parent = 'assets/svg/features/taproot/parent.svg';
}

abstract final class FeatureTransactionIconPath {
  static const String feeRateHigh = 'assets/svg/features/transaction/fee-rate/high.svg';
  static const String feeRateLow = 'assets/svg/features/transaction/fee-rate/low.svg';
  static const String feeRateMedium = 'assets/svg/features/transaction/fee-rate/medium.svg';
  static const String receipt = 'assets/svg/features/transaction/receipt.svg';
  static const String receive = 'assets/svg/features/transaction/receive.svg';
  static const String receivePlane = 'assets/svg/features/transaction/receive-plane.svg';
  static const String send = 'assets/svg/features/transaction/send.svg';
  static const String sendPlane = 'assets/svg/features/transaction/send-plane.svg';
  static const String transaction = 'assets/svg/features/transaction/transaction.svg';
  static const String txReceived = 'assets/svg/features/transaction/tx-received.svg';
  static const String txReceiving = 'assets/svg/features/transaction/tx-receiving.svg';
  static const String txSelf = 'assets/svg/features/transaction/tx-self.svg';
  static const String txSelfSending = 'assets/svg/features/transaction/tx-self-sending.svg';
  static const String txSending = 'assets/svg/features/transaction/tx-sending.svg';
  static const String txSent = 'assets/svg/features/transaction/tx-sent.svg';
}

abstract final class FeatureUtxoIconPath {
  static const String dust = 'assets/svg/features/utxo/dust.svg';
  static const String faucet = 'assets/svg/features/utxo/faucet.svg';
  static const String mergeUtxos = 'assets/svg/features/utxo/merge-utxos.svg';
  static const String splitUtxo = 'assets/svg/features/utxo/split-utxo.svg';
}

abstract final class FeatureWalletIconPath {
  static const String bitcoin = 'assets/svg/features/wallet/bitcoin.svg';
  static const String coins = 'assets/svg/features/wallet/coins.svg';
  static const String hotWalletFire = 'assets/svg/features/wallet/hot-wallet-fire.svg';
  static const String hotWalletFireThin = 'assets/svg/features/wallet/hot-wallet-fire-thin.svg';
  static const String pie = 'assets/svg/features/wallet/pie.svg';
  static const String piggyBank = 'assets/svg/features/wallet/piggy-bank.svg';
  static const String wallet = 'assets/svg/features/wallet/wallet.svg';
  static const String walletAddDefault = 'assets/svg/features/wallet/wallet-add-default.svg';
  static const String walletAddHot = 'assets/svg/features/wallet/wallet-add-hot.svg';
  static const String walletEyes = 'assets/svg/features/wallet/wallet-eyes.svg';
  static const String walletImportHot = 'assets/svg/features/wallet/wallet-import-hot.svg';
  static const String walletInfo = 'assets/svg/features/wallet/wallet-info.svg';
  static const String walletOutlined = 'assets/svg/features/wallet/wallet-outlined.svg';
  static const String watchOnlyEyes = 'assets/svg/features/wallet/watch-only-eyes.svg';
}

abstract final class ThirdPartyWalletTypeIconPath {
  static String get coconutVault => AppIconPath.coconutVault;

  static const String bitBox02 = 'assets/svg/wallet-catalog/hardware-wallets/bitbox02.svg';
  static const String coldCard = 'assets/svg/wallet-catalog/hardware-wallets/cold-card.svg';
  static const String jade = 'assets/svg/wallet-catalog/hardware-wallets/jade.svg';
  static const String keystone = 'assets/svg/wallet-catalog/hardware-wallets/keystone.svg';
  static const String krux = 'assets/svg/wallet-catalog/hardware-wallets/krux.svg';
  static const String passport = 'assets/svg/wallet-catalog/hardware-wallets/passport.svg';
  static const String seedSigner = 'assets/svg/wallet-catalog/hardware-wallets/seed-signer.svg';
  static const String trezor = 'assets/svg/wallet-catalog/hardware-wallets/trezor.svg';
  static const String zpub = 'assets/svg/wallet-catalog/import-formats/zpub.svg';
}
