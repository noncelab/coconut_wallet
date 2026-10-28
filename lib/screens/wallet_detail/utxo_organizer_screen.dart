import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/analytics_screen_observer.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_merge/utxo_merge_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_split_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UtxoOrganizerScreen extends StatefulWidget {
  const UtxoOrganizerScreen({super.key, required this.id});

  final int id;

  @override
  State<UtxoOrganizerScreen> createState() => _UtxoOrganizerScreenState();
}

class _UtxoOrganizerScreenState extends State<UtxoOrganizerScreen> with SelfLoggedScreenView<UtxoOrganizerScreen> {
  late int _selectedIndex = _canMerge(context.read<WalletProvider>()) ? 0 : 1;
  late bool _hasVisitedSplit = _selectedIndex == 1;

  /// 합치기는 쓸 수 있는 UTXO가 둘 이상일 때만 할 수 있다.
  bool _canMerge(WalletProvider wallets) =>
      wallets.getUtxoList(widget.id).where((utxo) => utxo.status == UtxoStatus.unspent).length >= 2;

  @override
  String get analyticsScreenName => AppRouteNames.utxoOrganizer;

  @override
  Map<String, Object> get analyticsParameters => {
    AnalyticsParameterNames.segment:
        (_selectedIndex == 0 ? UtxoOrganizerSegment.merge : UtxoOrganizerSegment.split).name,
  };

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    if (index == 0 && !_canMerge(context.read<WalletProvider>())) return;
    setState(() {
      _selectedIndex = index;
      if (index == 1) _hasVisitedSplit = true;
    });
    logScreenViewIfChanged();
  }

  @override
  Widget build(BuildContext context) {
    final canMerge = context.select<WalletProvider, bool>(_canMerge);
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(
        context: context,
        title: '',
        backgroundColor: context.coconutColors.background,
        customTitle: SizedBox(
          width: 180,
          child: CoconutSegmentedControl(
            isSelected: [_selectedIndex == 0, _selectedIndex == 1],
            onPressed: _selectTab,
            selectedColor: context.coconutColors.segmentedControlSelected,
            segmentedControlContainerColor: context.coconutColors.segmentedControlBackground,
            selectedTextColor: context.coconutColors.segmentedControlSelectedText,
            unselectedTextColor: context.coconutColors.segmentedControlUnselectedText,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            children: [
              Text(
                t.utxo_organizer_screen.merge,
                key: const Key('utxo-organizer-merge-tab'),
                style: canMerge ? null : TextStyle(color: context.coconutColors.mutedText),
              ),
              Text(t.utxo_organizer_screen.split),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          UtxoMergeScreen(id: widget.id, isActive: _selectedIndex == 0),
          if (_hasVisitedSplit)
            UtxoSplitScreen(id: widget.id, isActive: _selectedIndex == 1)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
