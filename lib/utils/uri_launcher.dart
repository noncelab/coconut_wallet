import 'package:coconut_wallet/analytics/external_link_analytics.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// [openInApp]이 false(기본값)면 외부 브라우저 앱으로, true면 인앱 브라우저
/// (iOS SFSafariViewController 등)로 연다.
///
/// analytics에는 기본적으로 [url]이 그대로 기록된다.
/// 주소·트랜잭션 해시 등 민감 정보가 포함된 URL을 열 때는 반드시 [analyticsValue]에
/// 민감 정보를 제거한 값을 넘겨야 한다.
///
/// 안전장치: [url]이 현재 설정된 block explorer host를 가리키는데 개발자 실수로
/// [analyticsValue]를 누락한 경우, 여기서 자동으로 sanitized된 값을 계산해 대신 기록한다.
/// (디버그 빌드에서는 assert로도 즉시 알려준다.)
Future<void> launchURL(BuildContext context, String url, {bool openInApp = false, String? analyticsValue}) async {
  Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    if (!context.mounted) return;
    final blockExplorerProvider = context.read<BlockExplorerProvider>();
    assert(
      analyticsValue != null || fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri) == null,
      'block explorer URL을 열 때는 analyticsValue에 sanitized된 값을 반드시 전달해야 합니다: $url',
    );
    final loggedValue = analyticsValue ?? fallbackSanitizedAnalyticsValue(blockExplorerProvider, uri) ?? url;
    context.read<AnalyticsService>().logExternalLinkOpened(loggedValue);
    await launchUrl(uri, mode: openInApp ? LaunchMode.platformDefault : LaunchMode.externalApplication);
  } else {
    throw '실행할 수 없는 URL : $url';
  }
}

/// [uri]가 [blockExplorerProvider]에 설정된 block explorer host를 가리키면, path에서
/// [BlockExplorerPathType]을 추론해 sanitized된 analytics 값을 반환한다. 해당하지 않으면 null.
@visibleForTesting
String? fallbackSanitizedAnalyticsValue(BlockExplorerProvider blockExplorerProvider, Uri uri) {
  final explorerHost = Uri.tryParse(blockExplorerProvider.blockExplorerUrl)?.host;
  if (explorerHost == null || explorerHost.isEmpty || uri.host != explorerHost) return null;

  for (final pathType in BlockExplorerPathType.values) {
    if (uri.pathSegments.contains(pathType.name)) {
      return blockExplorerProvider.sanitizedExplorerAnalyticsDestination(pathType);
    }
  }
  return null;
}
