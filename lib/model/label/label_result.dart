import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:share_plus/share_plus.dart';

class LabelImportResult {
  final WalletItemBase? wallet;
  int txMemoCount = 0;
  int utxoTagCount = 0;
  int utxoLockCount = 0;

  LabelImportResult({this.wallet});
}

class LabelExportResult {
  final XFile? xFile;
  final WalletItemBase? wallet;
  final int txMemoCount;
  final int utxoTagCount;
  final int utxoLockCount;

  LabelExportResult({this.xFile, this.wallet, this.txMemoCount = 0, this.utxoTagCount = 0, this.utxoLockCount = 0});
}
