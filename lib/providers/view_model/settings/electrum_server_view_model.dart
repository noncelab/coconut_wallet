import 'dart:async';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/screens/settings/electrum_server_screen.dart';
import 'package:flutter/material.dart';

class ElectrumServerViewModel extends ChangeNotifier {
  ElectrumServerViewModel();

  NodeConnectionStatus _nodeConnectionStatus = NodeConnectionStatus.waiting;

  bool _isServerAddressFormatError = false; // 서버 주소 형식
  bool _isPortOutOfRangeError = false; // 1 ~ 65535 포트 범위
  bool _isDefaultServerMenuVisible = false; // 기본 서버 메뉴 visibility
  bool _useSsl = false;

  ElectrumServer _currentServer = ElectrumServer.custom(
    DefaultElectrumServer.fromServerType('coconut').server.host,
    DefaultElectrumServer.fromServerType('coconut').server.port,
    DefaultElectrumServer.fromServerType('coconut').server.ssl,
  );

  StreamSubscription<NodeSyncState>? _nodeStateSubscription;
  NodeProvider? _nodeProvider;
  PreferenceProvider? _preferenceProvider;

  NodeConnectionStatus get nodeConnectionStatus => _nodeConnectionStatus;

  bool get isServerAddressFormatError => _isServerAddressFormatError;
  bool get isPortOutOfRangeError => _isPortOutOfRangeError;
  bool get isDefaultServerMenuVisible => _isDefaultServerMenuVisible;
  bool get useSsl => _useSsl;

  ElectrumServer get currentServer => _currentServer;

  /// NodeProvider와 PreferenceProvider 초기화 및 상태 감지 시작
  void initialize(NodeProvider nodeProvider, PreferenceProvider preferenceProvider) {
    _nodeProvider = nodeProvider;
    _preferenceProvider = preferenceProvider;

    // NodeProvider 상태 변경 감지 시작
    _startListeningToNodeState();

    // 초기 상태 확인
    _checkInitialNodeProviderStatus();
  }

  /// NodeProvider 상태 변경 리스너 등록
  void _startListeningToNodeState() {
    _nodeStateSubscription?.cancel();
    _nodeStateSubscription = _nodeProvider!.syncStateStream.listen((state) {
      _handleNodeSyncStateChange(state);
    });
  }

  /// NodeSyncState 변경 처리
  void _handleNodeSyncStateChange(NodeSyncState state) {
    if (_preferenceProvider == null || _nodeProvider == null) return;

    // 현재 설정된 서버와 NodeProvider의 서버가 같은지 확인
    final currentServer = _preferenceProvider!.getElectrumServer();
    final isCurrentServerConnected = _nodeProvider!.host == currentServer.host &&
        _nodeProvider!.port == currentServer.port &&
        _nodeProvider!.ssl == currentServer.ssl;

    // 현재 서버와 연결된 상태에서만 상태 업데이트
    if (isCurrentServerConnected) {
      _updateStatusFromNodeSyncState(state, allowConnectingOverride: false);
    }

    // 연결 중 상태에서의 상태 변화 처리
    if (_nodeConnectionStatus == NodeConnectionStatus.connecting) {
      _updateStatusFromNodeSyncState(state, allowConnectingOverride: true);
    }
  }

  /// NodeSyncState에 따른 NodeConnectionStatus 업데이트
  void _updateStatusFromNodeSyncState(NodeSyncState state,
      {required bool allowConnectingOverride}) {
    switch (state) {
      case NodeSyncState.syncing:
        if (allowConnectingOverride || _nodeConnectionStatus != NodeConnectionStatus.connecting) {
          setNodeConnectionStatus(NodeConnectionStatus.connected);
        }
        break;
      case NodeSyncState.completed:
        if (allowConnectingOverride || _nodeConnectionStatus != NodeConnectionStatus.connecting) {
          setNodeConnectionStatus(NodeConnectionStatus.connected);
        }
        break;
      case NodeSyncState.failed:
        setNodeConnectionStatus(NodeConnectionStatus.failed);
        break;
      case NodeSyncState.init:
        if (!allowConnectingOverride && _nodeConnectionStatus != NodeConnectionStatus.connecting) {
          setNodeConnectionStatus(NodeConnectionStatus.waiting);
        }
        break;
    }
  }

  /// 초기 NodeProvider 상태 확인
  void _checkInitialNodeProviderStatus() {
    if (_nodeProvider == null || _preferenceProvider == null) return;

    final currentServer = _preferenceProvider!.getElectrumServer();
    checkCurrentNodeProviderStatus(_nodeProvider!, currentServer);
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

  void setUseSsl(bool value) {
    _useSsl = value;
    notifyListeners();
  }

  void setCurrentServer(ElectrumServer server) {
    _currentServer = server;
    setUseSsl(server.ssl);
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

  /// 입력 형식 유효성 검사
  void validateInputFormat(String serverAddress, String portText) {
    // 서버 주소 형식 검사
    setServerAddressFormatError(!isValidDomain(serverAddress));

    // 포트 범위 검사
    setPortOutOfRangeError(!isValidPort(portText));
  }

  /// 현재 NodeProvider 상태 확인
  void checkCurrentNodeProviderStatus(NodeProvider nodeProvider, ElectrumServer currentServer) {
    debugPrint('서버 상태 점검 시작: ${currentServer.host}:${currentServer.port}');

    // NodeProvider가 초기화되었는지 확인
    if (nodeProvider.isInitialized) {
      // 현재 연결된 서버와 설정된 서버가 같은지 확인
      final isCurrentServerConnected = nodeProvider.host == currentServer.host &&
          nodeProvider.port == currentServer.port &&
          nodeProvider.ssl == currentServer.ssl;

      debugPrint('NodeProvider 초기화됨 - 서버 일치 여부: $isCurrentServerConnected');

      if (isCurrentServerConnected) {
        // 현재 NodeProvider의 동기화 상태 확인
        final currentSyncState = nodeProvider.state.nodeSyncState;
        debugPrint('현재 동기화 상태: $currentSyncState');

        switch (currentSyncState) {
          case NodeSyncState.completed:
            debugPrint('서버 상태 점검: [이미 연결됨 - 동기화 완료]');
            setNodeConnectionStatus(NodeConnectionStatus.connected);
            return;
          case NodeSyncState.syncing:
            debugPrint('서버 상태 점검: [이미 연결됨 - 동기화 중]');
            setNodeConnectionStatus(NodeConnectionStatus.connected);
            return;
          case NodeSyncState.failed:
            debugPrint('서버 상태 점검: [연결됨 - 동기화 실패]');
            setNodeConnectionStatus(NodeConnectionStatus.failed);
            return;
          default:
            debugPrint('서버 상태 점검: [연결됨 - 기타 상태: $currentSyncState]');
            break;
        }
      } else {
        debugPrint(
            '서버 상태 점검: [다른 서버에 연결됨] NodeProvider: ${nodeProvider.host}:${nodeProvider.port}, 설정: ${currentServer.host}:${currentServer.port}');
      }
    } else {
      debugPrint('서버 상태 점검: [NodeProvider 초기화되지 않음]');
    }

    // NodeProvider가 초기화되지 않았거나 다른 서버에 연결된 경우
    // 별도의 연결 테스트 수행
    _performServerConnectionTest(nodeProvider, currentServer);
  }

  /// 서버 연결 테스트 수행
  void _performServerConnectionTest(NodeProvider nodeProvider, ElectrumServer currentServer) {
    debugPrint('서버 상태 점검: [연결 테스트 시작]');

    nodeProvider.checkServerConnection(currentServer).then((result) {
      if (result.isFailure) {
        debugPrint('서버 상태 점검: [연결 실패]');
        setNodeConnectionStatus(NodeConnectionStatus.unconnected);
      } else {
        debugPrint('서버 상태 점검: [연결 가능]');
        // 연결은 가능하지만 NodeProvider가 해당 서버에 연결되지 않은 상태
        setNodeConnectionStatus(NodeConnectionStatus.waiting);
      }
    }).catchError((error) {
      debugPrint('서버 상태 점검: [테스트 중 오류] $error');
      setNodeConnectionStatus(NodeConnectionStatus.unconnected);
    });
  }

  @override
  void dispose() {
    _nodeStateSubscription?.cancel();
    super.dispose();
  }
}
