abstract final class WalletNameUtil {
  /// 기존 지갑 이름과 겹치지 않는 가장 작은 번호의 기본 이름을 반환한다.
  /// 첫 이름이 사용 중이면 2부터 확인하며, 중간에 비어 있는 번호를 우선 재사용한다.
  static String findAvailableDefaultName({
    required Iterable<String> existingNames,
    required String firstName,
    required String Function(int number) numberedName,
  }) {
    final names = existingNames.map((name) => name.trim()).toSet();
    if (!names.contains(firstName)) return firstName;

    var number = 2;
    while (names.contains(numberedName(number))) {
      number++;
    }
    return numberedName(number);
  }
}
