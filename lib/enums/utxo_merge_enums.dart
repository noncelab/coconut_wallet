enum UtxoMergeStep {
  entry, // UTXO 합치기 할 필요 없음 안내 문구
  selectMergeMethod, // 정리 기준(작음 금액, 태그, 중복주소)
  selectAmountRange, // 기준 금액 설정
  selectTag, // 태그 설정
  selectReceiveAddress, // 받는 주소 설정(ready)
}

enum UtxoMergeMethod { smallAmounts, sameTag, sameAddress }

enum UtxoAmountRange { below001, below0001, below00001, custom }
