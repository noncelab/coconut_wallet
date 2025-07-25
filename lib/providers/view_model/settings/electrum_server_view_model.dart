import 'dart:async';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/screens/settings/electrum_server_screen.dart';
import 'package:flutter/material.dart';

class ElectrumServerViewModel extends ChangeNotifier {
  final NodeProvider _nodeProvider;
  final PreferenceProvider _preferenceProvider;

  late ElectrumServer _initialServer;
  late ElectrumServer _currentServer;
  ElectrumServer get initialServer => _initialServer;
  ElectrumServer? get currentServer => _currentServer;

  NodeConnectionStatus _nodeConnectionStatus = NodeConnectionStatus.waiting;

  bool _isServerAddressFormatError = false; // 서버 주소 형식
  bool _isPortOutOfRangeError = false; // 1 ~ 65535 포트 범위
  bool _isDefaultServerMenuVisible = false; // 기본 서버 메뉴 visibility

  // NodeSyncState 구독 필요 없음, 연결 상태만 필요
  // StreamSubscription<NodeSyncState>? _nodeStateSubscription;

  NodeConnectionStatus get nodeConnectionStatus => _nodeConnectionStatus;

  bool get isServerAddressFormatError => _isServerAddressFormatError;
  bool get isPortOutOfRangeError => _isPortOutOfRangeError;
  bool get isDefaultServerMenuVisible => _isDefaultServerMenuVisible;

  ElectrumServerViewModel(this._nodeProvider, this._preferenceProvider) {
    // 현재 설정된 서버 정보 가져오기
    _initialServer = _preferenceProvider.getElectrumServer();

    // 초기 서버 정보 설정
    setCurrentServer(_initialServer);

    // NodeProvider 상태 변경 감지 시작
    // _startListeningToNodeState();

    // 초기 상태 확인
    _checkInitialNodeProviderStatus();
  }

  // /// NodeProvider 상태 변경 리스너 등록
  // void _startListeningToNodeState() {
  //   _nodeStateSubscription?.cancel();
  //   _nodeStateSubscription = _nodeProvider.syncStateStream.listen((state) {
  //     _handleNodeSyncStateChange(state);
  //   });
  // }

  /// NodeSyncState 변경 처리
  // void _handleNodeSyncStateChange(NodeSyncState state) {
  //   // 현재 설정된 서버와 NodeProvider의 서버가 같은지 확인
  //   final currentServer = _preferenceProvider.getElectrumServer();
  //   final isCurrentServerConnected = _nodeProvider.host == currentServer.host &&
  //       _nodeProvider.port == currentServer.port &&
  //       _nodeProvider.ssl == currentServer.ssl;

  //   // 현재 서버와 연결된 상태에서만 상태 업데이트
  //   if (isCurrentServerConnected) {
  //     _updateStatusFromNodeSyncState(state, allowConnectingOverride: false);
  //   }

  //   // 연결 중 상태에서의 상태 변화 처리
  //   if (_nodeConnectionStatus == NodeConnectionStatus.connecting) {
  //     _updateStatusFromNodeSyncState(state, allowConnectingOverride: true);
  //   }
  // }

  /// NodeSyncState에 따른 NodeConnectionStatus 업데이트
  // void _updateStatusFromNodeSyncState(NodeSyncState state,
  //     {required bool allowConnectingOverride}) {
  //   switch (state) {
  //     case NodeSyncState.syncing:
  //       if (allowConnectingOverride || _nodeConnectionStatus != NodeConnectionStatus.connecting) {
  //         setNodeConnectionStatus(NodeConnectionStatus.connected);
  //       }
  //       break;
  //     case NodeSyncState.completed:
  //       if (allowConnectingOverride || _nodeConnectionStatus != NodeConnectionStatus.connecting) {
  //         setNodeConnectionStatus(NodeConnectionStatus.connected);
  //       }
  //       break;
  //     case NodeSyncState.failed:
  //       setNodeConnectionStatus(NodeConnectionStatus.failed);
  //       break;
  //     case NodeSyncState.init:
  //       if (!allowConnectingOverride && _nodeConnectionStatus != NodeConnectionStatus.connecting) {
  //         setNodeConnectionStatus(NodeConnectionStatus.waiting);
  //       }
  //       break;
  //   }
  // }

  /// 초기 NodeProvider 상태 확인
  void _checkInitialNodeProviderStatus() {
    final currentServer = _preferenceProvider.getElectrumServer();
    changeServer(currentServer);
  }

  void setNodeConnectionStatus(NodeConnectionStatus status) {
    _nodeConnectionStatus = status;
    notifyListeners();
  }

  void setServerAddressFormatError(bool value) {
    _isServerAddressFormatError = value;
    notifyListeners();
  }

  void setPortOutOfRangeError(bool value) {
    _isPortOutOfRangeError = value;
    notifyListeners();
  }

  void setDefaultServerMenuVisible(bool value) {
    _isDefaultServerMenuVisible = value;
    notifyListeners();
  }

  void setCurrentServer(ElectrumServer server) {
    _currentServer = server;
    notifyListeners();
  }

  /// 도메인 유효성 검사
  bool isValidDomain(String input) {
    final domainRegExp =
        RegExp(r'^(?!:\/\/)([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$');
    return domainRegExp.hasMatch(input);
  }

  /// 포트 유효성 검사
  bool isValidPort(String portText) {
    final port = int.tryParse(portText);
    return port != null && port > 0 && port <= 65535;
  }

  /// 현재 서버와 동일한지 확인
  bool isSameWithCurrentServer(String serverAddress, String portText, bool useSsl) {
    return serverAddress == _currentServer.host &&
        portText == _currentServer.port.toString() &&
        useSsl == _currentServer.ssl;
  }

  /// 초기 서버 정보와 다른지 확인 (새로 추가)
  bool isDifferentFromInitialServer(String serverAddress, String portText, bool useSsl) {
    return serverAddress != _currentServer.host ||
        portText != _currentServer.port.toString() ||
        useSsl != _currentServer.ssl;
  }

  /// 입력 형식 유효성 검사: 서버 주소 형식, 포트 범위 검사
  void validateInputFormat(String serverAddress, String portText) {
    setServerAddressFormatError(!isValidDomain(serverAddress));
    setPortOutOfRangeError(!isValidPort(portText));
  }

  /// 서버 변경 및 상태 업데이트
  Future<bool> changeServerAndUpdateState(ElectrumServer newServer) async {
    setNodeConnectionStatus(NodeConnectionStatus.connecting);

    final result = await _nodeProvider.changeServer(newServer);

    if (result.isFailure) {
      setNodeConnectionStatus(NodeConnectionStatus.failed);
      return false;
    }

    setCurrentServer(newServer);

    _preferenceProvider.setCustomElectrumServer(
      newServer.host,
      newServer.port,
      newServer.ssl,
    );
    setNodeConnectionStatus(NodeConnectionStatus.connected);
    return true;
  }

  /// 서버 변경 및 연결 테스트
  void changeServer(ElectrumServer currentServer) {
    debugPrint('서버 상태 점검 시작: ${currentServer.host}:${currentServer.port}');

    // NodeProvider가 초기화되었는지 확인 // 이거 왜 하지?
    // if (!_nodeProvider.isInitialized) {
    //   debugPrint('서버 상태 점검: [NodeProvider 초기화되지 않음]');
    // }

    // 현재 연결된 서버와 설정된 서버가 같은지 확인
    final isSameServerConnected = _nodeProvider.host == currentServer.host &&
        _nodeProvider.port == currentServer.port &&
        _nodeProvider.ssl == currentServer.ssl;

    debugPrint('NodeProvider 초기화됨 - 서버 일치 여부: $isSameServerConnected');

    if (!isSameServerConnected) {
      debugPrint(
          '서버 상태 점검: [다른 서버에 연결됨] NodeProvider: ${_nodeProvider.host}:${_nodeProvider.port}, 설정: ${currentServer.host}:${currentServer.port}');
    }

    _performServerConnectionTest(currentServer);
  }

  /// 서버 연결 테스트 수행
  void _performServerConnectionTest(ElectrumServer currentServer) {
    debugPrint('서버 상태 점검: [연결 테스트 시작] ${currentServer.host}:${currentServer.port}');

    setNodeConnectionStatus(NodeConnectionStatus.connecting);

    _nodeProvider.checkServerConnection(currentServer).then((result) {
      if (result.isFailure) {
        debugPrint('서버 상태 점검: [연결 실패] ${currentServer.host}:${currentServer.port}');
        setNodeConnectionStatus(NodeConnectionStatus.failed);
      } else {
        debugPrint('서버 상태 점검: [연결 성공] ${currentServer.host}:${currentServer.port}');
        setNodeConnectionStatus(NodeConnectionStatus.connected);
      }
    }).catchError((error) {
      debugPrint('서버 상태 점검: [테스트 중 오류] ${currentServer.host}:${currentServer.port} - $error');
      setNodeConnectionStatus(NodeConnectionStatus.failed);
    });
  }

  @override
  void dispose() {
    // _nodeStateSubscription?.cancel();
    super.dispose();
  }
}
