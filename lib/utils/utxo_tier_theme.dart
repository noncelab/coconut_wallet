import 'package:flutter/material.dart';

enum UtxoTier { dust, tiny, small, medium, large, huge, whole, whale }

@immutable
class TierSwatch {
  final Color bg;
  final Color fg;
  const TierSwatch({required this.bg, required this.fg});
}

class UtxoColorUtils {
  static const Color _black = Color(0xFF111111);
  static const Color _white = Color(0xFFFFFFFF);

  /// WCAG contrast ratio
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final l1 = la > lb ? la : lb;
    final l2 = la > lb ? lb : la;
    return (l1 + 0.05) / (l2 + 0.05);
  }

  /// Choose black/white which gives better contrast on bg.
  static Color bestOn(Color bg) {
    final cBlack = contrastRatio(bg, _black);
    final cWhite = contrastRatio(bg, _white);
    return (cBlack >= cWhite) ? _black : _white;
  }
}

@immutable
class UtxoTierTheme {
  final String id; // 저장용
  final String name; // 표시용
  final Map<UtxoTier, Color> backgrounds;

  /// 특정 tier만 강제로 텍스트 색 지정하고 싶을 때
  final Map<UtxoTier, Color> foregroundOverrides;

  const UtxoTierTheme({
    required this.id,
    required this.name,
    required this.backgrounds,
    this.foregroundOverrides = const {},
  });

  Color bg(UtxoTier tier) => backgrounds[tier]!;
  Color fg(UtxoTier tier) => foregroundOverrides[tier] ?? UtxoColorUtils.bestOn(bg(tier));

  TierSwatch swatch(UtxoTier tier) => TierSwatch(bg: bg(tier), fg: fg(tier));

  /// sats 금액에 해당하는 배경색
  Color colorForSats(int sats) => bg(tierOfSats(sats));
}

// ---- sats -> tier (네 구간 반영, tiny는 547~10,000로 공백 커버) ----
UtxoTier tierOfSats(int sats) {
  if (sats <= 546) return UtxoTier.dust;
  if (sats <= 10_000) return UtxoTier.tiny; // 547~10,000
  if (sats <= 100_000) return UtxoTier.small;
  if (sats <= 1_000_000) return UtxoTier.medium;
  if (sats <= 9_999_999) return UtxoTier.large;
  if (sats <= 99_999_999) return UtxoTier.huge;
  if (sats <= 1_000_000_000) return UtxoTier.whole; // 1~10 BTC
  return UtxoTier.whale; // 10 BTC+
}

class UtxoTierThemes {
  static const pastelWallet = UtxoTierTheme(
    id: 'pastel_wallet',
    name: 'Pastel Wallet',
    backgrounds: {
      UtxoTier.dust: Color(0xFF8E8E8E),
      UtxoTier.tiny: Color(0xFFD9D9D9),
      UtxoTier.small: Color(0xFFD2E6FB),
      UtxoTier.medium: Color(0xFFDAF8E7),
      UtxoTier.large: Color(0xFF98A8D0),
      UtxoTier.huge: Color(0xFFF9DA94),
      UtxoTier.whole: Color(0xFFEBAF5A),
      UtxoTier.whale: Color(0xFFF2D5D2),
    },
  );

  static const slateCitrus = UtxoTierTheme(
    id: 'citrus_slate',
    name: 'Citrus & Slate',
    backgrounds: {
      UtxoTier.dust: Color(0xFF6B7280),
      UtxoTier.tiny: Color(0xFF94A3B8),
      UtxoTier.small: Color(0xFF22D3EE),
      UtxoTier.medium: Color(0xFF14B8A6),
      UtxoTier.large: Color(0xFF22C55E),
      UtxoTier.huge: Color(0xFFA3E635),
      UtxoTier.whole: Color(0xFFF7931A),
      UtxoTier.whale: Color(0xFFC2410C),
    },
  );

  static const monoOrange = UtxoTierTheme(
    id: 'orange_mono',
    name: 'Orange & Mono',
    backgrounds: {
      UtxoTier.dust: Color(0xFF4B5563),
      UtxoTier.tiny: Color(0xFF6B7280),
      UtxoTier.small: Color(0xFF9CA3AF),
      UtxoTier.medium: Color(0xFFD1D5DB),
      UtxoTier.large: Color(0xFFE5E7EB),
      UtxoTier.huge: Color(0xFFFCD34D),
      UtxoTier.whole: Color(0xFFF7931A),
      UtxoTier.whale: Color(0xFFB45309),
    },
  );

  static const earthCopper = UtxoTierTheme(
    id: 'copper_earth',
    name: 'Copper & Earth',
    backgrounds: {
      UtxoTier.dust: Color(0xFF7A6F6A),
      UtxoTier.tiny: Color(0xFFB8A99A),
      UtxoTier.small: Color(0xFFA3BE8C),
      UtxoTier.medium: Color(0xFF88C0D0),
      UtxoTier.large: Color(0xFF5E81AC),
      UtxoTier.huge: Color(0xFFD08770),
      UtxoTier.whole: Color(0xFFF7931A),
      UtxoTier.whale: Color(0xFF8F3F1F),
    },
  );

  static const oceanDepths = UtxoTierTheme(
    id: 'ocean_depths',
    name: 'Ocean Depths',
    backgrounds: {
      UtxoTier.dust: Color(0xFF8A8F98),
      UtxoTier.tiny: Color(0xFFB8C1CC),
      UtxoTier.small: Color(0xFF7DD3FC),
      UtxoTier.medium: Color(0xFF34D399),
      UtxoTier.large: Color(0xFF0EA5E9),
      UtxoTier.huge: Color(0xFF0F766E),
      UtxoTier.whole: Color(0xFFF7931A),
      UtxoTier.whale: Color(0xFF9A3412),
    },
  );

  static const synthwave = UtxoTierTheme(
    id: 'synthwave',
    name: 'Synthwave',
    backgrounds: {
      UtxoTier.dust: Color(0xFF6B7280),
      UtxoTier.tiny: Color(0xFFA78BFA),
      UtxoTier.small: Color(0xFF22D3EE),
      UtxoTier.medium: Color(0xFF34D399),
      UtxoTier.large: Color(0xFFF472B6),
      UtxoTier.huge: Color(0xFFFDE047),
      UtxoTier.whole: Color(0xFFF7931A),
      UtxoTier.whale: Color(0xFFDC2626),
    },
  );

  static const coconut = UtxoTierTheme(
    id: 'coconut',
    name: 'Coconut',
    backgrounds: {
      UtxoTier.dust: Color(0xFF8B8B8B),
      UtxoTier.tiny: Color(0xFFF7F3E9),
      UtxoTier.small: Color(0xFFDFF7F0),
      UtxoTier.medium: Color(0xFFD8C2A2),
      UtxoTier.large: Color(0xFFA36A3A),
      UtxoTier.huge: Color(0xFF5A3A22),
      UtxoTier.whole: Color(0xFF2E8B57),
      UtxoTier.whale: Color(0xFF0F5D3A),
    },
  );

  static const primaryDEFF58 = UtxoTierTheme(
    id: 'primary_deff58',
    name: 'Primary #DEFF58',
    backgrounds: {
      UtxoTier.dust: Color(0xFF6B7280),
      UtxoTier.tiny: Color(0xFF94A3B8),
      UtxoTier.small: Color(0xFF60A5FA),
      UtxoTier.medium: Color(0xFF22D3EE),
      UtxoTier.large: Color(0xFFA78BFA),
      UtxoTier.huge: Color(0xFFFDE047),
      UtxoTier.whole: Color(0xFFDEFF58),
      UtxoTier.whale: Color(0xFF4D7C0F),
    },
  );

  static const vaultWalletCapture = UtxoTierTheme(
    id: 'vault_wallet_capture',
    name: 'Vault/Wallet Capture',
    backgrounds: {
      UtxoTier.dust: Color(0xFF888888),
      UtxoTier.tiny: Color(0xFF4B5A7A),
      UtxoTier.small: Color(0xFFB8DDFE),
      UtxoTier.medium: Color(0xFF9CD2FC),
      UtxoTier.large: Color(0xFF8EAEF8),
      UtxoTier.huge: Color(0xFF86A1FA),
      UtxoTier.whole: Color(0xFF7D88F5),
      UtxoTier.whale: Color(0xFF5F60BE),
    },
  );

  static const monochrome = UtxoTierTheme(
    id: 'monochrome',
    name: 'Monochrome',
    backgrounds: {
      UtxoTier.dust: Color(0xFF374151),
      UtxoTier.tiny: Color(0xFF4B5563),
      UtxoTier.small: Color(0xFF6B7280),
      UtxoTier.medium: Color(0xFF9CA3AF),
      UtxoTier.large: Color(0xFFD1D5DB),
      UtxoTier.huge: Color(0xFFE5E7EB),
      UtxoTier.whole: Color(0xFFF3F4F6),
      UtxoTier.whale: Color(0xFFF9FAFB),
    },
  );

  static const all = <UtxoTierTheme>[
    pastelWallet,
    slateCitrus,
    monoOrange,
    monochrome,
    earthCopper,
    oceanDepths,
    synthwave,
    coconut,
    primaryDEFF58,
    vaultWalletCapture,
  ];

  static UtxoTierTheme fromId(String id) {
    return all.firstWhere((t) => t.id == id, orElse: () => pastelWallet);
  }
}
