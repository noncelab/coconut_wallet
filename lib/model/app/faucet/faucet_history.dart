import 'package:equatable/equatable.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';

class FaucetHistory extends Equatable {
  final int id;
  final int dateTime;
  final bool isToday;
  final int count;

  FaucetHistory({
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

  static FaucetHistory fromJson(Map<String, dynamic> json) => FaucetHistory(
        id: json['id'],
        dateTime: json['dateTime'],
        count: json['count'],
      );

  FaucetHistory copyWith({
    int? dateTime,
    int? count,
  }) {
    int newDateTime = dateTime ?? this.dateTime;
    return FaucetHistory(
      id: id,
      dateTime: newDateTime,
      count: count ?? this.count,
    );
  }
}
