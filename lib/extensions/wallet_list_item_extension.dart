import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/utils/bitcoin/transaction_util.dart';

extension WalletListItemBaseExtension on WalletListItemBase {
  /// 이 지갑으로 서명할 때 input 1개가 추가될 때 증가하는 vSize(vbytes)
  int get inputVSize {
    switch (walletType) {
      case WalletType.singleSignature:
        return 68;
      case WalletType.multiSignature:
        final config = multisigConfig!;
        return p2wshMultisigInputVSize(m: config.requiredSignature, n: config.totalSigner);
      case WalletType.taproot:
        final taprootWallet = this as TaprootWalletListItem;
        final spendType = taprootWallet.defaultSpendType;

        /// 다른 타입의 Policy가 추가되는 경우 defaultPolicy 사용하는 부분을 개선해야 할 가능성이 있음
        final policy = taprootWallet.defaultPolicy;
        return p2trInputVSize(
          spendType: spendType,
          scriptPathConfig:
              spendType == TaprootSpendType.scriptPath && policy != null
                  ? taprootWallet.scriptPathConfigFor(policy)
                  : null,
        );
    }
  }
}
