import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

enum WalletType {
  singleSignature,
  multiSignature;

  AddressType get addressType {
    switch (this) {
      case WalletType.singleSignature:
        return AddressType.p2wpkh;
      case WalletType.multiSignature:
        return AddressType.p2wsh;
    }
  }
}

enum WalletSyncResult {
  newWalletAdded,
  existingWalletUpdated, // coconut vault 지갑 ui 업데이트 됨
  existingWalletNoUpdate,
  existingName, // fail sync
  existingWalletUpdateImpossible, // 이미 추가된 descriptor를 서드파티 방법으로 또 추가한 경우
}

enum WalletLoadState { never, loadingFromDB, loadCompleted }

enum WalletImportSource { coconutVault, keystone, jade, seedSigner, coldCard, krux, extendedPublicKey }

extension WalletImportSourceExtension on WalletImportSource {
  static final Map<WalletImportSource, String> _names = {
    WalletImportSource.coconutVault: t.wallet_add_scanner_screen.vault,
    WalletImportSource.keystone: t.wallet_add_scanner_screen.keystone,
    WalletImportSource.jade: t.wallet_add_scanner_screen.jade,
    WalletImportSource.seedSigner: t.wallet_add_scanner_screen.seed_signer,
    WalletImportSource.coldCard: t.wallet_add_scanner_screen.cold_card,
    WalletImportSource.krux: t.wallet_add_scanner_screen.krux,
    WalletImportSource.extendedPublicKey: t.wallet_add_scanner_screen.self,
  };

  String get displayName => _names[this]!;

  static WalletImportSource fromStringDefaultCoconut(String name) {
    return WalletImportSource.values.firstWhere(
      (type) => type.name == name,
      orElse: () => WalletImportSource.coconutVault,
    );
  }

  static WalletImportSource? fromString(String name) {
    try {
      return WalletImportSource.values.firstWhere((type) => type.name == name);
    } catch (_) {
      return null;
    }
  }

  String get externalWalletIconPath {
    switch (this) {
      case WalletImportSource.coconutVault:
        return kCoconutVaultIconPath;
      case WalletImportSource.keystone:
        return kKeystoneIconPath;
      case WalletImportSource.jade:
        return kJadeIconPath;
      case WalletImportSource.seedSigner:
        return kSeedSignerIconPath;
      case WalletImportSource.coldCard:
        return kColdCardIconPath;
      case WalletImportSource.krux:
        return kKruxIconPath;
      case WalletImportSource.extendedPublicKey:
        return kZpubIconPath;
    }
  }
}
