import 'dart:convert';

import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/migration/taproot_older_to_after_migration.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

/// 코코넛 볼트 - 지갑 내보내기 스캔용
class CoconutWalletAddQrScanDataHandler implements IQrScanDataHandler {
  WatchOnlyWallet? _result;

  @override
  bool isCompleted() {
    return _result != null;
  }

  @override
  bool joinData(String data) {
    try {
      final jsonData = jsonDecode(data) as Map<String, dynamic>;
      final wallet = WatchOnlyWallet.fromJson(jsonData);
      if (wallet.isTaproot) {
        final migration = TaprootOlderToAfterMigration.migrate(
          descriptor: wallet.descriptor,
          scriptPathSeedInfos: wallet.scriptPathSeedInfos ?? const [],
        );
        final walletForValidation =
            migration.hasChanges
                ? WatchOnlyWallet(
                  wallet.name,
                  wallet.colorIndex,
                  wallet.iconIndex,
                  migration.descriptor,
                  wallet.requiredSignatureCount,
                  wallet.signers,
                  wallet.walletImportSource.name,
                  keyPathSeedInfos: wallet.keyPathSeedInfos,
                  scriptPathSeedInfos: migration.scriptPathSeedInfos,
                  createdAtInVault: wallet.createdAtInVault,
                )
                : wallet;

        if (!walletForValidation.isSupportedTaprootConfiguration) {
          Logger.error('Unsupported Taproot configuration');
          return false;
        }
      }

      // 여기서는 migration 결과를 validation에만 사용합니다.
      // 원본 wallet을 result로 전달해야 WalletProvider가 실제 저장 전에
      // migration을 다시 수행하고, 변경된 지갑 ID를 영속 저장할 수 있습니다.
      _result = wallet;
      return true;
    } catch (e, stackTrace) {
      Logger.error(e.toString());
      Logger.error(stackTrace);
      return false;
    }
  }

  @override
  void reset() {
    _result = null;
  }

  @override
  dynamic get result => _result;

  @override
  double get progress => isCompleted() ? 1.0 : 0.0;

  @override
  bool validateFormat(String data) {
    try {
      final jsonData = jsonDecode(data) as Map<String, dynamic>;
      WatchOnlyWallet.fromJson(jsonData);
      return true;
    } catch (_) {
      return false;
    }
  }
}
