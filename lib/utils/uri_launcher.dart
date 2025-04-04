import 'package:url_launcher/url_launcher.dart';

Future<void> launchURL(String url, {bool defaultMode = false}) async {
  Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri,
        mode: !defaultMode ? LaunchMode.externalApplication : LaunchMode.platformDefault);
  } else {
    throw '실행할 수 없는 URL : $url';
  }
}
