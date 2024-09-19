import 'package:json_annotation/json_annotation.dart';

part 'faucet_request.g.dart'; // 생성될 파일 이름 $ dart run build_runner build

@JsonSerializable()
class FaucetRequest {
  final String address;
  final double amount;

  FaucetRequest({
    this.address = '',
    this.amount = 0,
  });

  factory FaucetRequest.fromJson(Map<String, dynamic> json) =>
      _$FaucetRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FaucetRequestToJson(this);
}
