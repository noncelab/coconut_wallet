import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutToolTip, CoconutTooltipType, CoconutTooltipState, CoconutToast, CoconutToastLevel, CoconutPopup;
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  String _logContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogContent();
  }

  Future<void> _loadLogContent() async {
    setState(() => _isLoading = true);

    final content = await FileLogger.getLogContent();
    setState(() {
      _logContent = content ?? 'No log content available';
      _isLoading = false;
    });
  }

  Future<void> _clearLog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.settings_screen.log_viewer_screen.clear_log,
          description: t.settings_screen.log_viewer_screen.clear_log_description,
          onTapRight: () async {
            await FileLogger.clearLog();
            await _loadLogContent();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          onTapLeft: () {
            Navigator.of(context).pop();
          },
          rightButtonText: t.confirm,
          leftButtonText: t.cancel,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        title: t.log_viewer,
        context: context,
        backgroundColor: colors.background.withValues(alpha: 0.95),
        actionButtonList: [
          IconButton(
            icon: Icon(Icons.share, color: colors.iconDefault),
            onPressed: () async {
              try {
                final logContent = await FileLogger.getLogContent();
                final logText = logContent ?? 'No log content available';

                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: CONTACT_EMAIL_ADDRESS,
                  query:
                      'subject=${t.settings_screen.log_viewer_screen.email_subject}&body=${t.settings_screen.log_viewer_screen.email_body}\n\n$logText',
                );

                await launchURL(emailUri.toString());
              } catch (e) {
                if (context.mounted) {
                  CoconutToast.showToast(
                    context: context,
                    isVisibleIcon: true,
                    text: t.settings_screen.log_viewer_screen.email_error_msg,
                    seconds: 5,
                  );
                }
              }
            },
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/svg/trash.svg',
              width: 20,
              colorFilter: ColorFilter.mode(colors.iconDefault, BlendMode.srcIn),
            ),
            onPressed: _clearLog,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CoconutCircularIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 로그 설명 표시 영역
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              text: t.settings_screen.log_viewer_screen.log_description_1,
                              style: CoconutTypography.body2_14.setColor(colors.primaryText),
                              children: [
                                TextSpan(
                                  text: ' ${t.settings_screen.log_viewer_screen.log_description_2}',
                                  style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                                ),
                              ],
                            ),
                          ),
                          CoconutLayout.spacing_200h,
                          Text(
                            t.settings_screen.log_viewer_screen.log_target,
                            style: CoconutTypography.body2_14.setColor(colors.primaryText),
                          ),
                          CoconutLayout.spacing_100h,
                          // 로깅 대상 추가 시 여기에 추가
                          _buildLogDescription('1', t.settings_screen.log_viewer_screen.log_target_description_1),
                          CoconutLayout.spacing_100h,
                          _buildLogDescription('2', t.settings_screen.log_viewer_screen.log_target_description_2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildButtons(),
                    const SizedBox(height: 16),

                    // 로그 내용 표시 영역
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(10)),
                        child: SelectableText(
                          _logContent,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: colors.primaryText),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildLogDescription(String index, String description) {
    final colors = context.coconutColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$index. ', style: CoconutTypography.body2_14.setColor(colors.primaryText)),
        Flexible(
          child: Text(
            description,
            style: CoconutTypography.body2_14.setColor(colors.primaryText),
            textAlign: TextAlign.start,
            softWrap: true,
            maxLines: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        _buildButton(t.settings_screen.log_viewer_screen.buttons.discord, () {
          launchURL(DISCORD_COCONUT);
        }),
        CoconutLayout.spacing_100w,
        _buildButton(t.settings_screen.log_viewer_screen.buttons.copy, () {
          Clipboard.setData(ClipboardData(text: _logContent));
          CoconutToast.showToast(
            context: context,
            isVisibleIcon: true,
            text: t.settings_screen.log_viewer_screen.buttons.toast.copy_success,
            seconds: 2,
          );
        }),
      ],
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    final colors = context.coconutColors;

    return Flexible(
      child: CoconutButton(
        backgroundColor: colors.surfaceButton,
        foregroundColor: colors.surfaceButtonText,
        text: text,
        onPressed: onPressed,
      ),
    );
  }
}
