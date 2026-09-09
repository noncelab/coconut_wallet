import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_merge/utxo_merge_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_split_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:flutter/material.dart';

class UtxoOrganizerScreen extends StatefulWidget {
  const UtxoOrganizerScreen({super.key, required this.id});

  final int id;

  @override
  State<UtxoOrganizerScreen> createState() => _UtxoOrganizerScreenState();
}

class _UtxoOrganizerScreenState extends State<UtxoOrganizerScreen> {
  int _selectedIndex = 0;
  bool _hasVisitedSplit = false;

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      if (index == 1) _hasVisitedSplit = true;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            children: [Text(t.utxo_organizer_screen.merge), Text(t.utxo_organizer_screen.split)],
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
