import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/preferences/network_preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/block_explorer_view_model.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class BlockExplorerScreen extends StatefulWidget {
  const BlockExplorerScreen({super.key});

  @override
  State<BlockExplorerScreen> createState() => _BlockExplorerScreenState();
}

class _BlockExplorerScreenState extends State<BlockExplorerScreen> {
  late final BlockExplorerViewModel _viewModel;

  final TextEditingController _customExplorerController = TextEditingController();
  final FocusNode _customExplorerFocusNode = FocusNode();
  final GlobalKey _explorerGlobalKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    context.read<PreferenceProvider>();
    final networkPreferenceProvider = context.read<NetworkPreferenceProvider>();
    _viewModel = BlockExplorerViewModel(networkPreferenceProvider);

    _viewModel.addListener(_onViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_viewModel.customExplorerUrl.isNotEmpty) {
        _customExplorerController.text = _viewModel.customExplorerUrl;
      }
    });

    _customExplorerController.addListener(_onTextChanged);
    _customExplorerFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _customExplorerController.dispose();
    _customExplorerFocusNode.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (!_viewModel.isDefaultExplorerEnabled && _customExplorerController.text != _viewModel.customExplorerUrl) {
      if (!_viewModel.hasChanges) {
        _customExplorerController.text = _viewModel.customExplorerUrl;
      }
    }
  }

  void _onTextChanged() {
    _viewModel.onCustomUrlChanged(_customExplorerController.text);
  }

  void _clearFocus() {
    _customExplorerFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Scaffold(
          appBar: CoconutAppBar.build(title: t.block_explorer, context: context),
          body: Stack(
            children: [
              GestureDetector(
                onTap: _clearFocus,
                behavior: HitTestBehavior.translucent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      _buildDefaultExplorerToggle(),
                      _buildExplorerAddressTextField(),
                      _buildConnectionStatus(),
                      _buildCustomExplorerAlertBox(),
                    ],
                  ),
                ),
              ),
              FixedBottomButton(
                isActive: _viewModel.hasChanges,
                onButtonClicked: () async {
                  _clearFocus();
                  await _viewModel.saveChanges();
                },
                text: t.settings_screen.block_explorer.save,
                backgroundColor: CoconutColors.white,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefaultExplorerToggle() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.settings_screen.block_explorer.default_explorer,
                style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray300),
              ),
              Text('Mempool.space', style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
            ],
          ),
          CoconutSwitch(
            isOn: _viewModel.isDefaultExplorerEnabled,
            onChanged: (value) {
              _viewModel.toggleDefaultExplorer(value);

              if (!value) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    _customExplorerFocusNode.requestFocus();
                  }
                });
              } else {
                _clearFocus();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExplorerAddressTextField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child:
          _viewModel.showCustomUrlTextField
              ? AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                offset: _viewModel.showCustomUrlTextField ? Offset.zero : const Offset(0, -0.5),
                child: Padding(
                  padding: const EdgeInsets.only(top: 36),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t.settings_screen.block_explorer.custom_explorer,
                          style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                        ),
                      ),
                      CoconutLayout.spacing_100h,
                      CoconutTextField(
                        key: _explorerGlobalKey,
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        maxLines: 1,
                        textInputType: TextInputType.text,
                        controller: _customExplorerController,
                        focusNode: _customExplorerFocusNode,
                        onChanged: (value) {},
                        placeholderText: t.settings_screen.block_explorer.custom_explorer_input_placeholder,
                        suffix: IconButton(
                          iconSize: 14,
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _customExplorerController.clear();
                            _viewModel.clearCustomUrl();
                          },
                          icon:
                              _customExplorerController.text.isNotEmpty
                                  ? SvgPicture.asset(
                                    'assets/svg/text-field-clear.svg',
                                    colorFilter: ColorFilter.mode(
                                      _customExplorerController.text.isNotEmpty
                                          ? CoconutColors.white
                                          : CoconutColors.gray700,
                                      BlendMode.srcIn,
                                    ),
                                  )
                                  : Container(),
                        ),
                        onEditingComplete: () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _clearFocus();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              )
              : const SizedBox.shrink(),
    );
  }

  Widget _buildConnectionStatus() {
    if (!_viewModel.showConnectionStatus) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 34),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: CoconutColors.gray800),
      child: Row(
        children: [
          if (_viewModel.isConnecting)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(CoconutColors.white),
              ),
            )
          else if (_viewModel.isConnectionSuccessful)
            SvgPicture.asset(
              'assets/svg/circle-check.svg',
              height: 24,
              colorFilter: ColorFilter.mode(CoconutColors.colorPalette[3], BlendMode.srcIn),
            )
          else
            SvgPicture.asset(
              CustomIcons.triangleWarning,
              height: 24,
              colorFilter: const ColorFilter.mode(CoconutColors.hotPink, BlendMode.srcIn),
            ),
          CoconutLayout.spacing_300w,
          Expanded(
            child: Text(
              _viewModel.isConnecting
                  ? t.settings_screen.block_explorer.connection_status.connecting
                  : _viewModel.isConnectionSuccessful
                  ? t.settings_screen.block_explorer.connection_status.connected
                  : t.settings_screen.block_explorer.connection_status.failed,
              style: CoconutTypography.body2_14_Bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomExplorerAlertBox() {
    if (!_viewModel.showAlertBox) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: CoconutColors.gray800),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            'assets/svg/circle-warning.svg',
            height: 24,
            colorFilter: const ColorFilter.mode(CoconutColors.yellow, BlendMode.srcIn),
          ),
          CoconutLayout.spacing_300w,
          Expanded(
            child: Text(
              t.settings_screen.block_explorer.custom_explorer_description,
              style: CoconutTypography.body2_14_Bold,
            ),
          ),
        ],
      ),
    );
  }
}
