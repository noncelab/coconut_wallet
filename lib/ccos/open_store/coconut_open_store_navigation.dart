import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_intro_screen.dart';
import 'package:coconut_wallet/screens/ccos/store/coconut_open_store_feature_detail_screen.dart';
import 'package:coconut_wallet/screens/ccos/store/coconut_open_store_screen.dart';
import 'package:flutter/material.dart';

Future<void> openCoconutOpenStoreIntroScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosOpenStoreIntro),
      builder: (_) => const CoconutOpenStoreIntroScreen(),
    ),
  );
}

Future<void> openCoconutOpenStore(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosOpenStore),
      builder: (_) => const CoconutOpenStoreScreen(),
    ),
  );
}

Future<void> openCoconutOpenStoreFeature(BuildContext context, String featureId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosOpenStoreFeatureDetail),
      builder: (_) => CoconutOpenStoreFeatureDetailScreen(featureId: featureId),
    ),
  );
}
