import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/electrum_server_view_model.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class ElectrumServerScreen extends StatefulWidget {
  const ElectrumServerScreen({super.key});

  @override
  State<ElectrumServerScreen> createState() => _ElectrumServerScreen();
}

class _ElectrumServerScreen extends State<ElectrumServerScreen> {
  final TextEditingController _serverAddressController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  bool _currentSslState = false;
  ServerTab _selectedTab = ServerTab.defaultServer;

  final ScrollController _defaultServerScrollController = ScrollController();
  FocusNode serverAddressFocusNode = FocusNode();
  FocusNode portFocusNode = FocusNode();

  final GlobalKey _defaultServerButtonKey = GlobalKey();
  final GlobalKey _serverAddressFieldKey = GlobalKey();
  late final ValueChanged<Size> _onDefaultServerButtonSizeChanged;
  Size _defaultServerButtonSize = const Size(0, 0);

  late ElectrumServerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _onDefaultServerButtonSizeChanged = (Size size) {
      if (size != _defaultServerButtonSize) {
        setState(() {
          _defaultServerButtonSize = size;
        });
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _serverAddressController.text = _viewModel.initialServer.host;
        _portController.text = _viewModel.initialServer.port.toString();
        _currentSslState = _viewModel.initialServer.ssl;
      });

      serverAddressFocusNode.addListener(() {
        if (serverAddressFocusNode.hasFocus) {
          _viewModel.setDefaultServerMenuVisible(true);
        }
      });
    });
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    _portController.dispose();
    serverAddressFocusNode.dispose();
    portFocusNode.dispose();
    super.dispose();
  }

  void _unFocus() {
    FocusScope.of(context).unfocus();
    _viewModel.setDefaultServerMenuVisible(false);
    _validInputFormat();
  }

  void _validInputFormat() {
    _viewModel.validateInputFormat(_serverAddressController.text, _portController.text);
  }

  // 서버 입력 변경 감지
  void _onServerInputChanged() {
    // 서버 정보가 변경되면 waiting 상태로 변경 - 연결 상태 박스 숨김
    _viewModel.setNodeConnectionStatus(NodeConnectionStatus.waiting);
  }

  void _onSave() async {
    final newServer = ElectrumServer.custom(
      _serverAddressController.text,
      int.parse(_portController.text),
      _currentSslState,
    );

    final success = await _viewModel.changeServerAndUpdateState(newServer);

    if (!mounted) return;

    if (success) {
      vibrateLight();
    } else {
      vibrateLightDouble();
    }
  }

  void _onReset() async {
    final initialServer = _viewModel.initialServer;

    _onServerInputChanged(); // 상태 변경 감지

    setState(() {
      // 화면 진입 시의 초기 서버 정보로 초기화
      _serverAddressController.text = initialServer.host;
      _portController.text = initialServer.port.toString();
      _currentSslState = initialServer.ssl;
    });

    final success = await _viewModel.changeServerAndUpdateState(initialServer);

    if (!mounted) return;

    if (success) {
      vibrateLight();
    } else {
      vibrateLightDouble();
    }
  }

  bool isValidDomain(String input) {
    final domainRegExp = RegExp(r'^(?!:\/\/)([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$');
    return domainRegExp.hasMatch(input);
  }

  /// 초기화 버튼 활성화 조건: 현재 입력된 서버 정보가 초기 서버 정보와 다른지 확인
  bool _isDifferentFromInitialServer() {
    return _viewModel.isDifferentFromInitialServer(
      _serverAddressController.text,
      _portController.text,
      _currentSslState,
    );
  }

  /// 저장 버튼 활성화 조건: 현재 입력된 서버 정보가 현재 연결된 서버와 다른지 확인
  bool _hasActualChanges() {
    if (_serverAddressController.text.isEmpty ||
        _portController.text.isEmpty ||
        !_viewModel.isValidDomain(_serverAddressController.text) ||
        !_viewModel.isValidPort(_portController.text))
      return false;

    return !_viewModel.isSameWithCurrentServer(_serverAddressController.text, _portController.text, _currentSslState);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ElectrumServerViewModel>(
      create: (_) {
        _viewModel = ElectrumServerViewModel(
          Provider.of<NodeProvider>(context, listen: false),
          Provider.of<PreferenceProvider>(context, listen: false),
        );
        return _viewModel;
      },
      child: Consumer<ElectrumServerViewModel>(
        builder: (context, viewModel, child) {
          final canPop = viewModel.nodeConnectionStatus != NodeConnectionStatus.connecting;

          return PopScope(
            canPop: canPop,
            child: GestureDetector(
              onTap: _unFocus,
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                backgroundColor: CoconutColors.black,
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: Selector<ElectrumServerViewModel, NodeConnectionStatus>(
                    selector: (_, viewModel) => viewModel.nodeConnectionStatus,
                    builder: (context, nodeConnectionStatus, _) {
                      return CoconutAppBar.build(
                        title: t.electrum_server,
                        context: context,
                        isLeadingVisible: nodeConnectionStatus != NodeConnectionStatus.connecting,
                      );
                    },
                  ),
                ),
                body: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          _buildServerAddressTextField(),
                          _buildDefaultServerMenu(),
                          Selector<ElectrumServerViewModel, Tuple2<bool, NodeConnectionStatus>>(
                            selector:
                                (_, viewModel) =>
                                    Tuple2(viewModel.isDefaultServerMenuVisible, viewModel.nodeConnectionStatus),
                            builder: (context, data, child) {
                              final isDefaultServerMenuVisible = data.item1;
                              final nodeConnectionStatus = data.item2;
                              return isDefaultServerMenuVisible
                                  ? Container()
                                  : Column(
                                    children: [
                                      _buildPortTextField(),
                                      _buildSslToggle(),
                                      _buildAlertBox(nodeConnectionStatus),
                                    ],
                                  );
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildBottomButtons(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDefaultServerMenu() {
    return Selector<ElectrumServerViewModel, bool>(
      selector: (_, viewModel) => viewModel.isDefaultServerMenuVisible,
      builder:
          (context, isDefaultServerMenuVisible, child) =>
              isDefaultServerMenuVisible
                  ? Container(
                    width: MediaQuery.sizeOf(context).width,
                    padding: const EdgeInsets.only(bottom: 14, top: 6, right: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(width: 1, color: CoconutColors.gray600),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          // 기본 서버 선택 버튼 사이즈 계산
                          if (_defaultServerButtonKey.currentContext != null) {
                            final defaultServerButtonRenderBox =
                                _defaultServerButtonKey.currentContext?.findRenderObject() as RenderBox;
                            _onDefaultServerButtonSizeChanged(defaultServerButtonRenderBox.size);
                          }
                        });

                        return Column(children: [_buildServerSelectorHeader(), _buildServerList()]);
                      },
                    ),
                  )
                  : Container(),
    );
  }

  Widget _buildServerSelectorHeader() {
    return Selector<ElectrumServerViewModel, bool>(
      selector: (_, viewModel) => viewModel.hasUserServers,
      builder: (context, hasUserServers, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildHeaderTabButton(
                title: t.settings_screen.electrum_server.default_server,
                isSelected: _selectedTab == ServerTab.defaultServer,
                onTap: () => setState(() => _selectedTab = ServerTab.defaultServer),
              ),
            ),
            if (hasUserServers) ...[
              _buildHeaderTabButton(
                title: t.settings_screen.electrum_server.user_servers,
                isSelected: _selectedTab == ServerTab.userServer,
                onTap: () => setState(() => _selectedTab = ServerTab.userServer),
              ),
            ],
            const Spacer(),
            CoconutUnderlinedButton(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8),
              text: t.close,
              textStyle: CoconutTypography.body3_12,
              onTap: () {
                _viewModel.setDefaultServerMenuVisible(false);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderTabButton({required String title, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(
          title,
          style:
              isSelected
                  ? CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)
                  : CoconutTypography.body2_14.setColor(CoconutColors.gray600),
        ),
      ),
    );
  }

  Widget _buildServerList() {
    return Selector<ElectrumServerViewModel, List<ElectrumServer>>(
      selector:
          (_, viewModel) => _selectedTab == ServerTab.defaultServer ? _getDefaultServerList() : viewModel.userServers,
      builder: (context, serverList, child) {
        if (serverList.isEmpty && _selectedTab == ServerTab.userServer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedTab = ServerTab.defaultServer;
            });
          });
        }

        final shouldScroll = serverList.length > 3;

        final serverListWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < serverList.length; i++) ...[
              ShrinkAnimationButton(
                key: i == 0 ? _defaultServerButtonKey : null,
                defaultColor: CoconutColors.black,
                pressedColor: CoconutColors.gray850,
                borderRadius: 12,
                onPressed: () {
                  _serverAddressController.text = serverList[i].host;
                  _portController.text = serverList[i].port.toString();
                  setState(() {
                    _currentSslState = serverList[i].ssl;
                  });
                  _onServerInputChanged();
                  _unFocus();
                },
                onLongPress:
                    _selectedTab == ServerTab.userServer
                        ? () {
                          final currentServer = _viewModel.currentServer;
                          final serverToDelete = serverList[i];

                          // 현재 구동 중인 서버인지 확인
                          final isCurrentServer =
                              currentServer != null &&
                              currentServer.host == serverToDelete.host &&
                              currentServer.port == serverToDelete.port &&
                              currentServer.ssl == serverToDelete.ssl;

                          // 현재 구동 중인 서버인 경우 삭제 불가
                          if (!isCurrentServer) {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return CoconutPopup(
                                  languageCode: context.read<PreferenceProvider>().language,
                                  title: t.settings_screen.electrum_server.popup.delete_server_info,
                                  description: t.settings_screen.electrum_server.popup.delete_server_info_description,
                                  onTapRight: () async {
                                    final navigator = Navigator.of(context);
                                    await _viewModel.removeUserServer(serverList[i]);
                                    if (!mounted) return;
                                    vibrateLight();
                                    navigator.pop();
                                  },
                                  leftButtonText: t.close,
                                  rightButtonText: t.delete,
                                );
                              },
                            );
                          }
                        }
                        : null,
                child: Selector<ElectrumServerViewModel, NodeConnectionStatus?>(
                  selector: (_, viewModel) => viewModel.connectionStatusMap[serverList[i]],
                  builder: (context, serverConnectionStatus, child) {
                    return Container(
                      width: MediaQuery.sizeOf(context).width,
                      padding: const EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Expanded(child: Text(serverList[i].host, style: CoconutTypography.body2_14))]),
                          Row(
                            children: [
                              Text(
                                t.settings_screen.electrum_server.ssl_port(port: serverList[i].port),
                                style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                              ),
                              if (serverConnectionStatus == NodeConnectionStatus.connecting) ...[
                                CoconutLayout.spacing_100w,
                                const CupertinoActivityIndicator(radius: 6),
                              ],
                              if (serverConnectionStatus == NodeConnectionStatus.connected ||
                                  serverConnectionStatus == NodeConnectionStatus.failed) ...[
                                CoconutLayout.spacing_150w,
                                Container(
                                  width: CoconutTypography.body3_12.fontSize! / 2,
                                  height: CoconutTypography.body3_12.fontSize! / 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        serverConnectionStatus == NodeConnectionStatus.connected
                                            ? CoconutColors.green
                                            : CoconutColors.red,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );

        return shouldScroll
            ? SizedBox(
              height: _defaultServerButtonSize.height * 3,
              child: Scrollbar(
                controller: _defaultServerScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(controller: _defaultServerScrollController, child: serverListWidget),
              ),
            )
            : serverListWidget;
      },
    );
  }

  List<ElectrumServer> _getDefaultServerList() {
    final isRegtestFlavor = NetworkType.currentNetworkType == NetworkType.regtest;
    return isRegtestFlavor ? DefaultElectrumServer.regtestServers : DefaultElectrumServer.mainnetServers;
  }

  Widget _buildServerAddressTextField() {
    return Selector<ElectrumServerViewModel, NodeConnectionStatus>(
      selector: (_, viewModel) => viewModel.nodeConnectionStatus,
      builder: (context, nodeConnectionStatus, child) {
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.settings_screen.electrum_server.server_address,
                  style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                ),
              ),
              CoconutLayout.spacing_100h,
              nodeConnectionStatus == NodeConnectionStatus.connecting
                  ? Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: CoconutColors.gray600),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _serverAddressController.text,
                          style: CoconutTypography.body2_14.setColor(CoconutColors.gray600),
                        ),
                      ],
                    ),
                  )
                  : CoconutTextField(
                    key: _serverAddressFieldKey,
                    controller: _serverAddressController,
                    focusNode: serverAddressFocusNode,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () {
                      _viewModel.setDefaultServerMenuVisible(false);
                      _validInputFormat();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        FocusScope.of(context).requestFocus(portFocusNode);
                      });
                    },
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    isError: _serverAddressController.text.isNotEmpty && _viewModel.isServerAddressFormatError,
                    errorText: t.settings_screen.electrum_server.error_msg.invalid_domain_format,
                    textInputFormatter: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                    textInputType: TextInputType.text,
                    maxLines: 1,
                    suffix: IconButton(
                      iconSize: 14,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _serverAddressController.text = '';
                        });
                      },
                      icon:
                          _serverAddressController.text.isNotEmpty
                              ? SvgPicture.asset(
                                'assets/svg/text-field-clear.svg',
                                colorFilter: ColorFilter.mode(
                                  _serverAddressController.text.isNotEmpty
                                      ? CoconutColors.white
                                      : CoconutColors.gray700,
                                  BlendMode.srcIn,
                                ),
                              )
                              : Container(),
                    ),
                    onChanged: (text) {
                      _onServerInputChanged(); // 입력 변경 감지
                      setState(() {
                        if (_viewModel.isServerAddressFormatError) {
                          _viewModel.setServerAddressFormatError(false);
                        }
                      });
                    },
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortTextField() {
    return Selector<ElectrumServerViewModel, NodeConnectionStatus>(
      selector: (_, viewModel) => viewModel.nodeConnectionStatus,
      builder: (context, nodeConnectionStatus, child) {
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.settings_screen.electrum_server.port,
                  style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                ),
              ),
              CoconutLayout.spacing_100h,
              nodeConnectionStatus == NodeConnectionStatus.connecting
                  ? Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: CoconutColors.gray600),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Text(_portController.text, style: CoconutTypography.body2_14.setColor(CoconutColors.gray600)),
                      ],
                    ),
                  )
                  : CoconutTextField(
                    controller: _portController,
                    focusNode: portFocusNode,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: () {
                      _unFocus();
                    },
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    isError: _portController.text.isNotEmpty && _viewModel.isPortOutOfRangeError,
                    errorText: t.settings_screen.electrum_server.error_msg.port_out_of_range,
                    textInputFormatter: [FilteringTextInputFormatter.digitsOnly],
                    textInputType: TextInputType.number,
                    suffix: IconButton(
                      iconSize: 14,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _portController.text = '';
                        });
                      },
                      icon:
                          _portController.text.isNotEmpty
                              ? SvgPicture.asset(
                                'assets/svg/text-field-clear.svg',
                                colorFilter: ColorFilter.mode(
                                  _portController.text.isNotEmpty ? CoconutColors.white : CoconutColors.gray700,
                                  BlendMode.srcIn,
                                ),
                              )
                              : Container(),
                    ),
                    onChanged: (text) {
                      _onServerInputChanged(); // 입력 변경 감지
                      setState(() {
                        if (_viewModel.isPortOutOfRangeError) {
                          _viewModel.setPortOutOfRangeError(false);
                        }
                      });
                    },
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSslToggle() {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            t.settings_screen.electrum_server.use_ssl,
            style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
          ),
          Selector<ElectrumServerViewModel, NodeConnectionStatus>(
            selector: (_, viewModel) => viewModel.nodeConnectionStatus,
            builder: (context, nodeConnectionStatus, child) {
              final isNodeConnecting = nodeConnectionStatus == NodeConnectionStatus.connecting;
              return IgnorePointer(
                ignoring: isNodeConnecting,
                child: CoconutSwitch(
                  isOn: _currentSslState,
                  onChanged: (value) {
                    if (_currentSslState != value) {
                      vibrateLight(); // 진동 추가
                      setState(() {
                        _currentSslState = value;
                      });
                      _onServerInputChanged();
                    }
                  },
                  activeColor: isNodeConnecting ? CoconutColors.gray500 : null,
                  trackColor: isNodeConnecting ? CoconutColors.gray750 : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBox(NodeConnectionStatus status) {
    // waiting 상태일 때만 알림박스 숨김
    if (status == NodeConnectionStatus.waiting) return Container();

    return Container(
      margin: const EdgeInsets.only(top: 34),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: CoconutColors.gray800),
      child: Row(
        children: [
          _buildAlertIcon(status),
          CoconutLayout.spacing_300w,
          Expanded(child: Text(_getAlertString(status), style: CoconutTypography.body2_14_Bold)),
        ],
      ),
    );
  }

  Widget _buildAlertIcon(NodeConnectionStatus status) {
    switch (status) {
      case NodeConnectionStatus.failed:
        {
          return SvgPicture.asset(
            CustomIcons.triangleWarning,
            height: 20,
            colorFilter: const ColorFilter.mode(CoconutColors.hotPink, BlendMode.srcIn),
          );
        }
      case NodeConnectionStatus.connecting:
        {
          return const CupertinoActivityIndicator(radius: 10);
        }
      case NodeConnectionStatus.connected:
        {
          return SvgPicture.asset(
            'assets/svg/circle-check.svg',
            height: 20,
            colorFilter: ColorFilter.mode(CoconutColors.colorPalette[3], BlendMode.srcIn),
          );
        }
      default:
        {
          return Container();
        }
    }
  }

  String _getAlertString(NodeConnectionStatus status) {
    switch (status) {
      case NodeConnectionStatus.failed:
        {
          return t.settings_screen.electrum_server.alert.connection_failed;
        }
      case NodeConnectionStatus.connecting:
        {
          return t.settings_screen.electrum_server.alert.connecting;
        }
      case NodeConnectionStatus.connected:
        {
          return t.settings_screen.electrum_server.alert.connected;
        }
      default:
        {
          return '';
        }
    }
  }

  Widget _buildBottomButtons() {
    return Selector<ElectrumServerViewModel, NodeConnectionStatus>(
      selector: (_, viewModel) => viewModel.nodeConnectionStatus,
      builder: (context, nodeConnectionStatus, child) {
        // Save 버튼: 실제 변경 여부 확인
        final hasActualChanges = _hasActualChanges();
        debugPrint('hasActualChanges : $hasActualChanges');

        // Reset 버튼: 초기 서버 정보와 다른지 확인
        final isDifferentFromInitial = _isDifferentFromInitialServer();

        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.of(context).viewInsets.bottom <= 40 ? 40 : MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
            ),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width,
              child: Row(
                children: [
                  Flexible(
                    flex: 1,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width,
                      child: ShrinkAnimationButton(
                        isActive: nodeConnectionStatus != NodeConnectionStatus.connecting && isDifferentFromInitial,
                        defaultColor: CoconutColors.white,
                        pressedColor: CoconutColors.gray350,
                        onPressed: _onReset,
                        borderRadius: CoconutStyles.radius_200,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            t.settings_screen.electrum_server.reset,
                            textAlign: TextAlign.center,
                            style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.black),
                          ),
                        ),
                      ),
                    ),
                  ),
                  CoconutLayout.spacing_200w,
                  Flexible(
                    flex: 2,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width,
                      child: ShrinkAnimationButton(
                        isActive: hasActualChanges && nodeConnectionStatus != NodeConnectionStatus.connecting,
                        defaultColor: CoconutColors.white,
                        pressedColor: CoconutColors.gray350,
                        onPressed: () {
                          _unFocus();
                          _onSave();
                        },
                        borderRadius: CoconutStyles.radius_200,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            t.settings_screen.electrum_server.save,
                            textAlign: TextAlign.center,
                            style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.black),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum ServerTab { defaultServer, userServer }

enum NodeConnectionStatus {
  connecting, // 연결 중입니다
  connected, // 연결되었습니다
  failed, // 연결할 수 없습니다!
  waiting, // 대기중
}
