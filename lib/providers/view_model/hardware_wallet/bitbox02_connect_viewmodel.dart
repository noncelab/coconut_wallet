import 'dart:async';

import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_exceptions.dart';
import 'package:flutter/foundation.dart';

enum BitBox02ConnectStep {
  idle,
  scanning,
  connecting,
  pairing,
  paired,
  error,
}

class BitBox02ConnectViewModel extends ChangeNotifier {
  BitBox02ConnectStep _step = BitBox02ConnectStep.idle;
  String _statusMessage = '';
  String _pairingCode = '';
  BitBox02Device? _device;
  String? _errorMessage;
  bool _mockMode = false;

  BitBox02ConnectStep get step => _step;
  String get statusMessage => _statusMessage;
  String get pairingCode => _pairingCode;
  BitBox02Device? get device => _device;
  String? get errorMessage => _errorMessage;
  bool get isPaired => _step == BitBox02ConnectStep.paired;
  bool get mockMode => _mockMode;

  void setMockMode(bool value) {
    _mockMode = value;
    notifyListeners();
  }

  void _setState(BitBox02ConnectStep step, {String? status}) {
    _step = step;
    if (status != null) _statusMessage = status;
    notifyListeners();
  }

  Future<void> connect({required String transport, String configJson = '', String? host, int? port}) async {
    if (_step == BitBox02ConnectStep.connecting ||
        _step == BitBox02ConnectStep.pairing) {
      return; // Already in progress
    }
    if (_step == BitBox02ConnectStep.paired) {
      return; // Already connected
    }

    if (_mockMode) {
      await _connectMock();
      return;
    }

    _setState(BitBox02ConnectStep.connecting, status: 'Connecting to BitBox02...');

    try {
      _device = await BitBox02Device.connect(
        transport: transport,
        configJson: configJson,
        host: host,
        port: port,
      );

      if (configJson.isNotEmpty) {
        await _device!.loadConfig(configJson);
      }

      _setState(BitBox02ConnectStep.pairing, status: 'Initializing...');
      await _device!.init();

      _setState(BitBox02ConnectStep.paired, status: 'BitBox02 connected');
    } on BitBox02ConnectException catch (e) {
      _errorMessage = e.message;
      _setState(BitBox02ConnectStep.error, status: 'Connection failed');
    } on BitBox02InitException catch (e) {
      _errorMessage = e.message;
      _setState(BitBox02ConnectStep.error, status: 'Initialization failed');
    } catch (e) {
      _errorMessage = e.toString();
      _setState(BitBox02ConnectStep.error, status: 'Unexpected error');
    }
  }

  Future<void> _connectMock() async {
    _errorMessage = null;
    _device = null;

    _setState(BitBox02ConnectStep.connecting, status: 'Connecting to BitBox02 (mock)...');
    await Future.delayed(const Duration(seconds: 1));

    _setState(BitBox02ConnectStep.pairing, status: 'Initializing Noise handshake...');
    await Future.delayed(const Duration(seconds: 2));

    _setState(BitBox02ConnectStep.paired, status: 'BitBox02 paired (mock)');
  }

  Future<void> disconnect() async {
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
      _device = null;
    }
    _setState(BitBox02ConnectStep.idle, status: '');
  }

  void reset() {
    _step = BitBox02ConnectStep.idle;
    _statusMessage = '';
    _pairingCode = '';
    _device = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Don't await disconnect — just fire and forget. State updates
    // after disposal are safely ignored by not notifying listeners.
    _device = null;
    super.dispose();
  }
}
