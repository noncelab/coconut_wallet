import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

enum TaprootParticipantRole { parent, child }

/// 지갑 카드 내에 서명자 구성, 상속 조건에 사용되는 카드
class TaprootParticipantCard extends StatelessWidget {
  final TaprootParticipantRole role;
  final bool isMine;
  final bool isValid;
  final bool hasSingleParent;
  final bool hasBackgroundColor;
  final bool showRoleWidget;
  final bool showLockStatusIcon;
  final String? walletName;
  final String mfp;
  final String derivationPath;
  final int? locktime;
  final bool useNewline;
  final VoidCallback? onTap;

  const TaprootParticipantCard({
    super.key,
    required this.role,
    this.isMine = false,
    this.isValid = true,
    this.hasSingleParent = false,
    this.hasBackgroundColor = false,
    this.showRoleWidget = true,
    this.showLockStatusIcon = true,
    this.walletName,
    required this.mfp,
    required this.derivationPath,
    this.locktime,
    this.useNewline = false,
    this.onTap,
  });

  TaprootParticipantCard copyWith({
    TaprootParticipantRole? role,
    bool? isMine,
    bool? isValid,
    bool? hasSingleParent,
    bool? hasBackgroundColor,
    bool? showRoleWidget,
    bool? showLockStatusIcon,
    String? walletName,
    String? mfp,
    String? derivationPath,
    int? locktime,
    bool? useNewline,
    VoidCallback? onTap,
  }) {
    return TaprootParticipantCard(
      key: key,
      role: role ?? this.role,
      isMine: isMine ?? this.isMine,
      isValid: isValid ?? this.isValid,
      hasSingleParent: hasSingleParent ?? this.hasSingleParent,
      hasBackgroundColor: hasBackgroundColor ?? this.hasBackgroundColor,
      showRoleWidget: showRoleWidget ?? this.showRoleWidget,
      showLockStatusIcon: showLockStatusIcon ?? this.showLockStatusIcon,
      walletName: walletName ?? this.walletName,
      mfp: mfp ?? this.mfp,
      derivationPath: derivationPath ?? this.derivationPath,
      locktime: locktime ?? this.locktime,
      useNewline: useNewline ?? this.useNewline,
      onTap: onTap ?? this.onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (onTap != null) {
      return ShrinkAnimationButton(onPressed: onTap!, child: _buildCardContainer());
    }

    return _buildCardContainer();
  }

  Widget _buildCardContainer() {
    final style = _style;

    return Container(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: style.border, width: 1),
      ),
      padding: const EdgeInsets.only(top: 18, bottom: 18, left: 16, right: 20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: CoconutColors.gray800, width: 1),
              borderRadius: BorderRadius.circular(8),
              color: CoconutColors.gray100.withValues(alpha: 0.12),
            ),
            padding: const EdgeInsets.all(5),
            child: SvgPicture.asset(style.iconAssetPath, width: 16, height: 16),
          ),
          CoconutLayout.spacing_200w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (locktime != null) ...[
                      Flexible(child: Text(_formattedLocktime, style: CoconutTypography.body3_12)),
                    ] else ...[
                      Text(walletName ?? '', style: CoconutTypography.body3_12_Bold),
                    ],
                    if (_lockStatusIcon != null) ...[CoconutLayout.spacing_200w, _lockStatusIcon!],
                  ],
                ),
                Text('$mfp · $derivationPath', style: CoconutTypography.caption_10.setColor(CoconutColors.gray600)),
              ],
            ),
          ),
          if (showRoleWidget) _roleLabel(style),
        ],
      ),
    );
  }

  _TaprootParticipantCardStyle get _style {
    // 1. isValid가 false 인 경우 우선적으로 error 스타일 적용
    // 2. isMine 여부는 roleLabel에만 영향을 주도록 변경 (카드 전체 스타일에는 영향 X)
    // 3. hasBackgroundColor이 true인 경우에만 배경색과 테두리 색상이 적용
    if (!isValid) {
      return _TaprootParticipantCardStyle(
        background: CoconutColors.hotPink.withValues(alpha: 0.06),
        border: CoconutColors.hotPink.withValues(alpha: 0.5),
        roleBackgroundColor: CoconutColors.hotPink.withValues(alpha: 0.06),
        roleTextColor: CoconutColors.hotPink,
        iconAssetPath: _iconAssetPath,
      );
    }
    if (!hasBackgroundColor || (!isMine && role != TaprootParticipantRole.child)) {
      return _neutralStyle;
    }

    if (role == TaprootParticipantRole.parent) {
      return _TaprootParticipantCardStyle(
        background: hasBackgroundColor ? CoconutColors.purple.withValues(alpha: 0.08) : CoconutColors.white,
        border: hasBackgroundColor ? CoconutColors.purple.withValues(alpha: 0.5) : CoconutColors.gray300,
        roleBackgroundColor: CoconutColors.purple,
        roleTextColor: CoconutColors.white,
        iconAssetPath: _iconAssetPath,
      );
    }
    return _TaprootParticipantCardStyle(
      background: hasBackgroundColor ? CoconutColors.sky.withValues(alpha: 0.08) : CoconutColors.white,
      border: hasBackgroundColor ? CoconutColors.sky.withValues(alpha: 0.5) : CoconutColors.gray300,
      roleBackgroundColor: CoconutColors.sky,
      roleTextColor: CoconutColors.white,
      iconAssetPath: _iconAssetPath,
    );
  }

  _TaprootParticipantCardStyle get _neutralStyle {
    return _TaprootParticipantCardStyle(
      background: CoconutColors.gray800,
      border: CoconutColors.gray800,
      roleBackgroundColor: CoconutColors.gray700,
      roleTextColor: CoconutColors.white,
      iconAssetPath: _iconAssetPath,
    );
  }

  String get _iconAssetPath {
    return switch (role) {
      TaprootParticipantRole.parent => 'assets/svg/parent.svg',
      TaprootParticipantRole.child => 'assets/svg/child.svg',
    };
  }

  SvgPicture? get _lockStatusIcon {
    if (!showLockStatusIcon || role == TaprootParticipantRole.parent || _isLocktimePassed != false) {
      return null;
    }

    return SvgPicture.asset(
      'assets/svg/lock.svg',
      width: 16,
      height: 16,
      colorFilter: const ColorFilter.mode(CoconutColors.sky, BlendMode.srcIn),
    );
  }

  bool? get _isLocktimePassed {
    if (locktime == null) return null;

    final locktimeDate = DateTime.fromMillisecondsSinceEpoch(_toMilliseconds(locktime!));
    return DateTime.now().isAfter(locktimeDate);
  }

  Widget _roleLabel(_TaprootParticipantCardStyle style) {
    final text = _roleText;

    return Container(
      decoration: BoxDecoration(
        color: style.roleBackgroundColor,
        border: Border.all(color: style.border, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(text, style: CoconutTypography.caption_10.setColor(style.roleTextColor)),
    );
  }

  String get _roleText {
    if (isMine) {
      return isValid ? t.taproot.participant_card.me : t.taproot.participant_card.co_signer;
    }
    if (role == TaprootParticipantRole.child) {
      return t.taproot.participant_card.beneficiary;
    }
    return hasSingleParent ? t.taproot.participant_card.signer : t.taproot.participant_card.co_signer;
  }

  String get _formattedLocktime {
    final locktime = this.locktime;
    if (locktime == null) {
      return '';
    }

    final dateTime = DateTime.fromMillisecondsSinceEpoch(_toMilliseconds(locktime));
    final pattern = useNewline ? 'yyyy.MM.dd\nHH:mm' : 'yyyy.MM.dd HH:mm';
    final formattedDateTime = DateFormat(pattern).format(dateTime);

    return t.taproot.participant_card.locktime_after(dateTime: formattedDateTime);
  }

  int _toMilliseconds(int locktime) {
    if (locktime >= 1000000000000) {
      return locktime;
    }
    return locktime * 1000;
  }
}

class _TaprootParticipantCardStyle {
  final Color background;
  final Color border;
  final Color roleBackgroundColor;
  final Color roleTextColor;
  final String iconAssetPath;

  const _TaprootParticipantCardStyle({
    required this.background,
    required this.border,
    required this.roleBackgroundColor,
    required this.roleTextColor,
    required this.iconAssetPath,
  });
}
