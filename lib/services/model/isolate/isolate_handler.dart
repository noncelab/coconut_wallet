import 'dart:isolate';

import 'package:coconut_wallet/model/node/address_balance_update_dto.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';

class IsolateHandler {
  /// 여러 스크립트의 잔액을 배치로 처리하는 내부 함수
  Future<void> handleGetBalanceBatch(
    ElectrumService electrumService,
    List<dynamic> params,
    SendPort replyPort,
  ) async {
    final addressType = params[0];
    final scriptStatuses = params[1] as List<ScriptStatus>;

    List<AddressBalanceUpdateDto> balanceUpdateDtoList = [];
    for (var script in scriptStatuses) {
      try {
        final balance =
            await electrumService.getBalance(addressType, script.address);

        final dto = AddressBalanceUpdateDto(
          scriptStatus: script,
          confirmed: balance.confirmed,
          unconfirmed: balance.unconfirmed,
        );

        balanceUpdateDtoList.add(dto);
      } catch (e) {
        Logger.error('Error fetching balance for script ${script.address}: $e');
        continue;
      }
    }
    replyPort.send(balanceUpdateDtoList);
  }
}
