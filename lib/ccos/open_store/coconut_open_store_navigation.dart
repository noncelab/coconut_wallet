import 'package:coconut_wallet/screens/ccos/coconut_open_store_intro_screen.dart';
import 'package:flutter/material.dart';

Future<void> openCoconutOpenStoreIntroScreen(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CoconutOpenStoreIntroScreen()));
}
