/// 기존 호출은 PSBT가 있으면 서명, 없으면 지갑 추가다. 재연결은 명시적으로 요청한다.
enum HardwareWalletConnectMode { addWallet, sign, reconnect }
