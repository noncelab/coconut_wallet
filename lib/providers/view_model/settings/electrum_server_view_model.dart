import 'dart:async';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/node_connection_status.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
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
  bool _isServerAddressFormatError = false; // 서버 주소 형식
  bool _isPortOutOfRangeError = false; // 1 ~ 65535 포트 범위
  bool _isDefaultServerMenuVisible = false; // 기본 서버 메뉴 visibility

  // 인증서를 신뢰할 수 없는 경우, 사용자 확인이 필요한 커스텀 서버와 확인창에 보여줄 지문
  ElectrumServer? _pendingUntrustedServer;
  String? _pendingCertificateFingerprint;

  NodeConnectionStatus get nodeConnectionStatus => _nodeConnectionStatus;
  Map<ElectrumServer, NodeConnectionStatus> get connectionStatusMap => _connectionStatusMap;
  bool get isServerAddressFormatError => _isServerAddressFormatError;
  bool get isPortOutOfRangeError => _isPortOutOfRangeError;
  bool get isDefaultServerMenuVisible => _isDefaultServerMenuVisible;
  String? get pendingCertificateFingerprint => _pendingCertificateFingerprint;

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
    final networkType = NetworkType.currentNetworkType;
    final serverList =
        networkType == NetworkType.regtest
            ? DefaultElectrumServer.regtestServers
            : networkType == NetworkType.testnet
            ? DefaultElectrumServer.testnetServers
            : DefaultElectrumServer.mainnetServers;

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
    final isSameServer = isSameWithCurrentServer(newServer.host, newServer.port.toString(), newServer.ssl);
    final isAlreadyConnected =
        isSameServer && !_nodeProvider.hasConnectionError && _nodeProvider.state.nodeSyncState != NodeSyncState.failed;

    if (isAlreadyConnected) {
      setNodeConnectionStatus(NodeConnectionStatus.connected);
      return true;
    }

    setNodeConnectionStatus(NodeConnectionStatus.connecting);

    // 이 지점에 도달했다는 건 isAlreadyConnected가 false라는 뜻이다 — 서버가 그대로여도
    // 현재 연결이 끊겼거나 실패한 상태이므로 반드시 재검증해야 한다.(저장 버튼 클릭으로 복구 가능)
    {
      // 이전에 이미 핀닝된 커스텀 서버라면 저장된 지문을 그대로 사용해 매번 다시 신뢰 확인창을 띄우지 않음
      newServer = _withKnownFingerprint(newServer);

      final connectionResult = await _nodeProvider.checkServerConnection(newServer);
      if (connectionResult.isFailure) {
        // 커스텀 서버에서 인증서를 신뢰할 수 없는 경우에만 지문 확인 절차 진행
        if (connectionResult.error.code == ErrorCodes.untrustedCertificateError.code && !_isDefaultServer(newServer)) {
          await _beginUntrustedCertificateFlow(newServer);
          return false;
        }
        setNodeConnectionStatus(NodeConnectionStatus.failed);
        return false;
      }
    }

    final result = await _nodeProvider.changeServer(newServer);

    if (result.isFailure) {
      if (result.error.code == ErrorCodes.chainMismatchError.code) {
        setNodeConnectionStatus(NodeConnectionStatus.networkMismatch);
      } else {
        setNodeConnectionStatus(NodeConnectionStatus.failed);
      }
      return false;
    }

    _setCurrentServer(newServer);

    // 기본 서버는 host/port/ssl을 리터럴로 얼리지 않고 serverName 참조로 저장한다.
    // 이후 해당 기본 서버의 host나 지문이 바뀌어도 항상 최신 값을 따라간다.
    final matchedDefault = DefaultElectrumServer.findMatching(newServer.host, newServer.port, newServer.ssl);
    if (matchedDefault != null) {
      await _electrumServerProvider.setSelectedDefaultServer(matchedDefault.serverName);
    } else {
      await _electrumServerProvider.setCustomElectrumServer(
        newServer.host,
        newServer.port,
        newServer.ssl,
        pinnedCertFingerprint: newServer.pinnedCertFingerprint,
      );

      // 커스텀 서버는 사용자 서버 목록에도 (지문 포함) 최신 상태로 저장한다.
      await _electrumServerProvider.addUserServer(
        newServer.host,
        newServer.port,
        newServer.ssl,
        pinnedCertFingerprint: newServer.pinnedCertFingerprint,
      );
      await _loadUserServers();
    }

    debugPrint('서버 정보 업데이트: ${newServer.host} ${newServer.port} ${newServer.ssl}');

    setNodeConnectionStatus(NodeConnectionStatus.connected);
    return true;
  }

  /// 인증서를 신뢰할 수 없는 커스텀 서버의 지문을 확인하고, TOFU 확인창(untrustedCertificate 상태)으로 전환한다.
  Future<void> _beginUntrustedCertificateFlow(ElectrumServer server) async {
    final probeResult = await _nodeProvider.probeCertificateFingerprint(server);
    if (probeResult.isFailure) {
      setNodeConnectionStatus(NodeConnectionStatus.failed);
      return;
    }

    _pendingUntrustedServer = server;
    _pendingCertificateFingerprint = probeResult.value;
    setNodeConnectionStatus(NodeConnectionStatus.untrustedCertificate);
  }

  /// 사용자가 확인창에서 지문을 확인하고 신뢰를 승인했을 때 호출한다.
  Future<bool> trustPendingCertificateAndConnect() async {
    final server = _pendingUntrustedServer;
    final fingerprint = _pendingCertificateFingerprint;
    if (server == null || fingerprint == null) {
      return false;
    }

    _pendingUntrustedServer = null;
    _pendingCertificateFingerprint = null;

    return changeServerAndUpdateState(server.copyWith(pinnedCertFingerprint: fingerprint));
  }

  /// 사용자가 확인창에서 신뢰를 거부했을 때 호출한다.
  void cancelPendingCertificateTrust() {
    _pendingUntrustedServer = null;
    _pendingCertificateFingerprint = null;
    setNodeConnectionStatus(NodeConnectionStatus.failed);
  }

  /// 동일한 host/port/ssl로 이미 신뢰 승인되어 저장된 사용자 서버가 있으면 그 지문을 붙여서 반환한다.
  ElectrumServer _withKnownFingerprint(ElectrumServer server) {
    if (server.pinnedCertFingerprint != null) return server;

    final known = _findUserServer(server);
    if (known == null || known.pinnedCertFingerprint == null) return server;

    return server.copyWith(pinnedCertFingerprint: known.pinnedCertFingerprint);
  }

  Future<void> removeUserServer(ElectrumServer server) async {
    await _electrumServerProvider.removeUserServer(server);
    await _loadUserServers();
  }

  bool _isDefaultServer(ElectrumServer server) {
    return DefaultElectrumServer.findMatching(server.host, server.port, server.ssl) != null;
  }

  /// 사용자 서버 목록에서 동일한 host/port/ssl을 가진 항목을 찾는다.
  ElectrumServer? _findUserServer(ElectrumServer server) {
    for (final userServer in _userServers) {
      if (userServer.host == server.host && userServer.port == server.port && userServer.ssl == server.ssl) {
        return userServer;
      }
    }
    return null;
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
