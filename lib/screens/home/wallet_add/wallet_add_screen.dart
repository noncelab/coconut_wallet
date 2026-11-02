import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:provider/provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_actions.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/features/wallet/add/wallet_add_options.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 지갑 추가 방법 고르기. 보기 전용(에어갭·연결형)과 핫월렛(새로 만들기·가져오기)
class WalletAddScreen extends StatelessWidget {
  static const routeName = '/wallet-add';
  static const sourcesRouteName = '/wallet-add-sources';

  const WalletAddScreen({super.key});

  /// 지갑이 하나도 없으면 이 화면을 열고, 이미 지갑이 있으면 기존 지갑 추가 탑 시트를 연다.
  static Future<void> openByWalletCount(BuildContext context) {
    if (context.read<WalletProvider>().walletItemList.isEmpty) return open(context);
    return WalletAddDialog.showTopSheet(context, WalletAddDialogMode.walletType);
  }

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(CupertinoPageRoute(settings: const RouteSettings(name: routeName), builder: (_) => const WalletAddScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(context: context, backgroundColor: colors.homeBackground),
      body: SafeArea(
        child: ListView(
          key: const Key('wallet-add-screen'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: const [WalletAddOptions()],
        ),
      ),
    );
  }
}

/// 기기 목록의 한 묶음. [title]이 없으면 제목 없이 보여 준다.
typedef WalletAddSourceSection = ({String? title, List<WalletImportSource> sources});

/// 보기 전용 지갑을 가져올 기기·형식 목록. 에어갭·연결형을 묶음별로 나눠 보여 준다.
class WalletAddSourcesScreen extends StatelessWidget {
  final String title;
  final List<WalletAddSourceSection> sections;

  const WalletAddSourcesScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(context: context, title: title, backgroundColor: colors.homeBackground),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            for (final (index, section) in sections.indexed) ...[
              if (section.title case final sectionTitle?)
                Padding(
                  key: ValueKey('wallet-add-section-$index'),
                  padding: EdgeInsets.fromLTRB(4, index == 0 ? 8 : 24, 4, 8),
                  child: Text(sectionTitle, style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText)),
                ),
              for (final (row, source) in section.sources.indexed) ...[
                if (row > 0) CoconutLayout.spacing_200h,
                _SourceRow(source: source),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final WalletImportSource source;

  const _SourceRow({required this.source});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      key: ValueKey('wallet-add-source-${source.name}'),
      defaultColor: colors.homeSurface,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 14,
      onPressed: () => WalletAddActions.openSource(context, Navigator.of(context), source),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SvgPicture.asset(
              source.externalWalletIconPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_400w,
            Expanded(
              child: Text(source.displayName, style: CoconutTypography.body1_16.copyWith(color: colors.primaryText)),
            ),
            Icon(CupertinoIcons.chevron_right, size: 16, color: colors.primaryText),
          ],
        ),
      ),
    );
  }
}
