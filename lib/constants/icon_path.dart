import 'package:coconut_lib/coconut_lib.dart';

class IconPath {
  static const String _svgAppIconsBase = 'assets/svg/app-icons';
  static const String _imageBase = 'assets/images';

  static bool get isTestnet => NetworkType.currentNetworkType.isTestnet;
  static bool get isMainnet => !isTestnet;
  static String get _networkSuffix => isTestnet ? 'regtest' : 'mainnet';

  static String get coconut => '$_svgAppIconsBase/coconut-$_networkSuffix.svg';
  static String get coconutVault => '$_svgAppIconsBase/coconut-vault-$_networkSuffix.svg';
  static String get qrEmbedLogo => '$_imageBase/splash_logo_$_networkSuffix.png';
}

String get kCoconutVaultIconPath => IconPath.coconutVault;
const kKeystoneIconPath = 'assets/svg/wallet-type/keystone.svg';
const kSeedSignerIconPath = 'assets/svg/wallet-type/seed-signer.svg';
const kJadeIconPath = 'assets/svg/wallet-type/jade.svg';
const kZpubIconPath = 'assets/svg/wallet-type/zpub.svg';
const kColdCardIconPath = 'assets/svg/wallet-type/cold-card.svg';
const kKruxIconPath = 'assets/svg/wallet-type/krux.svg';
const kPassportIconPath = 'assets/svg/wallet-type/passport.svg';
const kBitBox02IconPath = 'assets/svg/wallet-type/bitbox02.svg';
