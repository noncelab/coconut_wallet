import 'package:equatable/equatable.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';

class FaucetRecord extends Equatable {
  final int id;
  final int dateTime;
  final bool isToday;
  final int count;

  FaucetRecord({
    required this.id,
    required this.dateTime,
    required this.count,
  }) : isToday = DateTimeUtil.isToday(dateTime);

  @override
  List<Object?> get props => [id, dateTime, isToday, count];

  @override
  bool? get stringify => true;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime,
        'count': count,
      };

  static FaucetRecord fromJson(Map<String, dynamic> json) => FaucetRecord(
        id: json['id'],
        dateTime: json['dateTime'],
        count: json['count'],
      );

  FaucetRecord copyWith({
    int? dateTime,
    int? count,
  }) {
    int newDateTime = dateTime ?? this.dateTime;
    return FaucetRecord(
      id: id,
      dateTime: newDateTime,
      count: count ?? this.count,
    );
  }
}
