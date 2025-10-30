import 'package:json_annotation/json_annotation.dart';

part 'faucet_status_response.g.dart'; // 생성될 파일 이름 $ dart run build_runner build

@JsonSerializable()
class FaucetStatusResponse {
  final double totalBalance;
  final double todayBalance;
  final int todayRequestedCount;
  final double maxLimit;
  final double minLimit;

  FaucetStatusResponse({
    this.totalBalance = 0,
    this.todayBalance = 0,
    this.todayRequestedCount = 0,
    this.maxLimit = 0,
    this.minLimit = 0,
  });

  factory FaucetStatusResponse.fromJson(Map<String, dynamic> json) => _$FaucetStatusResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FaucetStatusResponseToJson(this);

  @override
  String toString() =>
      'totalBalance($totalBalance) / todayBalance=$todayBalance / todayRequestedCount=$todayRequestedCount / maxLimit=$maxLimit / minLimit=$minLimit';
}
