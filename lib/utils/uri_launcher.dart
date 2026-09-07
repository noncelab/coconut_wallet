import 'package:coconut_wallet/analytics/external_link_analytics.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// [openInApp]이 false(기본값)면 외부 브라우저 앱으로, true면 인앱 브라우저
/// (iOS SFSafariViewController 등)로 연다.
///
/// analytics에는 기본적으로 [url]이 그대로 기록된다.
/// 주소·트랜잭션 해시 등 민감 정보가 포함된 URL을 열 때는 반드시 [analyticsUrl]에
/// 민감 정보를 제거한 값을 넘겨야 한다.
Future<void> launchURL(BuildContext context, String url, {bool openInApp = false, String? analyticsUrl}) async {
  Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    if (!context.mounted) return;
    context.read<AnalyticsService>().logExternalLinkOpened(analyticsUrl ?? url);
    await launchUrl(uri, mode: openInApp ? LaunchMode.platformDefault : LaunchMode.externalApplication);
  } else {
    throw '실행할 수 없는 URL : $url';
  }
}
