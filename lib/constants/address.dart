/// 주소 저장 최대 간격 (usedIndex와 generatedIndex의 차이가 200 이상이면 저장하지 않습니다.)
const int kMaxAddressLimitGap = 200;

/// 실시간 구독(watch) 대상이 되는 gap limit. usedIndex 기준 이 범위 내의 미사용 주소만 구독한다.
const int kSubscriptionGapLimit = 20;

/// 초기 조회 개수
const int kInitialAddressCount = 20;

/// 한 번에 조회할 개수
const int kAddressLoadCount = 20;
