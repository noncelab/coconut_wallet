import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';

extension TransactionExtension on Transaction {
  /// taproot 지갑인 경우 [taprootConfig]를 항상 전달해야 함.
  /// [estimateVirtualByte] 내부에서 transaction 생성 시 적용된 policy(_appliedPolicy)를
  /// 기반으로 keyPath/scriptPath 여부를 스스로 판단하므로,
  /// 호출 측에서 spend type을 분기할 필요 없음.
  double estimateVirtualByteForWallet(WalletListItemBase wallet) {
    if (wallet.walletType != WalletType.taproot) {
      return estimateVirtualByte(
        wallet.walletType.addressType,
        requiredSignature: wallet.multisigConfig?.requiredSignature,
        totalSigner: wallet.multisigConfig?.totalSigner,
      );
    } else {
      return estimateVirtualByte(
        wallet.walletType.addressType,
        requiredSignature: wallet.taprootConfig?.requiredSignature,
        leafCount: wallet.taprootConfig?.leafCount,
      );
    }
  }
}
