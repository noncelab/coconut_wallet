import 'package:flutter/material.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool? _isNetworkOn;
  bool? get isNetworkOn => _isNetworkOn;

  void setIsNetworkOn(bool isNetworkOn) {
    if (_isNetworkOn != isNetworkOn) {
      _isNetworkOn = isNetworkOn;
      notifyListeners();
    }
  }
}
