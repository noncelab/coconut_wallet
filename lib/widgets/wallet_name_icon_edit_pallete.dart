import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/icon/svg_icon.dart';
import 'package:coconut_wallet/widgets/icon/wallet_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class WalletNameIconEditPalette extends StatefulWidget {
  final String name;
  final int iconIndex;
  final int colorIndex;
  final Function(String) onNameChanged;
  final Function(int) onIconSelected;
  final Function(int) onColorSelected;
  final Function(bool)? onFocusChanged;

  const WalletNameIconEditPalette({
    super.key,
    required this.onNameChanged,
    required this.onIconSelected,
    required this.onColorSelected,
    this.onFocusChanged,
    this.name = '',
    this.iconIndex = 0,
    this.colorIndex = 0,
  });

  @override
  State<WalletNameIconEditPalette> createState() => _WalletNameIconEditPaletteState();
}

class _WalletNameIconEditPaletteState extends State<WalletNameIconEditPalette> {
  late String _name;
  late int _selectedIconIndex;
  late int _selectedColorIndex;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  int get _colorCount => CoconutColors.colorPalette.length;

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _selectedIconIndex = widget.iconIndex;
    _selectedColorIndex = widget.colorIndex;
    _controller.text = _name;

    _focusNode.addListener(() {
      widget.onFocusChanged?.call(_focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      decoration: const BoxDecoration(color: Colors.white),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CustomScrollView(
              slivers: <Widget>[
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(child: _buildSelectedIconWithName()),
                SliverPadding(
                  padding: EdgeInsets.zero,
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 4.0,
                    ),
                    delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
                      return GestureDetector(
                        onTap: () => _updateSelected(index),
                        child: index < _colorCount ? _buildColorItem(index) : _buildIconItem(index - _colorCount),
                      );
                    }, childCount: _colorCount + CustomIcons.totalCount),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedIconWithName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CoconutLayout.spacing_400w,
            _selectedIconIndex >= 0
                ? Center(
                  child: WalletIcon(
                    walletImportSource: WalletImportSource.coconutVault,
                    iconIndex: _selectedIconIndex,
                    colorIndex: _selectedColorIndex,
                  ),
                )
                : const SizedBox(width: 16),
            CoconutLayout.spacing_200w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CoconutTextField(
                    isLengthVisible: false,
                    placeholderColor: CoconutColors.gray400,
                    placeholderText: t.name,
                    maxLength: 20,
                    maxLines: 1,
                    controller: _controller,
                    focusNode: _focusNode,
                    suffix:
                        _controller.text.isNotEmpty
                            ? IconButton(
                              highlightColor: CoconutColors.gray200,
                              iconSize: 14,
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _controller.clear();
                                setState(() {
                                  _name = '';
                                  widget.onNameChanged('');
                                });
                              },
                              icon: SvgPicture.asset(
                                'assets/svg/text-field-clear.svg',
                                colorFilter: const ColorFilter.mode(CoconutColors.gray400, BlendMode.srcIn),
                              ),
                            )
                            : null,
                    onChanged: (text) {
                      setState(() {
                        _name = text;
                        widget.onNameChanged(text);
                      });
                    },
                  ),
                ],
              ),
            ),
            CoconutLayout.spacing_400w,
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text('${_name.length} / 20', style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500)),
        ),
      ],
    );
  }

  Widget _buildColorItem(int colorIndex) {
    final isSelected = colorIndex == _selectedColorIndex;
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40.0),
            color: CoconutColors.colorPalette[colorIndex],
          ),
        ),
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(11.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40.0),
              border: Border.all(color: isSelected ? CoconutColors.gray800 : CoconutColors.white, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconItem(int iconIndex) {
    final isSelected = iconIndex == _selectedIconIndex;
    return Stack(
      children: [
        Positioned.fill(child: SvgIcon(index: iconIndex)),
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(11.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40.0),
              border: Border.all(color: isSelected ? CoconutColors.gray800 : CoconutColors.white, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  void _updateSelected(int index) {
    if (index < _colorCount) {
      setState(() {
        _selectedColorIndex = index;
        widget.onColorSelected(index);
      });
    } else {
      setState(() {
        _selectedIconIndex = index - _colorCount;
        widget.onIconSelected(_selectedIconIndex);
      });
    }
  }
}
