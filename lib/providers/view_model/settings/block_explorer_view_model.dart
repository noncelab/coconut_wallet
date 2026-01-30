import 'dart:async';

import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/utils/url_normalize_util.dart';

enum ExplorerConnectionStatus { none, connecting, connected, failed }

class BlockExplorerViewModel extends ChangeNotifier {
  final PreferenceProvider _preferenceProvider;

  late bool _initialUseDefault;
  late String _initialCustomUrl;

  bool _isDefaultExplorerEnabled = true;
  String _customExplorerUrl = '';
  bool _hasChanges = false;
  bool _showAlertBox = false;
  ExplorerConnectionStatus _connectionStatus = ExplorerConnectionStatus.none;

  Timer? _connectionTimer;
  bool _disposed = false;

  BlockExplorerViewModel(this._preferenceProvider) {
    _loadSettings();
  }

  // Getters
  bool get isDefaultExplorerEnabled => _isDefaultExplorerEnabled;
  String get customExplorerUrl => _customExplorerUrl;
  bool get hasChanges => _hasChanges;
  bool get showAlertBox => _showAlertBox;

  bool get showCustomUrlTextField => !_isDefaultExplorerEnabled;
  bool get showConnectionStatus => _connectionStatus != ExplorerConnectionStatus.none;
  bool get isConnecting => _connectionStatus == ExplorerConnectionStatus.connecting;
  bool get isConnectionSuccessful => _connectionStatus == ExplorerConnectionStatus.connected;

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _disposed = true;
    super.dispose();
  }

  void _loadSettings() {
    _isDefaultExplorerEnabled = _preferenceProvider.useDefaultExplorer;
    _customExplorerUrl = _preferenceProvider.customExplorerUrl;

    _initialUseDefault = _isDefaultExplorerEnabled;
    _initialCustomUrl = _customExplorerUrl;

    if (!_isDefaultExplorerEnabled && _customExplorerUrl.isNotEmpty) {
      _showAlertBox = true;
    }

    notifyListeners();
  }

  void toggleDefaultExplorer(bool value) {
    _isDefaultExplorerEnabled = value;

    if (value) {
      _connectionStatus = ExplorerConnectionStatus.none;
      _showAlertBox = false;
    }

    _checkForChanges();
  }

  void onCustomUrlChanged(String value) {
    _customExplorerUrl = value;
    _checkForChanges();
  }

  void clearCustomUrl() {
    _customExplorerUrl = '';
    _connectionStatus = ExplorerConnectionStatus.none;
    _checkForChanges();
  }

  void _checkForChanges() {
    bool changed = false;

    if (_isDefaultExplorerEnabled != _initialUseDefault) {
      changed = true;
    } else if (!_isDefaultExplorerEnabled) {
      changed = _customExplorerUrl != _initialCustomUrl && _customExplorerUrl.isNotEmpty;
    }

    if (_hasChanges != changed) {
      _hasChanges = changed;
      notifyListeners();
    }
  }

  Future<void> saveChanges() async {
    if (_isDefaultExplorerEnabled) {
      await _preferenceProvider.setUseDefaultExplorer(true);

      _resetStateAfterSave();
    } else {
      await _testAndSaveCustomUrl();
    }
  }

  Future<void> _testAndSaveCustomUrl() async {
    _setConnectionStatus(ExplorerConnectionStatus.connecting);
    _showAlertBox = false;

    final String urlToTest = UrlNormalizeUtil.normalize(_customExplorerUrl);

    final Dio dio = Dio();
    try {
      final response = await dio.get(urlToTest);
      if (response.statusCode == 200) {
        await _preferenceProvider.setUseDefaultExplorer(false);
        await _preferenceProvider.setCustomExplorerUrl(urlToTest);

        _customExplorerUrl = urlToTest;

        _setConnectionStatus(ExplorerConnectionStatus.connected);
        _showAlertBox = true;
        _resetStateAfterSave();

        _connectionTimer?.cancel();
        _connectionTimer = Timer(const Duration(seconds: 5), () {
          if (!_disposed) {
            _connectionStatus = ExplorerConnectionStatus.none;
            notifyListeners();
          }
        });
      } else {
        _setConnectionStatus(ExplorerConnectionStatus.failed);
      }
    } catch (e) {
      _setConnectionStatus(ExplorerConnectionStatus.failed);
    }
  }

  void _setConnectionStatus(ExplorerConnectionStatus status) {
    _connectionStatus = status;
    notifyListeners();
  }

  void _resetStateAfterSave() {
    _initialUseDefault = _isDefaultExplorerEnabled;
    _initialCustomUrl = _customExplorerUrl;
    _hasChanges = false;
    notifyListeners();
  }
}
