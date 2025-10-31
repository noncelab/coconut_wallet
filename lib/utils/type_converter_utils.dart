/// 타입 변환과 관련된 유틸리티 함수들을 모아놓은 파일입니다.

/// CBOR 디코딩 결과로 얻은 Map의 키를 String 타입으로 변환합니다.
/// CBOR 디코딩 결과는 dynamic 타입의 키를 가질 수 있으므로, 이를 String으로 통일하여 사용하기 위한 함수입니다.
Map<String, dynamic> convertKeysToString(Map<dynamic, dynamic> map) {
  return map.map((key, value) {
    String newKey = key.toString();
    dynamic newValue;
    if (value is Map) {
      newValue = convertKeysToString(value);
    } else if (value is List) {
      newValue =
          value.map((item) {
            if (item is Map) {
              return convertKeysToString(item);
            } else {
              return item;
            }
          }).toList();
    } else {
      newValue = value;
    }
    return MapEntry(newKey, newValue);
  });
}
