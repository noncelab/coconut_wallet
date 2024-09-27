import 'package:json_annotation/json_annotation.dart';

part 'default_error_response.g.dart'; // 생성될 파일 이름 $ dart run build_runner build

@JsonSerializable()
class DefaultErrorResponse {
  final String error;
  final String message;

  DefaultErrorResponse({
    this.error = '',
    this.message = '',
  });

  factory DefaultErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$DefaultErrorResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DefaultErrorResponseToJson(this);
}
