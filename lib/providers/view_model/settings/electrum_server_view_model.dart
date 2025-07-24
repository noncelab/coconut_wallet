import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
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

  NodeConnectionStatus get nodeConnectionStatus => _nodeConnectionStatus;

  bool get isServerAddressFormatError => _isServerAddressFormatError;
  bool get isPortOutOfRangeError => _isPortOutOfRangeError;
  bool get isDefaultServerMenuVisible => _isDefaultServerMenuVisible;
  bool get useSsl => _useSsl;

  ElectrumServer get currentServer => _currentServer;

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
}
