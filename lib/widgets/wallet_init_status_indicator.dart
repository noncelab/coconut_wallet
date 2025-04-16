import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

/// Represents the initialization state of a wallet. 처음 초기화 때만 사용하지 않고 refresh 할 때도 사용합니다.
enum WalletInitState {
  /// The wallet has never been initialized.
  never,

  /// The wallet is currently being processed.
  processing,

  /// The wallet has finished successfully.
  finished,

  /// An error occurred during wallet initialization.
  error,

  /// Update impossible (node connection finally failed)
  impossible,
}

// TODO: 더이상 사용하지 않음 확인 후 삭제
class WalletInitStatusIndicator extends StatelessWidget {
  final WalletInitState state;
  final VoidCallback? onTap;
  final bool isLastUpdateTimeVisible;
  final int? lastUpdateTime;

  const WalletInitStatusIndicator(
      {super.key,
      required this.state,
      this.onTap,
      this.isLastUpdateTimeVisible = false,
      this.lastUpdateTime});

  @override
  Widget build(BuildContext context) {
    String iconName = '';
    String text = '';
    Color color = CoconutColors.primary;

    switch (state) {
      case WalletInitState.impossible:
        iconName = 'impossible';
        text = '업데이트 불가';
        color = MyColors.warningRed;
      case WalletInitState.error:
        iconName = 'failure';
        text = '업데이트 실패';
        color = MyColors.failedYellow;
      case WalletInitState.finished:
        iconName = 'complete';
        text = '업데이트 완료';
        color = CoconutColors.primary;
      case WalletInitState.processing:
        iconName = 'loading';
        text = '업데이트 중';
        color = CoconutColors.primary;
      default:
        iconName = 'complete';
        text = '';
        color = Colors.transparent;
    }

    if (isLastUpdateTimeVisible && lastUpdateTime != null && lastUpdateTime != 0) {
      iconName = 'idle';
      text = '마지막 업데이트 ${DateTimeUtil.formatLastUpdateTime(lastUpdateTime!)}';
      color = MyColors.transparentWhite_50;
    }

    return GestureDetector(
      onTap: isLastUpdateTimeVisible && lastUpdateTime != 0 ? onTap : null,
      child: Container(
        padding: const EdgeInsets.only(right: 28, top: 4, bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                fontFamily: CustomFonts.text.getFontFamily,
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.normal,
              ),
            ),
            const SizedBox(width: 8),

            /// Isolate - repository fetch를 메인 스레드에서 실행시 멈춤
            if (state == WalletInitState.processing) ...{
              LottieBuilder.asset(
                'assets/files/status_loading.json',
                width: 20,
              ),
            } else ...{
              SvgPicture.asset('assets/svg/status-$iconName.svg',
                  width: 18, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
            }
          ],
        ),
      ),
    );
  }
}
