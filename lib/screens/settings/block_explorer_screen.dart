import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/block_explorer_service.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BlockExplorerScreen extends StatefulWidget {
  const BlockExplorerScreen({super.key});

  @override
  State<BlockExplorerScreen> createState() => _BlockExplorerScreen();
}

class _BlockExplorerScreen extends State<BlockExplorerScreen> {
  bool _isDefaultExplorerEnabled = true; // 현재 기본 익스플로러 사용 여부
  bool _showCustomUrlTextField = false;
  bool _hasChanges = false;

  bool _initialDefaultExplorerEnabled = true;
  String _initialExplorerUrl = '';

  bool _showConnectionStatus = false;
  bool _showAlertBox = false;
  bool _isConnectionSuccessful = false;
  bool _isConnecting = false;
  Timer? _connectionTimer;

  final GlobalKey _explorerGlobalKey = GlobalKey();
  final TextEditingController _customExplorerController = TextEditingController();
  final FocusNode _customExplorerFocusNode = FocusNode();

  bool get _hasUrlChanged =>
      _customExplorerController.text.isNotEmpty && _customExplorerController.text != _initialExplorerUrl;

  @override
  void initState() {
    super.initState();
    _customExplorerFocusNode.addListener(_onFocusChange);
    _customExplorerController.addListener(_onTextChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _customExplorerController.removeListener(_onTextChanged);
    _customExplorerController.dispose();
    _customExplorerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final useDefault = await BlockExplorerService.getUseDefaultExplorer();
    final explorerUrl = await BlockExplorerService.getExplorerUrl();

    setState(() {
      _isDefaultExplorerEnabled = useDefault;
      _showCustomUrlTextField = !useDefault;
      if (!useDefault) {
        _customExplorerController.text = explorerUrl;
        _showAlertBox = true;
      }

      _initialDefaultExplorerEnabled = useDefault;
      _initialExplorerUrl = explorerUrl;

      _hasChanges = false;
    });
  }

  void _onFocusChange() {
    setState(() {});
  }

  void _onTextChanged() {
    _checkForChanges();
  }

  void _checkForChanges() {
    // default > custom 변경 시 또는 커스텀 url이 변경되었는지 확인
    if (!_isDefaultExplorerEnabled) {
      setState(() {
        _hasChanges = _hasUrlChanged;
      });
    }
    // custom > default 변경 시
    else if (!_initialDefaultExplorerEnabled && _isDefaultExplorerEnabled) {
      setState(() {
        _hasChanges = true;
      });
    } else {
      setState(() {
        _hasChanges = false;
      });
    }
  }

  Future<void> _onDefaultExplorerToggle(bool value) async {
    setState(() {
      _isDefaultExplorerEnabled = value;
      if (value) {
        _showCustomUrlTextField = false;
        _showConnectionStatus = false;
        _showAlertBox = false;
        _customExplorerFocusNode.unfocus();
      } else {
        _showCustomUrlTextField = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _customExplorerFocusNode.requestFocus();
          }
        });
      }
    });

    _checkForChanges();
  }

  Future<bool> _testConnection(String url) async {
    final Dio dio = Dio();

    if (!url.startsWith('http') && !url.startsWith('https')) {
      url = 'https://$url';
    }

    try {
      final response = await dio.get(url);
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveChanges() async {
    if (_isDefaultExplorerEnabled && !_initialDefaultExplorerEnabled) {
      // custom > default 변경시
      await BlockExplorerService.resetToDefault();
      setState(() {
        _hasChanges = false;
        _showConnectionStatus = false;
        _showAlertBox = false;
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _showConnectionStatus = true;
      _isConnectionSuccessful = false;
      _showAlertBox = false;
    });

    try {
      if (_hasUrlChanged) {
        // 저장할 데이터
        final explorerUrl = _customExplorerController.text;
        // 연결 테스트
        final isConnected = await _testConnection(explorerUrl);

        if (isConnected) {
          await BlockExplorerService.setUseDefaultExplorer(_isDefaultExplorerEnabled);
          if (!_isDefaultExplorerEnabled) {
            await BlockExplorerService.setCustomExplorerUrl(explorerUrl);
          }

          _initialDefaultExplorerEnabled = _isDefaultExplorerEnabled;
          _initialExplorerUrl = explorerUrl;

          setState(() {
            _hasChanges = false;
            _isConnectionSuccessful = true;
            _isConnecting = false;
            _showAlertBox = true;
          });

          _clearFocus();

          // 연결 성공 시 상태 표시, 5초 후 연결 상태 숨김
          _connectionTimer?.cancel();
          _connectionTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _showConnectionStatus = false;
              });
            }
          });
        } else {
          setState(() {
            _hasChanges = false;
            _isConnectionSuccessful = false;
            _isConnecting = false;
            _showAlertBox = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isConnectionSuccessful = false;
        _isConnecting = false;
        _showAlertBox = false;
      });
    }
  }

  void _clearFocus() {
    _customExplorerFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
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
            isActive: _hasChanges,
            onButtonClicked: _saveChanges,
            text: t.settings_screen.block_explorer.save,
            backgroundColor: CoconutColors.white,
          ),
        ],
      ),
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
          CoconutSwitch(isOn: _isDefaultExplorerEnabled, onChanged: _onDefaultExplorerToggle),
        ],
      ),
    );
  }

  Widget _buildExplorerAddressTextField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child:
          _showCustomUrlTextField
              ? AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                offset: _showCustomUrlTextField ? Offset.zero : const Offset(0, -0.5),
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
                            setState(() {
                              _customExplorerController.text = '';
                              _showConnectionStatus = false;
                            });
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
    if (!_showConnectionStatus) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 34),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: CoconutColors.gray800),
      child: Row(
        children: [
          if (_isConnecting)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(CoconutColors.white),
              ),
            )
          else if (_isConnectionSuccessful)
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
              _isConnecting
                  ? t.settings_screen.block_explorer.connection_status.connecting
                  : _isConnectionSuccessful
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
    if (!_showAlertBox) {
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
