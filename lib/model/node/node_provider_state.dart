import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/utils/logger.dart';

/// NodeProvider 상태 정보를 담는 클래스
class NodeProviderState {
  final NodeSyncState nodeSyncState;
  final Map<int, WalletUpdateInfo> registeredWallets;

  const NodeProviderState({
    required this.nodeSyncState,
    required this.registeredWallets,
  });

  // 초기 상태를 생성하는 팩토리 생성자 추가
  factory NodeProviderState.initial() {
    return const NodeProviderState(
      nodeSyncState: NodeSyncState.completed,
      registeredWallets: {},
    );
  }

  NodeProviderState copyWith({
    NodeSyncState? newConnectionState,
    Map<int, WalletUpdateInfo>? newUpdatedWallets,
  }) {
    return NodeProviderState(
      nodeSyncState: newConnectionState ?? nodeSyncState,
      registeredWallets: newUpdatedWallets ?? registeredWallets,
    );
  }

  void printStatus() {
    // UpdateStatus를 심볼로 변환하는 함수
    String statusToSymbol(WalletSyncState status) {
      switch (status) {
        case WalletSyncState.waiting:
          return '⏳'; // 대기 중
        case WalletSyncState.syncing:
          return '🔄'; // 동기화 중
        case WalletSyncState.completed:
          return '✅'; // 완료됨
      }
    }

    // ConnectionState를 심볼로 변환하는 함수
    String connectionStateToSymbol(NodeSyncState state) {
      switch (state) {
        case NodeSyncState.init:
        case NodeSyncState.syncing:
          return '🔄 동기화 중';
        case NodeSyncState.completed:
          return '🟢 대기 중ㅤ';
        case NodeSyncState.failed:
          return '🔴 실패';
      }
    }

    final connectionStateSymbol = connectionStateToSymbol(nodeSyncState);

    if (registeredWallets.isEmpty) {
      final buffer = StringBuffer();
      buffer.writeln('--> 등록된 지갑이 없습니다.');
      buffer.writeln('--> nodeSyncState: $nodeSyncState');
      Logger.log(buffer.toString());
      return;
    }

    // 등록된 지갑의 키 목록 얻기
    final walletKeys = registeredWallets.keys.toList();

    // 테이블 헤더 출력 (connectionState 포함)
    final headerBuffer = StringBuffer();
    headerBuffer.writeln('\n');
    headerBuffer.writeln('┌─────────────────────────────────────────────────┐');
    headerBuffer
        .writeln('│ 연결 상태: $connectionStateSymbol${' ' * (33 - connectionStateSymbol.length)}│');
    headerBuffer.writeln('├─────────┬─────────┬─────────┬─────────┬─────────┤');
    headerBuffer.writeln('│ 지갑 ID │  구독   │  잔액   │  거래   │  UTXO   │');
    headerBuffer.writeln('├─────────┼─────────┼─────────┼─────────┼─────────┤');
    Logger.log(headerBuffer.toString());

    // 각 지갑 상태를 개별적으로 출력 (긴 로그 방지)
    for (int i = 0; i < walletKeys.length; i++) {
      final key = walletKeys[i];
      final value = registeredWallets[key]!;

      final subscriptionSymbol = statusToSymbol(value.subscription);
      final balanceSymbol = statusToSymbol(value.balance);
      final transactionSymbol = statusToSymbol(value.transaction);
      final utxoSymbol = statusToSymbol(value.utxo);

      final rowBuffer = StringBuffer();
      rowBuffer.writeln(
          '│ ${key.toString().padRight(7)} │   $subscriptionSymbol    │   $balanceSymbol    │   $transactionSymbol    │   $utxoSymbol    │');

      // 마지막 행이 아니면 행 구분선 추가
      if (i < walletKeys.length - 1) {
        rowBuffer.writeln('├─────────┼─────────┼─────────┼─────────┼─────────┤');
      }

      Logger.log(rowBuffer.toString());
    }

    // 테이블 하단 테두리 출력
    Logger.log('└─────────┴─────────┴─────────┴─────────┴─────────┘');
  }
}
