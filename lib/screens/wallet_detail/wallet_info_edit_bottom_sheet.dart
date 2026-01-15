import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_edit_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class WalletInfoEditBottomSheet extends StatelessWidget {
  final int id;
  final WalletImportSource walletImportSource;
  const WalletInfoEditBottomSheet({super.key, required this.id, required this.walletImportSource});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WalletInfoEditViewModel>(
      create: (context) => WalletInfoEditViewModel(id, Provider.of<WalletProvider>(context, listen: false)),
      child: _WalletInfoEditBottomSheetContent(id: id, walletImportSource: walletImportSource),
    );
  }
}

class _WalletInfoEditBottomSheetContent extends StatefulWidget {
  final int id;
  final WalletImportSource walletImportSource;

  const _WalletInfoEditBottomSheetContent({required this.id, required this.walletImportSource});

  @override
  State<_WalletInfoEditBottomSheetContent> createState() => _WalletInfoEditBottomSheetState();
}

class _WalletInfoEditBottomSheetState extends State<_WalletInfoEditBottomSheetContent> {
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  bool _isFirst = true;
  String _initialValue = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<WalletInfoEditViewModel>();
      _initialValue = viewModel.walletName;
      _textEditingController.text = viewModel.walletName;
      _textFieldFocusNode.requestFocus();
    });

    _textEditingController.addListener(() {
      context.read<WalletInfoEditViewModel>().checkNameValidity(_textEditingController.text);
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
                useIntrinsicHeight: true,
                appBar: CoconutAppBar.buildWithNext(
                  title: walletName,
                  context: context,
                  onBackPressed: () {
                    Navigator.pop(context);
                  },
                  onNextPressed: () {
                    FocusScope.of(context).unfocus();
                    context.read<WalletInfoEditViewModel>().changeWalletName(
                      _textEditingController.text,
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
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 30),
            child: Row(
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
                    maxLength: 15,
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
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: CoconutColors.gray700),
      padding: const EdgeInsets.all(10),
      child: SvgPicture.asset(
        widget.walletImportSource.externalWalletIconPath,
        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
      ),
    );
  }
}
