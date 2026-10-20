import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/common/buttons/button_group.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 도움 받기 시트: 앱 정보 화면의 기존 문의 채널(디스코드·이메일). 공개 채널(X)은 사고 내용을 공개 글로 올리지 않게 뺀다
Future<void> showHelpChannelsSheet(BuildContext context) {
  return CommonBottomSheets.showBottomSheet<void>(
    context: context,
    title: t.safety_guide.help_center.open,
    screenName: '/premium/help',
    showDragHandle: true,
    showCloseButton: true,
    child: const _HelpChannels(),
  );
}

/// 문의 메일 주소. 제목·본문을 따로 인코딩해 기기 이름 등의 '&'·'='가 다른 메일 필드(cc 등)가 되지 않게 한다
@visibleForTesting
String supportMailtoUrl(String subject, String body) =>
    'mailto:$CONTACT_EMAIL_ADDRESS?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';

/// 사건 문의 메일 본문: OS와 앱 버전만. 기기 이름·모델·식별자(identifierForVendor)는 넣지 않는다(앱 정보 화면 메일은 그대로)
@visibleForTesting
String supportMailBody({required String os, required String app, required String build}) =>
    'OS: $os\n'
    'App Version: $app\n'
    'Build Number: $build\n\n'
    '------------------------------------------------------------\n'
    '${t.app_info_screen.inquiry}: \n\n';

Future<String> _deviceInfoBody() async {
  final package = await PackageInfo.fromPlatform();
  final plugin = DeviceInfoPlugin();
  final os =
      Platform.isAndroid
          ? 'Android ${(await plugin.androidInfo).version.release}'
          : Platform.isIOS
          ? 'iOS ${(await plugin.iosInfo).systemVersion}'
          : Platform.operatingSystem;
  return supportMailBody(os: os, app: '${package.appName} ver.${package.version}', build: package.buildNumber);
}

class _HelpChannels extends StatelessWidget {
  const _HelpChannels();

  Widget _logo(String asset) => ClipRRect(
    borderRadius: BorderRadius.circular(8.0),
    child: Image.asset(asset, width: 24, height: 24, fit: BoxFit.cover),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 4 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ButtonGroup(
            buttons: [
              SingleButton(
                key: const Key('help-channel-discord'),
                enableShrinkAnim: true,
                buttonPosition: SingleButtonPosition.top,
                title: t.app_info_screen.ask_to_discord,
                leftElement: _logo('assets/images/discord-full-logo.png'),
                onPressed: () => launchURL(context, DISCORD_COCONUT, destination: ExternalLinkDestination.supportChat),
              ),
              SingleButton(
                key: const Key('help-channel-email'),
                enableShrinkAnim: true,
                buttonPosition: SingleButtonPosition.bottom,
                title: t.app_info_screen.ask_to_email,
                leftElement: _logo('assets/images/mail-icon.png'),
                onPressed: () async {
                  final body = await _deviceInfoBody().catchError((_) => '');
                  if (context.mounted) {
                    launchURL(
                      context,
                      supportMailtoUrl(t.email_subject, body),
                      destination: ExternalLinkDestination.supportEmail,
                    );
                  }
                },
              ),
            ],
          ),
          CoconutLayout.spacing_400h,
          const HelpCenterNeverAsksNote(),
        ],
      ),
    );
  }
}

/// "코코넛은 니모닉·시드·패스프레이즈·개인 키를 절대 묻지 않아요" 한 줄(노출 의심 시트·완료 화면·도움 받기 시트)
class HelpCenterNeverAsksNote extends StatelessWidget {
  const HelpCenterNeverAsksNote({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SvgPicture.asset(
            CommonStateIconPath.shieldWarning,
            width: 14,
            height: 14,
            colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
          ),
        ),
        CoconutLayout.spacing_150w,
        Expanded(
          // 사기 예방 문장은 꼭 읽어야 하므로 코코넛에서도 대비가 서는 secondaryTextStrong(R5)
          child: Text(
            safetyKoText(t.safety_guide.help_center.never_asks),
            style: CoconutTypography.body3_12.setColor(colors.secondaryTextStrong),
          ),
        ),
      ],
    );
  }
}
