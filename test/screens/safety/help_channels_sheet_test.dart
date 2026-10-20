import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/screens/safety/help_channels_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // D9: 기기 정보의 '&'·'='·한글이 다른 메일 필드(cc 등)가 되거나 본문을 자르지 않는다
  test('support mail keeps the subject and body as single fields', () {
    const subject = 'Coconut 문의 & 질문';
    const body = 'Name: Alice & Bob\nModel=X1 &cc=someone@example.com\n문의: 안녕하세요';
    final uri = Uri.parse(supportMailtoUrl(subject, body));
    expect(uri.scheme, 'mailto');
    expect(uri.path, CONTACT_EMAIL_ADDRESS);
    expect(uri.queryParameters.keys, unorderedEquals(['subject', 'body']));
    expect(uri.queryParameters['subject'], subject);
    expect(uri.queryParameters['body'], body);
  });

  // 레드팀 §9: 사건 문의 메일에는 기기 이름·식별자·모델을 넣지 않고 OS와 앱 버전만
  test('incident support mail body carries only the OS and app version', () {
    final body = supportMailBody(os: 'iOS 26.1', app: 'Coconut Wallet ver.4.1.0', build: '412');
    expect(body, contains('OS: iOS 26.1'));
    expect(body, contains('App Version: Coconut Wallet ver.4.1.0'));
    expect(body, contains('Build Number: 412'));
    for (final banned in ['Identifier', 'Name:', 'Model', 'Brand', 'Manufacturer']) {
      expect(body, isNot(contains(banned)), reason: banned);
    }
  });
}
