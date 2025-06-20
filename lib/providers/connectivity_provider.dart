import 'package:flutter/material.dart';

class ConnectivityProvider extends ValueNotifier<bool> {
  ConnectivityProvider() : super(true);

  bool get isNetworkOff => !value;
  bool get isNetworkOn => value;

  void setIsNetworkOn(bool isNetworkOn) {
    value = isNetworkOn;
  }
}
