import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

class CoconutCrewScreen extends StatelessWidget {
  const CoconutCrewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(context: context, title: t.app_info_screen.coconut_crew),
      body: Container(),
    );
  }
}
