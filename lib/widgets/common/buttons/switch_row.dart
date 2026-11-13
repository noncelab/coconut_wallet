import 'package:coconut_design_system/coconut_design_system.dart' show CoconutSwitch, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/text/keep_words.dart';
import 'package:flutter/material.dart';

/// 카드 안의 켜고 끄는 줄: 제목 + 보조 글 + 스위치.
/// 줄 어디를 눌러도 한 번 바뀌고(누르는 높이 48 이상), 화면 읽기·키보드에서는 줄 하나가 스위치다.
/// 스위치 모양은 앱 설정 줄(위젯 설정 시트 등)과 같은 크기·스위치 색 토큰을 쓴다.
///
/// 의미 상태(제목·보조 글·켜짐·쓸 수 있는지)는 줄 하나가 갖는다. 안쪽 스위치는 그림일 뿐이라
/// 누르기·포커스·의미에서 빼서, 비활성일 때 안쪽 스위치가 따로 활성으로 읽히거나 눌리지 않는다.
class SwitchRow extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final Key? subtitleKey;
  final bool value;

  /// 없으면 바꿀 수 없는 상태로 흐리게 보인다
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
    this.subtitleKey,
    this.switchKey,
  });

  static const minHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final onChanged = this.onChanged;
    final toggle = onChanged == null ? null : () => onChanged(!value);
    final subtitle = this.subtitle;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: subtitle == null ? title : '$title\n$subtitle',
      toggled: value,
      enabled: toggle != null,
      onTap: toggle,
      child: FocusableActionDetector(
        enabled: toggle != null,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              toggle?.call();
              return null;
            },
          ),
        },
        child: Opacity(
          opacity: toggle == null ? 0.4 : 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: toggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minHeight),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          keepWords(title),
                          semanticsLabel: title,
                          style: titleStyle ?? CoconutTypography.body2_14.copyWith(color: colors.primaryText),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            keepWords(subtitle),
                            key: subtitleKey,
                            semanticsLabel: subtitle,
                            style:
                                subtitleStyle ?? CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 그림만: 누르면 줄의 GestureDetector가 받는다(한 번만 바뀜)
                  ExcludeFocus(
                    child: IgnorePointer(
                      child: CoconutSwitch(
                        key: switchKey,
                        isOn: value,
                        scale: 0.7,
                        activeTrackColor: colors.switchActiveTrack,
                        activeThumbColor: colors.switchActiveThumb,
                        inactiveTrackColor: colors.switchInactiveTrack,
                        inactiveThumbColor: colors.switchInactiveThumb,
                        onChanged: (_) => toggle?.call(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
