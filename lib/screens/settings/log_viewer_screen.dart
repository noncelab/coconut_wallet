import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter_svg/svg.dart';

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
    //
    CustomDialogs.showCustomAlertDialog(context, title: '로그 지우기', message: '로그를 지우시겠어요?',
        onConfirm: () async {
      await FileLogger.clearLog();
      await _loadLogContent();
    }, onCancel: () {
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(
        title: 'Debug Log',
        context: context,
        backgroundColor: CoconutColors.black.withOpacity(0.95),
        actionButtonList: [
          IconButton(
            icon: const Icon(Icons.share, color: CoconutColors.white),
            onPressed: () async {
              await FileLogger.shareLog();
              final Uri params = Uri(
                  scheme: 'mailto',
                  path: CONTACT_EMAIL_ADDRESS,
                  query: 'subject=coconut_wallet_debug_log');

              launchURL(params.toString());
            },
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/svg/trash.svg',
              width: 20,
              colorFilter: const ColorFilter.mode(
                CoconutColors.white,
                BlendMode.srcIn,
              ),
            ),
            onPressed: _clearLog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CoconutCircularIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CoconutColors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '문제가 발생하면 [공유] 버튼을 눌러 로그 복사 후, 이메일로 보내주세요. 공유해주신 정보는 문제 해결을 위해서만 사용되며 문제 해결 즉시 정보는 폐기됩니다. \n\n[로깅 대상]\n1. 키스톤 3 프로 지갑 추가 시 일부 기기에서 문제가 발생함에 따라 이를 확인하기 위해 로깅 중입니다.',
                      style: CoconutTypography.body2_14.setColor(CoconutColors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CoconutColors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SelectableText(
                        _logContent,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: CoconutColors.white,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
