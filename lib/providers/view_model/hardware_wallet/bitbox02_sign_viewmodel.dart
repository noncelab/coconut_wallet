import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_exceptions.dart';
import 'package:flutter/foundation.dart';

enum BitBox02SignStep {
  connecting,
  signing,
  done,
  error,
}

class BitBox02SignViewModel extends ChangeNotifier {
  BitBox02SignStep _step = BitBox02SignStep.connecting;
  String _statusMessage = 'Connect your BitBox02 to sign the transaction';
  String? _errorMessage;
  bool _mockMode = false;
  BitBox02Device? _device;
  String _signedPsbt = '';
  bool _isSigning = false;

  final String psbtBase64;
  final String walletName;

  BitBox02SignViewModel({
    required this.psbtBase64,
    required this.walletName,
    bool mockMode = false,
  }) {
    _mockMode = mockMode;
  }

  BitBox02SignStep get step => _step;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  bool get mockMode => _mockMode;
  String get signedPsbt => _signedPsbt;
  bool get isSigning => _isSigning;

  void setMockMode(bool value) {
    _mockMode = value;
    notifyListeners();
  }

  Future<void> signTransaction({BitBox02Device? existingDevice}) async {
    if (_isSigning) return;

    _isSigning = true;
    _errorMessage = null;

    if (_mockMode) {
      await _signMock();
      _isSigning = false;
      return;
    }

    try {
      _setState(BitBox02SignStep.connecting, status: 'Connecting to BitBox02...');

      if (existingDevice != null) {
        _device = existingDevice;
      } else {
        _device = await BitBox02Device.connect(
          transport: 'usb',
        );
        await _device!.init();
      }

      _setState(BitBox02SignStep.signing,
          status: 'Please verify the transaction on your BitBox02...\nCheck amount, address, and fee on the device screen.');

      final signed = await _device!.btcSignPSBTBase64(psbtBase64);
      _signedPsbt = signed;

      _setState(BitBox02SignStep.done, status: 'Transaction signed');
    } on BitBox02ConnectException catch (e) {
      _errorMessage = e.message;
      _setState(BitBox02SignStep.error, status: 'Connection failed');
    } on BitBox02SignException catch (e) {
      _errorMessage = e.message;
      _setState(BitBox02SignStep.error, status: 'Signing failed');
    } on BitBox02InitException catch (e) {
      _errorMessage = e.message;
      _setState(BitBox02SignStep.error, status: 'Initialization failed');
    } catch (e) {
      _errorMessage = e.toString();
      _setState(BitBox02SignStep.error, status: 'Unexpected error');
    }

    _isSigning = false;
  }

  Future<void> _signMock() async {
    _setState(BitBox02SignStep.connecting, status: 'Connecting to BitBox02 (mock)...');
    await Future.delayed(const Duration(seconds: 1));

    _setState(BitBox02SignStep.signing,
        status: 'Please verify the transaction on your BitBox02...\nCheck amount, address, and fee on the device screen.');
    await Future.delayed(const Duration(seconds: 3));

    _signedPsbt = base64Encode(utf8.encode('signed_transaction_mock'));
    _setState(BitBox02SignStep.done, status: 'Transaction signed (mock)');
  }

  void _setState(BitBox02SignStep step, {required String status}) {
    _step = step;
    _statusMessage = status;
    notifyListeners();
  }

  void reset() {
    _step = BitBox02SignStep.connecting;
    _statusMessage = 'Connect your BitBox02 to sign the transaction';
    _errorMessage = null;
    _isSigning = false;
    _signedPsbt = '';
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
      _device = null;
    }
  }
}
