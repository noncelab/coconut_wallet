// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_error_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DefaultErrorResponse _$DefaultErrorResponseFromJson(
        Map<String, dynamic> json) =>
    DefaultErrorResponse(
      error: json['error'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );

Map<String, dynamic> _$DefaultErrorResponseToJson(
        DefaultErrorResponse instance) =>
    <String, dynamic>{
      'error': instance.error,
      'message': instance.message,
    };
