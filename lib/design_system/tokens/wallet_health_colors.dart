import 'package:flutter/material.dart';

/// Wallet Health 화면 전용 색. 디자인 시안 값으로 고정한다.
///
/// 테마 토큰(CoconutColors)을 바꾸거나 새 테마를 추가해도 이 값은 따라 바꾸지 않는다.
/// 어떤 테마에서 색이 보이지 않을 때만 그 테마용 값을 따로 지정한다([WalletHealthColors.dark] 참고).
@immutable
class WalletHealthColors {
  const WalletHealthColors({
    required this.gaugeTrack,
    required this.gaugeColors,
    required this.gaugeStops,
    required this.excellent,
    required this.good,
    required this.warning,
    required this.critical,
    required this.warningPillBackground,
    required this.warningPillBorder,
    required this.premiumGradient,
    required this.premiumTitle,
    required this.premiumCheck,
    required this.premiumBody,
    required this.premiumButtonBackground,
    required this.premiumButtonBorder,
    required this.premiumButtonText,
  });

  /// 시안 기준 값(라이트·코코넛 테마)
  static const base = WalletHealthColors(
    gaugeTrack: Color(0xFFF4F4F4),
    gaugeColors: [
      Color(0xFFD6C8E8),
      Color(0xFFE8B9D6),
      Color(0xFFF2B8BE),
      Color(0xFFF6CDB0),
      Color(0xFFF5DDA4),
      Color(0xFFBFE8D0),
      Color(0xFFB4DCEB),
      Color(0xFFAFC6EE),
    ],
    gaugeStops: [0, 0.25, 0.45, 0.55, 0.7, 0.8, 0.9, 1],
    excellent: Color(0xFF0EC2EA),
    good: Color(0xFF16D09C),
    warning: Color(0xFFE9B824),
    critical: Color(0xFFF36769),
    warningPillBackground: Color(0x1FE9B824),
    warningPillBorder: Color(0x52E9B824),
    premiumGradient: [Color(0xFFE8F4FF), Color(0xFFE3DEFD)],
    premiumTitle: Color(0xFF5B12A8),
    premiumCheck: Color(0xFF9A46D8),
    premiumBody: Color(0xFF1E1E1E),
    premiumButtonBackground: Color(0xFFD9C9F7),
    premiumButtonBorder: Color(0xFFC3A3EE),
    premiumButtonText: Color(0xFFA25BE0),
  );

  /// 다크 테마: 밝은 회색 트랙만 어두운 바탕에서 튀어 따로 지정한다
  static final dark = base.copyWith(gaugeTrack: const Color(0xFF2C2C2C));

  /// 게이지 빈 구간
  final Color gaugeTrack;

  /// 게이지 원호 전체에 까는 색과 위치. 0 근처 라벤더에서 조치 필요(분홍)·주의(노랑)·양호(민트)·매우 좋음(하늘)으로 이어서 섞인다
  final List<Color> gaugeColors;
  final List<double> gaugeStops;

  /// 매우 좋음 점수 라벨
  final Color excellent;

  /// 양호: 점수 라벨, 통과 체크 아이콘·값, 카드 "문제 없음"
  final Color good;

  /// 주의: 점수 라벨, ⚠ 아이콘, 확인 버튼 글자, 카드 이슈 문구
  final Color warning;

  /// 조치 필요 점수 라벨
  final Color critical;

  /// 확인 버튼 바탕·테두리
  final Color warningPillBackground;
  final Color warningPillBorder;

  /// Premium 판매 카드. 바탕이 늘 밝은 그라데이션이라 글자색도 테마와 무관하게 고정
  final List<Color> premiumGradient;
  final Color premiumTitle;
  final Color premiumCheck;
  final Color premiumBody;
  final Color premiumButtonBackground;
  final Color premiumButtonBorder;
  final Color premiumButtonText;

  WalletHealthColors copyWith({Color? gaugeTrack}) => WalletHealthColors(
    gaugeTrack: gaugeTrack ?? this.gaugeTrack,
    gaugeColors: gaugeColors,
    gaugeStops: gaugeStops,
    excellent: excellent,
    good: good,
    warning: warning,
    critical: critical,
    warningPillBackground: warningPillBackground,
    warningPillBorder: warningPillBorder,
    premiumGradient: premiumGradient,
    premiumTitle: premiumTitle,
    premiumCheck: premiumCheck,
    premiumBody: premiumBody,
    premiumButtonBackground: premiumButtonBackground,
    premiumButtonBorder: premiumButtonBorder,
    premiumButtonText: premiumButtonText,
  );
}
