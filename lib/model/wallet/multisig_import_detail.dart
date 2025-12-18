import 'dart:core';
import 'package:json_annotation/json_annotation.dart';

part 'multisig_import_detail.g.dart';

@JsonSerializable(ignoreUnannotated: true)
class MultisigImportDetail {
  @JsonKey()
  String name;
  @JsonKey()
  int colorIndex;
  @JsonKey()
  int iconIndex;
  @JsonKey()
  Map<String, String> namesMap;
  @JsonKey()
  String coordinatorBsms;

  MultisigImportDetail({
    required this.name,
    required this.colorIndex,
    required this.iconIndex,
    required this.namesMap,
    required this.coordinatorBsms,
  });

  Map<String, dynamic> toJson() => _$MultisigImportDetailToJson(this);

  factory MultisigImportDetail.fromJson(Map<String, dynamic> json) => _$MultisigImportDetailFromJson(json);
}
