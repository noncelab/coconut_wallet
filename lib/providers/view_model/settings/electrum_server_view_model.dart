import 'dart:async';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
import 'package:coconut_wallet/screens/settings/electrum_server_screen.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class ElectrumServerViewModel extends ChangeNotifier {
  final NodeProvider _nodeProvider;
  final ElectrumServerProvider _electrumServerProvider;

  late ElectrumServer _initialServer;
  late ElectrumServer _currentServer;
  ElectrumServer get initialServer => _initialServer;
  ElectrumServer? get currentServer => _currentServer;

  List<ElectrumServer> _userServers = [];

  List<ElectrumServer> get userServers => _userServers;
  bool get hasUserServers => _userServers.isNotEmpty;

  NodeConnectionStatus _nodeConnectionStatus = NodeConnectionStatus.waiting;
  final Map<ElectrumServer, NodeConnectionStatus> _connectionStatusMap = {};
  bool _isServerAddressFormatError = false;
  bool _isPortOutOfRangeError = false;
  bool _isDefaultServerMenuVisible = false;
  bool _isFloresta = false;
  int _rpcPort = 0;

  NodeConnectionStatus get nodeConnectionStatus => _nodeConnectionStatus;
  Map<ElectrumServer, NodeConnectionStatus> get connectionStatusMap => _connectionStatusMap;
  bool get isServerAddressFormatError => _isServerAddressFormatError;
  bool get isPortOutOfRangeError => _isPortOutOfRangeError;
  bool get isDefaultServerMenuVisible => _isDefaultServerMenuVisible;
  bool get isFloresta => _isFloresta;
  int get rpcPort => _rpcPort;

  ElectrumServerViewModel(this._nodeProvider, this._electrumServerProvider) {
    // 현재 설정된 서버 정보 가져오기
    _initialServer = _electrumServerProvider.getElectrumServer();

    // 초기 서버 정보 설정
    _setCurrentServer(_initialServer);

    // 초기 상태 확인
    _checkInitialNodeProviderStatus();

    // 모든 ElectrumServer 연결 테스트
    _checkAllElectrumServerConnections();

    // 사용자 서버 정보 불러오기
    _loadUserServers();
  }

  /// 초기 NodeProvider 상태 확인
  void _checkInitialNodeProviderStatus() {
    final currentServer = _electrumServerProvider.getElectrumServer();
    _performServerConnectionTest(currentServer);
  }

  /// 모든 기본 일렉트럼 서버 상태 체크
  void _checkAllElectrumServerConnections() {
    final isRegtestFlavor = NetworkType.currentNetworkType == NetworkType.regtest;
    final serverList = isRegtestFlavor ? DefaultElectrumServer.regtestServers : DefaultElectrumServer.mainnetServers;

    for (final server in serverList) {
      _connectionStatusMap[server] = NodeConnectionStatus.connecting;

      _nodeProvider
          .checkServerConnection(server)
          .then((result) {
            _connectionStatusMap[server] =
                result.isSuccess ? NodeConnectionStatus.connected : NodeConnectionStatus.failed;
            debugPrint(
              '[서버 상태 체크] ${_connectionStatusMap[server]!.name} - ${result.isSuccess ? 'Connected' : 'Failed'}',
            );
            notifyListeners();
          })
          .catchError((_) {
            _connectionStatusMap[server] = NodeConnectionStatus.failed;
            notifyListeners();
          });
    }
  }

  /// 사용자 서버 목록 로드
  Future<void> _loadUserServers() async {
    try {
      _userServers = (await _electrumServerProvider.getUserServers());
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to load user servers: $e');
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

  void setFloresta(bool value) {
    _isFloresta = value;
    notifyListeners();
  }

  void setRpcPort(int value) {
    _rpcPort = value;
    notifyListeners();
  }

  void _setCurrentServer(ElectrumServer server) {
    _currentServer = server;
    notifyListeners();
  }

  /// 도메인 유효성 검사
  bool isValidDomain(String input) {
    // IPv4 주소 패턴
    final ipv4Pattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (ipv4Pattern.hasMatch(input)) {
      // 각 옥텟이 0-255 범위인지 확인
      final parts = input.split('.');
      for (final part in parts) {
        final octet = int.tryParse(part) ?? -1;
        if (octet < 0 || octet > 255) {
          return false;
        }
      }
      return true;
    }

    // .onion 주소 확인
    if (input.trim().toLowerCase().endsWith('.onion')) {
      final onionRegex = RegExp(r'^[a-z0-9]+.onion$', caseSensitive: false);
      return onionRegex.hasMatch(input.trim().toLowerCase());
    }

    // 일반 도메인 패턴
    final domainRegExp = RegExp(r'^(?!:\/\/)([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$');
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

    // 서버 연결 테스트
    final connectionResult = await _nodeProvider.checkServerConnection(newServer);
    if (connectionResult.isFailure) {
      setNodeConnectionStatus(NodeConnectionStatus.failed);
      return false;
    }

    final result = await _nodeProvider.changeServer(newServer);

    _setCurrentServer(newServer);
    _electrumServerProvider.setCustomElectrumServer(
      newServer.host,
      newServer.port,
      newServer.ssl,
      isFloresta: newServer.isFloresta,
      rpcPort: newServer.rpcPort,
    );

    if (!_isDefaultServer(newServer) && !_isUserServer(newServer)) {
      await _electrumServerProvider.addUserServer(
        newServer.host,
        newServer.port,
        newServer.ssl,
        isFloresta: newServer.isFloresta,
        rpcPort: newServer.rpcPort,
      );
      await _loadUserServers();
    }

    debugPrint('서버 정보 업데이트: ${newServer.host} ${newServer.port} ${newServer.ssl} isFloresta=${newServer.isFloresta}');

    if (result.isFailure) {
      setNodeConnectionStatus(NodeConnectionStatus.failed);
      return false;
    }

    setNodeConnectionStatus(NodeConnectionStatus.connected);
    return true;
  }

  Future<void> removeUserServer(ElectrumServer server) async {
    await _electrumServerProvider.removeUserServer(server);
    await _loadUserServers();
  }

  bool _isDefaultServer(ElectrumServer server) {
    final isRegtestFlavor = NetworkType.currentNetworkType == NetworkType.regtest;
    final defaultServers =
        isRegtestFlavor ? DefaultElectrumServer.regtestServers : DefaultElectrumServer.mainnetServers;

    return defaultServers.any(
      (defaultServer) =>
          defaultServer.host == server.host && defaultServer.port == server.port && defaultServer.ssl == server.ssl,
    );
  }

  /// 사용자 서버 목록에 포함되어 있는지 확인
  bool _isUserServer(ElectrumServer server) {
    return _userServers.any(
      (userServer) => userServer.host == server.host && userServer.port == server.port && userServer.ssl == server.ssl,
    );
  }

  /// 서버 연결 테스트 수행
  void _performServerConnectionTest(ElectrumServer currentServer) {
    debugPrint('서버 상태 점검: [연결 테스트 시작] ${currentServer.host}:${currentServer.port}');

    setNodeConnectionStatus(NodeConnectionStatus.connecting);

    _nodeProvider
        .checkServerConnection(currentServer)
        .then((result) {
          if (result.isFailure) {
            debugPrint('서버 상태 점검: [연결 실패] ${currentServer.host}:${currentServer.port}');
            setNodeConnectionStatus(NodeConnectionStatus.failed);
          } else {
            debugPrint('서버 상태 점검: [연결 성공] ${currentServer.host}:${currentServer.port}');
            setNodeConnectionStatus(NodeConnectionStatus.connected);
          }
        })
        .catchError((error) {
          debugPrint('서버 상태 점검: [테스트 중 오류] ${currentServer.host}:${currentServer.port} - $error');
          setNodeConnectionStatus(NodeConnectionStatus.failed);
        });
  }
}
