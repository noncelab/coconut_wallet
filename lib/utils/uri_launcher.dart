import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/external_link_analytics.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// [openInApp]이 false(기본값)면 외부 브라우저 앱으로, true면 인앱 브라우저
/// (iOS SFSafariViewController 등)로 연다.
///
/// analytics에는 [url]을 보내지 않고 [destination] 분류만 기록한다.
/// URL에는 주소·트랜잭션 해시 같은 민감 정보가 섞일 수 있기 때문이다.
Future<void> launchURL(
  BuildContext context,
  String url, {
  required ExternalLinkDestination destination,
  bool openInApp = false,
}) async {
  Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    if (!context.mounted) return;
    context.read<AnalyticsService>().logExternalLinkOpened(destination);
    await launchUrl(uri, mode: openInApp ? LaunchMode.platformDefault : LaunchMode.externalApplication);
  } else {
    throw '실행할 수 없는 URL : $url';
  }
}
