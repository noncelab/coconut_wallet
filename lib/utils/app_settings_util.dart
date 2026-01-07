import 'dart:io';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

Future<void> openAppSettings() async {
  if (Platform.isIOS) {
    const url = 'app-settings:';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  } else if (Platform.isAndroid) {
    const channel = MethodChannel('app-settings');
    channel.invokeMethod('openAppSettings');
  }
}
