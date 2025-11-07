import 'package:json_annotation/json_annotation.dart';

part 'faucet_response.g.dart'; // 생성될 파일 이름 $ dart run build_runner build

@JsonSerializable()
class FaucetResponse {
  final String address;
  final double amount;
  final String txHash;

  FaucetResponse({this.address = '', this.amount = 0, this.txHash = ''});

  factory FaucetResponse.fromJson(Map<String, dynamic> json) => _$FaucetResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FaucetResponseToJson(this);

  @override
  String toString() => 'address($address) / amount=$amount / txHash=$txHash';
}
