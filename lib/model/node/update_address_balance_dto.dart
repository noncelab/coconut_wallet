import 'package:coconut_wallet/model/node/script_status.dart';

class UpdateAddressBalanceDto {
  final ScriptStatus scriptStatus;
  final int confirmed;
  final int unconfirmed;

  int get total => confirmed + unconfirmed;

  UpdateAddressBalanceDto({required this.scriptStatus, required this.confirmed, required this.unconfirmed});
}
