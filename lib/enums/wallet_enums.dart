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
  String get displayName {
    switch (this) {
      case WalletImportSource.coconutVault:
        return t.wallet_add_scanner_screen.vault;
      case WalletImportSource.keystone:
        return t.wallet_add_scanner_screen.keystone;
      case WalletImportSource.jade:
        return t.wallet_add_scanner_screen.jade;
      case WalletImportSource.seedSigner:
        return t.wallet_add_scanner_screen.seed_signer;
      case WalletImportSource.coldCard:
        return t.wallet_add_scanner_screen.cold_card;
      case WalletImportSource.krux:
        return t.wallet_add_scanner_screen.krux;
      case WalletImportSource.extendedPublicKey:
        return t.wallet_add_scanner_screen.self;
    }
  }

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
