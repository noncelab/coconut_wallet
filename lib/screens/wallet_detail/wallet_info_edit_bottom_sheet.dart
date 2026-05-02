import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_edit_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/icon/svg_icon.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:coconut_wallet/styles.dart';

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

  bool get _canEditPalette => widget.isCustomAccount && widget.walletImportSource == WalletImportSource.coconutVault;

  @override
  void initState() {
    super.initState();

    final viewModel = context.read<WalletInfoEditViewModel>();
    _initialValue = viewModel.walletName;
    _textEditingController.text = viewModel.walletName;

    if (_canEditPalette) {
      _selectedIconIndex = viewModel.iconIndex;
      _selectedColorIndex = viewModel.colorIndex;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canEditPalette) {
        _textFieldFocusNode.requestFocus();
      }
    });

    _textEditingController.addListener(() {
      context.read<WalletInfoEditViewModel>().checkValidity(
        _textEditingController.text,
        selectedIconIndex: _canEditPalette ? _selectedIconIndex : null,
        selectedColorIndex: _canEditPalette ? _selectedColorIndex : null,
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
        final isCompleteEnabled = !isProcessing && _textEditingController.text.isNotEmpty && canUpdateName;

        final mediaQuery = MediaQuery.of(context);
        final statusBarHeight = mediaQuery.padding.top;
        final androidBottomSystemHeight =
            Theme.of(context).platform == TargetPlatform.android ? mediaQuery.viewPadding.bottom : 0.0;
        final computedMaxBodyHeight = mediaQuery.size.height - statusBarHeight - androidBottomSystemHeight;
        const estimatedHeaderHeight = 108.0; // drag handle + title row + top/bottom paddings
        const bottomSpacing = 16.0;
        final maxAllowedBodyHeight = computedMaxBodyHeight - estimatedHeaderHeight - bottomSpacing - 44;
        final resolvedBodyHeight = _canEditPalette ? maxAllowedBodyHeight.clamp(160.0, double.infinity) : 220.0;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: _canEditPalette ? 0 : mediaQuery.viewInsets.bottom),
              child: SafeArea(
                child: Container(
                  color: CoconutColors.black,
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Center(
                              child: SizedBox(
                                width: 55,
                                height: 4,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: CoconutColors.gray400,
                                    borderRadius: BorderRadius.all(Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap:
                                      isProcessing
                                          ? null
                                          : () {
                                            Navigator.pop(context);
                                          },
                                  child: const Icon(Icons.close_rounded, size: 24, color: CoconutColors.white),
                                ),
                                Expanded(
                                  child: Text(
                                    walletName,
                                    style: Styles.body2Bold.copyWith(color: CoconutColors.white),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 24),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: resolvedBodyHeight,
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: _buildBody(context),
                                ),
                                FixedBottomButton(
                                  backgroundColor: CoconutColors.white,
                                  isVisibleAboveKeyboard: _canEditPalette,
                                  isActive: isCompleteEnabled,
                                  showGradient: true,
                                  bottomPadding: FixedBottomButton.fixedBottomButtonDefaultBottomPadding,
                                  onButtonClicked: () {
                                    if (!isCompleteEnabled) return;
                                    FocusScope.of(context).unfocus();
                                    context.read<WalletInfoEditViewModel>().changeWalletInfo(
                                      _textEditingController.text,
                                      _selectedIconIndex,
                                      _selectedColorIndex,
                                      () => Navigator.pop(context, _textEditingController.text.trim()),
                                    );
                                  },
                                  text: t.done,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isProcessing)
                        Positioned.fill(
                          child: Container(
                            color: CoconutColors.black.withValues(alpha: 0.6),
                            alignment: Alignment.center,
                            child: const CoconutCircularIndicator(size: 160),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
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

        // FixedBottomButton이 위에 올라오기 때문에 본문 쪽에만 스크롤 여유(bottom spacer)를 둡니다.
        const double bottomSpacer =
            FixedBottomButton.fixedBottomButtonDefaultHeight +
            FixedBottomButton.fixedBottomButtonDefaultBottomPadding +
            20;

        return SizedBox(
          height: double.infinity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: bottomSpacer),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildIcon(),
                    CoconutLayout.spacing_400w,
                    Expanded(
                      child: CoconutTextField(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        controller: _textEditingController,
                        focusNode: _textFieldFocusNode,
                        onChanged: (text) {
                          if (_isFirst && _initialValue != text) {
                            _isFirst = false;
                          }
                        },
                        backgroundColor: CoconutColors.white.withValues(alpha: 0.15),
                        errorColor: CoconutColors.hotPink,
                        placeholderText: t.name,
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
                        suffix:
                            _textEditingController.text.isNotEmpty
                                ? IconButton(
                                  iconSize: 14,
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _textEditingController.clear();
                                  },
                                  icon: SvgPicture.asset(
                                    'assets/svg/text-field-clear.svg',
                                    colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                                  ),
                                )
                                : null,
                      ),
                    ),
                  ],
                ),
                if (_canEditPalette) ...[const SizedBox(height: 8), _buildPaletteGrid()],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    final iconColor = _canEditPalette ? ColorUtil.getColor(_selectedColorIndex).backgroundColor : CoconutColors.gray700;
    final iconColorFilter = _canEditPalette ? ColorUtil.getColor(_selectedColorIndex).color : Colors.black;
    final svgPath =
        _canEditPalette
            ? CustomIcons.getPathByIndex(_selectedIconIndex)
            : widget.walletImportSource.externalWalletIconPath;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
      decoration: BoxDecoration(shape: BoxShape.circle, color: iconColor),
      padding: const EdgeInsets.all(10),
      child: SvgPicture.asset(svgPath, colorFilter: ColorFilter.mode(iconColorFilter, BlendMode.srcIn)),
    );
  }

  Widget _buildPaletteGrid() {
    return GridView.builder(
      padding: EdgeInsets.zero,
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
          border: Border.all(color: isSelected ? CoconutColors.white : CoconutColors.black, width: 1.8),
        ),
      ),
    );
  }
}
