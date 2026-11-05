import 'package:coconut_wallet/constants/isolate_constants.dart';

const Duration kHttpReceiveTimeout = Duration(milliseconds: 5000);

const Duration kHttpConnectionTimeout = Duration(milliseconds: 3000);

const Duration kElectrumConnectionTimeout = Duration(milliseconds: 3000);

const int kSocketMaxConnectionAttempts = 30;

const Duration kElectrumResponseTimeout = Duration(seconds: 60);

/// 일반 노드에서 브로드캐스트 응답을 기다리는 시간. 넘기면 서버에 거래가 들어갔는지 확인한다.
const Duration kBroadcastReplyTimeout = Duration(seconds: 8);

/// 응답을 못 받은 브로드캐스트가 서버에 들어갔는지 확인하는 시간.
const Duration kBroadcastCheckTimeout = Duration(seconds: 4);
const Duration kBroadcastCheckTimeoutForOnion = Duration(seconds: 12);

/// 결과를 모르는 전송을 같은 거래로 다시 보내는 횟수. 매번 기다림을 두 배로 늘린다.
/// 최대 대기는 일반 노드 약 2분, Tor 약 11분이다(응답·확인 대기 + 다시 보내기 전 연결 확인·재연결).
const int kBroadcastRetries = 2;

/// 다시 보내기 전 재연결을 기다리는 상한. 지갑 구독까지 기다리지 않는다(재연결은 뒤에서 계속된다).
const Duration kBroadcastReconnectWait = Duration(seconds: 10);

/// 송금 하나의 결과를 기다리는 전체 상한. 다음 다시 보내기가 이를 넘길 수 있으면 보내지 않는다.
const Duration kBroadcastTotalLimit = Duration(seconds: 120);
const Duration kBroadcastTotalLimitForOnion = Duration(seconds: 720);

/// 송금 한 번(응답 대기 + 서버 확인)의 대기. 결과를 모르는 송금을 같은 거래로 다시 보낼 때마다 두 배로 늘린다.
/// [command]는 메인 쪽이 isolate 결과를 기다리는 시간, [worstCase]는 다시 보내기 전 연결 확인·재연결·isolate 준비·준비 확인과
/// 명령 전 소켓 확인까지 더한 한 번의 다시 보내기 최대치다.
({Duration reply, Duration check, Duration command, Duration worstCase}) broadcastLimits({
  required bool onion,
  required int attempt,
}) {
  final scale = 1 << attempt;
  final reply = (onion ? kElectrumResponseTimeout : kBroadcastReplyTimeout) * scale;
  final check = (onion ? kBroadcastCheckTimeoutForOnion : kBroadcastCheckTimeout) * scale;
  final command = reply + check + const Duration(seconds: 3);
  final connectivityCheck = onion ? kIsolateSimpleResponseTimeoutForOnion : kIsolateSimpleResponseTimeout;
  final isolateStart = onion ? kIsolateInitTimeoutForOnion : kIsolateInitTimeout;
  return (
    reply: reply,
    check: check,
    command: command,
    worstCase: command + connectivityCheck * 2 + kBroadcastReconnectWait + isolateStart + const Duration(seconds: 1),
  );
}

const Duration kElectrumPingInterval = Duration(seconds: 20);

const Duration kNodeRefreshWaitTimeout = Duration(seconds: 30);

/// 결과를 모르는 송금을 [attempt]번째로 다시 보내도 송금 시작부터 [elapsed]가 지난 지금 전체 상한 안에 끝나는지.
bool canResendWithinLimit({required Duration elapsed, required bool onion, required int attempt}) =>
    elapsed + broadcastLimits(onion: onion, attempt: attempt).worstCase <=
    (onion ? kBroadcastTotalLimitForOnion : kBroadcastTotalLimit);
