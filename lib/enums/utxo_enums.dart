import 'network_enums.dart';

extension UtxoOrderEnumExtension on UtxoOrderEnum {
  String get text {
    switch (this) {
      case UtxoOrderEnum.byAmountDesc:
        return "큰 금액순";
      case UtxoOrderEnum.byAmountAsc:
        return "작은 금액순";
      case UtxoOrderEnum.byTimestampDesc:
        return "최신순";
      case UtxoOrderEnum.byTimestampAsc:
        return "오래된 순";
    }
  }
}
