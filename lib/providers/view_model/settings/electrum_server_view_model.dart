import 'dart:async';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
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
  final Map<ElectrumServer, NodeConnectionStatus> _serverConnectionMap = {};
  bool _isServerAddressFormatError = false; // 서버 주소 형식
  bool _isPortOutOfRangeError = false; // 1 ~ 65535 포트 범위
  bool _isDefaultServerMenuVisible = false; // 기본 서버 메뉴 visibility

  NodeConnectionStatus get nodeConnectionStatus => _nodeConnectionStatus;
  Map<ElectrumServer, NodeConnectionStatus> get serverConnectionMap => _serverConnectionMap;
  bool get isServerAddressFormatError => _isServerAddressFormatError;
  bool get isPortOutOfRangeError => _isPortOutOfRangeError;
  bool get isDefaultServerMenuVisible => _isDefaultServerMenuVisible;

  ElectrumServerViewModel(this._nodeProvider, this._preferenceProvider) {
    // 현재 설정된 서버 정보 가져오기
    _initialServer = _preferenceProvider.getElectrumServer();

    // 초기 서버 정보 설정
    setCurrentServer(_initialServer);

    // 초기 상태 확인
    _checkInitialNodeProviderStatus();

    // 모든 ElectrumServer 연결 테스트
    _checkAllElectrumServerConnections();
  }

  /// 초기 NodeProvider 상태 확인
  void _checkInitialNodeProviderStatus() {
    final currentServer = _preferenceProvider.getElectrumServer();
    changeServer(currentServer);
  }

  /// 모든 기본 일렉트럼 서버 상태 체크
  void _checkAllElectrumServerConnections() {
    final isRegtestFlavor = NetworkType.currentNetworkType == NetworkType.regtest;
    final serverList = isRegtestFlavor
        ? DefaultElectrumServer.regtestServers
        : DefaultElectrumServer.mainnetServers;

    for (final server in serverList) {
      _serverConnectionMap[server] = NodeConnectionStatus.connecting;

      _nodeProvider.checkServerConnection(server).then((result) {
        _serverConnectionMap[server] =
            result.isSuccess ? NodeConnectionStatus.connected : NodeConnectionStatus.failed;
        debugPrint(
            '[서버 상태 체크] ${_serverConnectionMap[server]!.name} - ${result.isSuccess ? 'Connected' : 'Failed'}');
        notifyListeners();
      }).catchError((_) {
        _serverConnectionMap[server] = NodeConnectionStatus.failed;
        notifyListeners();
      });
    }
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
    debugPrint(
        'current server: ${_currentServer.host} ${_currentServer.port} ${_currentServer.ssl}');
    debugPrint('new server: $serverAddress $portText $useSsl');
    return serverAddress == _currentServer.host &&
        portText == _currentServer.port.toString() &&
        useSsl == _currentServer.ssl;
  }

  /// 초기 서버 정보와 다른지 확인
  bool isDifferentFromInitialServer(String serverAddress, String portText, bool useSsl) {
    return serverAddress != _initialServer.host ||
        portText != _initialServer.port.toString() ||
        useSsl != _initialServer.ssl;
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

    // 상태 상관없이 서버 정보 업데이트
    setCurrentServer(newServer);
    _preferenceProvider.setCustomElectrumServer(
      newServer.host,
      newServer.port,
      newServer.ssl,
    );

    debugPrint('서버 정보 업데이트: ${newServer.host} ${newServer.port} ${newServer.ssl}');

    if (result.isFailure) {
      setNodeConnectionStatus(NodeConnectionStatus.failed);
      return false;
    }

    setNodeConnectionStatus(NodeConnectionStatus.connected);
    return true;
  }

  /// 서버 변경 및 연결 테스트
  void changeServer(ElectrumServer currentServer) {
    debugPrint('서버 상태 점검 시작: ${currentServer.host}:${currentServer.port}');

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
}
