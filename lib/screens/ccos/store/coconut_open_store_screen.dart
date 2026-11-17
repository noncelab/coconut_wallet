import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutToast;
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_navigation.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ccos_store_view_model.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_feature_card.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart' show CoconutToast;
import 'package:coconut_wallet/widgets/features/ccos/card/coconut_open_store_intro_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_scope.dart';

class CoconutOpenStoreScreen extends StatelessWidget {
  const CoconutOpenStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (context) =>
              CcosStoreViewModel(context.read<PreferenceProvider>(), arkProvider: context.readArkProviderOrNull()),
      child: const CcosStoreScope(child: _CoconutOpenStoreView()),
    );
  }
}

class _CoconutOpenStoreView extends StatefulWidget {
  const _CoconutOpenStoreView();

  @override
  State<_CoconutOpenStoreView> createState() => _CoconutOpenStoreViewState();
}

class _CoconutOpenStoreViewState extends State<_CoconutOpenStoreView> {
  Future<void> _add(CcosStoreViewModel viewModel, CcosFeatureListing listing) async {
    await viewModel.add(listing.id);
    if (!mounted) return;
    CoconutToast.showToast(context: context, text: t.ccos.store.added_toast, isVisibleIcon: true);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CcosStoreViewModel>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CoconutAppBar.build(context: context, title: t.ccos.store.title, isBottom: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _buildHeader(context),
          for (final listing in viewModel.listings) ...[
            CoconutLayout.spacing_400h,
            CcosStoreFeatureCard(
              listing: listing,
              state: viewModel.stateOf(listing.id),
              onTap: () => openCoconutOpenStoreFeature(context, listing.id),
              onAdd: () => _add(viewModel, listing),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      child: GestureDetector(
        onTap: () => openCoconutOpenStoreIntroScreen(context),
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              const Positioned.fill(child: CoconutOpenStoreCosmicBackground()),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      BrandIconPath.coconutPlanet,
                      width: 48,
                      height: 48,
                      colorFilter: const ColorFilter.mode(CoconutOpenStoreCosmicBackground.iconColor, BlendMode.srcIn),
                    ),
                    CoconutLayout.spacing_400w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.ccos.store.header_title,
                            style: CoconutTypography.body1_16_Bold.setColor(
                              CoconutOpenStoreCosmicBackground.primaryTextColor,
                            ),
                          ),
                          CoconutLayout.spacing_100h,
                          Text(
                            t.ccos.store.header_subtitle,
                            style: CoconutTypography.body3_12.setColor(
                              CoconutOpenStoreCosmicBackground.secondaryTextColor,
                            ),
                          ),
                          CoconutLayout.spacing_200h,
                          Text(
                            '${t.ccos.store.what_is} ›',
                            style: CoconutTypography.body3_12_Bold.setColor(
                              CoconutOpenStoreCosmicBackground.primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
