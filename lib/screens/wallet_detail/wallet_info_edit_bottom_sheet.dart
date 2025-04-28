import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_edit_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class WalletInfoEditBottomSheet extends StatefulWidget {
  final int id;
  final WalletImportSource walletImportSource;
  const WalletInfoEditBottomSheet({super.key, required this.id, required this.walletImportSource});

  @override
  State<WalletInfoEditBottomSheet> createState() => _WalletInfoEditBottomSheetState();
}

class _WalletInfoEditBottomSheetState extends State<WalletInfoEditBottomSheet> {
  bool _hasAddedListener = false;
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();

  @override
  void dispose() {
    _textEditingController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _textFieldFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WalletInfoEditViewModel>(
      create: (context) => WalletInfoEditViewModel(
        widget.id,
        Provider.of<WalletProvider>(context, listen: false),
      ),
      child: Consumer<WalletInfoEditViewModel>(
        builder: (context, viewModel, child) {
          if (!_hasAddedListener) {
            _textEditingController.addListener(() {
              _handleInput(context);
            });
            _hasAddedListener = true;
          }

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                CoconutBottomSheet(
                  useIntrinsicHeight: true,
                  appBar: CoconutAppBar.buildWithNext(
                    title: viewModel.walletName,
                    context: context,
                    onBackPressed: () {
                      Navigator.pop(context);
                    },
                    onNextPressed: () {
                      FocusScope.of(context).unfocus();
                      viewModel.changeWalletName(
                        _textEditingController.text,
                        () => Navigator.pop(context, _textEditingController.text.trim()),
                      );
                    },
                    nextButtonTitle: t.complete,
                    isBottom: true,
                    isActive: _textEditingController.text.isNotEmpty &&
                        !viewModel.isNameDuplicated &&
                        !viewModel.isSameAsCurrentName &&
                        !viewModel.isProcessing,
                  ),
                  body: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                          left: 16,
                          right: 16,
                          top: 30),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CoconutLayout.spacing_100w,
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            constraints: const BoxConstraints(
                              minHeight: 40,
                              minWidth: 40,
                            ),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: CoconutColors.gray700,
                            ),
                            padding: const EdgeInsets.all(10),
                            child: SvgPicture.asset(
                              _getExternalWalletIconPath(),
                              colorFilter: const ColorFilter.mode(
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          CoconutLayout.spacing_500w,
                          Expanded(
                            child: CoconutTextField(
                              controller: _textEditingController,
                              focusNode: _textFieldFocusNode,
                              onChanged: (text) {},
                              backgroundColor: CoconutColors.white.withOpacity(0.15),
                              errorColor: CoconutColors.hotPink,
                              placeholderColor: CoconutColors.gray700,
                              activeColor: CoconutColors.white,
                              cursorColor: CoconutColors.white,
                              maxLength: 15,
                              errorText: viewModel.isNameDuplicated || viewModel.isSameAsCurrentName
                                  ? t.wallet_info_screen.duplicated_name
                                  : '',
                              isError: viewModel.isNameDuplicated || viewModel.isSameAsCurrentName,
                              maxLines: 1,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                if (viewModel.isProcessing)
                  Positioned.fill(
                    top: kToolbarHeight,
                    child: Container(
                      color: CoconutColors.black.withOpacity(0.6),
                      alignment: Alignment.center,
                      child: const CoconutCircularIndicator(
                        size: 160,
                      ),
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleInput(BuildContext context) {
    final viewModel = context.read<WalletInfoEditViewModel>();
    viewModel.checkNameValidity(_textEditingController.text);
  }

  String _getExternalWalletIconPath() => widget.walletImportSource == WalletImportSource.keystone
      ? kKeystoneIconPath
      : widget.walletImportSource == WalletImportSource.seedSigner
          ? kSeedSignerIconPath
          : kZpubIconPath;
}
