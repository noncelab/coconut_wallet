import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_edit_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/icon/svg_icon.dart';
import 'package:coconut_wallet/widgets/icon/wallet_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class WalletInfoEditBottomSheet extends StatelessWidget {
  final int id;
  final WalletImportSource walletImportSource;
  final bool isCustomAccount;
  const WalletInfoEditBottomSheet({
    super.key,
    required this.id,
    required this.walletImportSource,
    required this.isCustomAccount,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WalletInfoEditViewModel>(
      create: (context) => WalletInfoEditViewModel(id, Provider.of<WalletProvider>(context, listen: false)),
      child: _WalletInfoEditBottomSheetContent(
        id: id,
        walletImportSource: walletImportSource,
        isCustomAccount: isCustomAccount,
      ),
    );
  }
}

class _WalletInfoEditBottomSheetContent extends StatefulWidget {
  final int id;
  final WalletImportSource walletImportSource;
  final bool isCustomAccount;

  const _WalletInfoEditBottomSheetContent({
    required this.id,
    required this.walletImportSource,
    required this.isCustomAccount,
  });

  @override
  State<_WalletInfoEditBottomSheetContent> createState() => _WalletInfoEditBottomSheetState();
}

class _WalletInfoEditBottomSheetState extends State<_WalletInfoEditBottomSheetContent> {
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  bool _isFirst = true;
  String _initialValue = '';

  int _selectedIconIndex = 0;
  int _selectedColorIndex = 0;

  int get _colorCount => CoconutColors.colorPalette.length;

  @override
  void initState() {
    super.initState();

    final viewModel = context.read<WalletInfoEditViewModel>();
    _initialValue = viewModel.walletName;
    _textEditingController.text = viewModel.walletName;

    if (widget.isCustomAccount) {
      _selectedIconIndex = viewModel.iconIndex;
      _selectedColorIndex = viewModel.colorIndex;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isCustomAccount) {
        _textFieldFocusNode.requestFocus();
      }
    });

    _textEditingController.addListener(() {
      context.read<WalletInfoEditViewModel>().checkValidity(
        _textEditingController.text,
        selectedIconIndex: widget.isCustomAccount ? _selectedIconIndex : null,
        selectedColorIndex: widget.isCustomAccount ? _selectedColorIndex : null,
      );
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<WalletInfoEditViewModel, Tuple3<bool, bool, String>>(
      selector: (_, viewModel) => Tuple3(viewModel.canUpdateName, viewModel.isProcessing, viewModel.walletName),
      builder: (context, data, child) {
        final canUpdateName = data.item1;
        final isProcessing = data.item2;
        final walletName = data.item3;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              CoconutBottomSheet(
                useIntrinsicHeight: !widget.isCustomAccount,
                heightRatio: widget.isCustomAccount ? 0.9 : 0.95,
                appBar: CoconutAppBar.buildWithNext(
                  title: walletName,
                  context: context,
                  onBackPressed: () {
                    Navigator.pop(context);
                  },
                  onNextPressed: () {
                    FocusScope.of(context).unfocus();
                    context.read<WalletInfoEditViewModel>().changeWalletInfo(
                      _textEditingController.text,
                      _selectedIconIndex,
                      _selectedColorIndex,
                      () => Navigator.pop(context, _textEditingController.text.trim()),
                    );
                  },
                  nextButtonTitle: t.complete,
                  isBottom: true,
                  isActive: _textEditingController.text.isNotEmpty && canUpdateName,
                ),
                body: _buildBody(context),
              ),
              if (isProcessing)
                Positioned.fill(
                  top: kToolbarHeight,
                  child: Container(
                    color: CoconutColors.black.withValues(alpha: 0.6),
                    alignment: Alignment.center,
                    child: const CoconutCircularIndicator(size: 160),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return Selector<WalletInfoEditViewModel, Tuple2<bool, bool>>(
      selector: (_, viewModel) => Tuple2(viewModel.isNameDuplicated, viewModel.isSameAsCurrentName),
      builder: (context, data, child) {
        final isNameDuplicated = data.item1;
        final isSameAsCurrentName = data.item2;
        final isError = isSameAsCurrentName || isNameDuplicated;
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CoconutLayout.spacing_100w,
                      _buildIcon(),
                      CoconutLayout.spacing_500w,
                      Expanded(
                        child: CoconutTextField(
                          controller: _textEditingController,
                          focusNode: _textFieldFocusNode,
                          onChanged: (text) {
                            if (_isFirst && _initialValue != text) {
                              _isFirst = false;
                            }
                          },
                          backgroundColor: CoconutColors.white.withValues(alpha: 0.15),
                          errorColor: CoconutColors.hotPink,
                          placeholderColor: CoconutColors.gray700,
                          activeColor: CoconutColors.white,
                          cursorColor: CoconutColors.white,
                          maxLength: 20,
                          errorText:
                              _isFirst
                                  ? ''
                                  : isError
                                  ? t.wallet_info_screen.duplicated_name
                                  : '',
                          isError: _isFirst ? false : isError,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  if (widget.isCustomAccount) ...[const SizedBox(height: 24), _buildPaletteGrid()],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isCustomAccount ? CoconutColors.black : CoconutColors.gray700,
      ),
      padding: const EdgeInsets.all(10),
      child:
          widget.isCustomAccount
              ? WalletIcon(
                walletImportSource: WalletImportSource.coconutVault,
                iconIndex: _selectedIconIndex,
                colorIndex: _selectedColorIndex,
              )
              : SvgPicture.asset(
                widget.walletImportSource.externalWalletIconPath,
                colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              ),
    );
  }

  Widget _buildPaletteGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 4.0),
      itemCount: _colorCount + CustomIcons.totalCount,
      itemBuilder: (context, index) {
        final isColorItem = index < _colorCount;

        return GestureDetector(
          onTap: () => _handleItemTap(index, isColorItem),
          child: isColorItem ? _buildColorPaletteItem(index) : _buildIconPaletteItem(index - _colorCount),
        );
      },
    );
  }

  void _handleItemTap(int index, bool isColorItem) {
    setState(() {
      if (isColorItem) {
        _selectedColorIndex = index;
      } else {
        _selectedIconIndex = index - _colorCount;
      }
    });

    context.read<WalletInfoEditViewModel>().checkValidity(
      _textEditingController.text,
      selectedIconIndex: _selectedIconIndex,
      selectedColorIndex: _selectedColorIndex,
    );
  }

  Widget _buildColorPaletteItem(int colorIndex) {
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
        _buildSelectionBorder(isSelected),
      ],
    );
  }

  Widget _buildIconPaletteItem(int iconIndex) {
    final isSelected = iconIndex == _selectedIconIndex;

    return Stack(children: [Positioned.fill(child: SvgIcon(index: iconIndex)), _buildSelectionBorder(isSelected)]);
  }

  Widget _buildSelectionBorder(bool isSelected) {
    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.all(11.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40.0),
          border: Border.all(color: isSelected ? CoconutColors.gray500 : CoconutColors.black, width: 1.8),
        ),
      ),
    );
  }
}
