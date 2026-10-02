import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';

/// `wallet_type`: 싱글시그 보기 전용 / 다중서명 / 탭루트 상속 지갑 / 핫월렛
enum AnalyticsWalletType {
  watchOnly,
  multisig,
  inheritance,
  hotWallet;

  static AnalyticsWalletType of(WalletItemBase wallet) {
    if (wallet.hasLocalKey) return AnalyticsWalletType.hotWallet;
    return switch (wallet.walletType) {
      WalletType.singleSignature => AnalyticsWalletType.watchOnly,
      WalletType.multiSignature => AnalyticsWalletType.multisig,
      WalletType.taproot => AnalyticsWalletType.inheritance,
    };
  }
}
