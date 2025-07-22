import 'dart:math';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/electrum_server_domain.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/settings/electrum_server_view_model.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
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
  final ScrollController _defaultServerScrollController = ScrollController();
  FocusNode serverAddressFocusNode = FocusNode();
  FocusNode portFocusNode = FocusNode();

  final GlobalKey _defaultServerButtonKey = GlobalKey();
  final GlobalKey _serverAddressFieldKey = GlobalKey();
  Size _defaultServerButtonSize = const Size(0, 0);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      serverAddressFocusNode.addListener(() {
        if (serverAddressFocusNode.hasFocus) {
          context.read<ElectrumServerViewModel>().setDefaultServerMenuVisible(true);
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
    context.read<ElectrumServerViewModel>().setDefaultServerMenuVisible(false);
    _validInputFormat();
  }

  void _validInputFormat() {
    final isDomain = isValidDomain(_serverAddressController.text);
    final isValidPort = int.tryParse(_portController.text);
    final viewModel = context.read<ElectrumServerViewModel>();

    if (isDomain) {
      viewModel.setServerAddressFormatError(false);
    } else {
      viewModel.setServerAddressFormatError(true);
    }

    if (isValidPort != null && isValidPort > 0 && isValidPort <= 65535) {
      viewModel.setPortOutOfRangeError(false);
    } else {
      viewModel.setPortOutOfRangeError(true);
    }
  }

  void _onSave() async {
    final viewModel = context.read<ElectrumServerViewModel>();

    viewModel.setNodeConnectionStatus(NodeConnectionStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    if (Random().nextBool()) {
      viewModel.setNodeConnectionStatus(NodeConnectionStatus.failed);
    } else {
      viewModel.setNodeConnectionStatus(NodeConnectionStatus.connected);
    }
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted || viewModel.nodeConnectionStatus != NodeConnectionStatus.connected) return;
    viewModel.setNodeConnectionStatus(NodeConnectionStatus.waiting);
  }

  bool isValidDomain(String input) {
    final domainRegExp = RegExp(r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z]{2,})+$');
    return domainRegExp.hasMatch(input);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = context.select<ElectrumServerViewModel, bool>(
      (viewModel) => viewModel.nodeConnectionStatus != NodeConnectionStatus.connecting,
    );
    return PopScope(
      canPop: canPop,
      child: GestureDetector(
        onTap: () => _unFocus(),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                ),
                child: Column(
                  children: [
                    _buildServerAddressTextField(),
                    _buildDefaultServerMenu(),
                    Selector<ElectrumServerViewModel, Tuple2<bool, NodeConnectionStatus>>(
                        selector: (_, viewModel) => Tuple2(
                              viewModel.isDefaultServerMenuVisible,
                              viewModel.nodeConnectionStatus,
                            ),
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
                        }),
                  ],
                ),
              ),
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultServerMenu() {
    return Selector<ElectrumServerViewModel, bool>(
      selector: (_, viewModel) => viewModel.isDefaultServerMenuVisible,
      builder: (context, isDefaultServerMenuVisible, child) => isDefaultServerMenuVisible
          ? Container(
              width: MediaQuery.sizeOf(context).width,
              padding: const EdgeInsets.only(
                bottom: 14,
                top: 6,
                right: 6,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  width: 1,
                  color: CoconutColors.gray600,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // 기본 서버 선택 버튼 사이즈 계산
                    if (_defaultServerButtonKey.currentContext != null) {
                      final defaultServerButtonRenderBox =
                          _defaultServerButtonKey.currentContext?.findRenderObject() as RenderBox;
                      setState(() {
                        _defaultServerButtonSize = defaultServerButtonRenderBox.size;
                      });
                    }
                  });

                  final shouldScroll = kDefaultElectrumServers.length > 3;
                  final serverList = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < kDefaultElectrumServers.length; i++) ...[
                        ShrinkAnimationButton(
                          key: i == 0 ? _defaultServerButtonKey : null,
                          defaultColor: CoconutColors.black,
                          pressedColor: CoconutColors.gray850,
                          borderRadius: 12,
                          onPressed: () {
                            _serverAddressController.text = kDefaultElectrumServers[i].address;
                            _portController.text = kDefaultElectrumServers[i].port.toString();
                            _unFocus();
                          },
                          child: Container(
                            width: MediaQuery.sizeOf(context).width,
                            padding: const EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  kDefaultElectrumServers[i].address,
                                  style: CoconutTypography.body3_12,
                                ),
                                Text(
                                  t.settings_screen.electrum_server.ssl_port(
                                    port: kDefaultElectrumServers[i].port,
                                  ),
                                  style: CoconutTypography.body3_12.setColor(
                                    CoconutColors.gray400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );

                  return shouldScroll
                      ? Column(
                          children: [
                            _buildDefaultServerMenuHeader(),
                            SizedBox(
                              height: _defaultServerButtonSize.height * 3,
                              child: Scrollbar(
                                controller: _defaultServerScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _defaultServerScrollController,
                                  child: serverList,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildDefaultServerMenuHeader(),
                            serverList,
                          ],
                        );
                },
              ),
            )
          : Container(),
    );
  }

  Widget _buildDefaultServerMenuHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            t.settings_screen.electrum_server.default_server,
            style: CoconutTypography.body3_12_Bold,
          ),
        ),
        CoconutUnderlinedButton(
          padding: const EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: 8,
          ),
          text: t.close,
          textStyle: CoconutTypography.body3_12,
          onTap: () {
            context.read<ElectrumServerViewModel>().setDefaultServerMenuVisible(false);
          },
        )
      ],
    );
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
                    style: CoconutTypography.body3_12.setColor(
                      CoconutColors.gray400,
                    ),
                  ),
                ),
                CoconutLayout.spacing_100h,
                nodeConnectionStatus == NodeConnectionStatus.connecting
                    ? Container(
                        width: MediaQuery.sizeOf(context).width,
                        height: 54,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: CoconutColors.gray600,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.transparent,
                        ),
                        child: Text(
                          _serverAddressController.text,
                          style: CoconutTypography.body2_14.setColor(
                            CoconutColors.gray600,
                          ),
                        ),
                      )
                    : CoconutTextField(
                        key: _serverAddressFieldKey,
                        controller: _serverAddressController,
                        focusNode: serverAddressFocusNode,
                        textInputAction: TextInputAction.next,
                        onEditingComplete: () {
                          context
                              .read<ElectrumServerViewModel>()
                              .setDefaultServerMenuVisible(false);
                          _validInputFormat();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            FocusScope.of(context).requestFocus(portFocusNode);
                          });
                        },
                        height: 54,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        isError: _serverAddressController.text.isNotEmpty &&
                            context.read<ElectrumServerViewModel>().isServerAddressFormatError,
                        errorText:
                            t.settings_screen.electrum_server.error_msg.invalid_domain_format,
                        textInputFormatter: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                        textInputType: TextInputType.text,
                        suffix: IconButton(
                          iconSize: 14,
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              _serverAddressController.text = '';
                            });
                          },
                          icon: _serverAddressController.text.isNotEmpty
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
                          setState(() {
                            if (context
                                .read<ElectrumServerViewModel>()
                                .isServerAddressFormatError) {
                              context
                                  .read<ElectrumServerViewModel>()
                                  .setServerAddressFormatError(false);
                            }
                          });
                        },
                      ),
              ],
            ),
          );
        });
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
                    style: CoconutTypography.body3_12.setColor(
                      CoconutColors.gray400,
                    ),
                  ),
                ),
                CoconutLayout.spacing_100h,
                nodeConnectionStatus == NodeConnectionStatus.connecting
                    ? Container(
                        width: MediaQuery.sizeOf(context).width,
                        height: 54,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: CoconutColors.gray600,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Text(
                              _portController.text,
                              style: CoconutTypography.body2_14.setColor(
                                CoconutColors.gray600,
                              ),
                            ),
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
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        isError: _portController.text.isNotEmpty &&
                            context.read<ElectrumServerViewModel>().isPortOutOfRangeError,
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
                          icon: _portController.text.isNotEmpty
                              ? SvgPicture.asset(
                                  'assets/svg/text-field-clear.svg',
                                  colorFilter: ColorFilter.mode(
                                    _portController.text.isNotEmpty
                                        ? CoconutColors.white
                                        : CoconutColors.gray700,
                                    BlendMode.srcIn,
                                  ),
                                )
                              : Container(),
                        ),
                        onChanged: (text) {
                          setState(() {
                            if (context.read<ElectrumServerViewModel>().isPortOutOfRangeError) {
                              context.read<ElectrumServerViewModel>().setPortOutOfRangeError(false);
                            }
                          });
                        },
                      ),
              ],
            ),
          );
        });
  }

  Widget _buildSslToggle() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 36,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            t.settings_screen.electrum_server.use_ssl,
            style: CoconutTypography.body3_12.setColor(
              CoconutColors.gray400,
            ),
          ),
          Selector<ElectrumServerViewModel, Tuple2<bool, NodeConnectionStatus>>(
            selector: (_, viewModel) => Tuple2(viewModel.useSsl, viewModel.nodeConnectionStatus),
            builder: (context, data, child) {
              final useSsl = data.item1;
              final isNodeConnecting = data.item2 == NodeConnectionStatus.connecting;
              return IgnorePointer(
                ignoring: isNodeConnecting,
                child: CoconutSwitch(
                  isOn: useSsl,
                  onChanged: (value) => {
                    context.read<ElectrumServerViewModel>().setUseSsl(value),
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
    if (status == NodeConnectionStatus.waiting) return Container();

    return Container(
      margin: const EdgeInsets.only(
        top: 34,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: CoconutColors.gray800,
      ),
      child: Row(
        children: [
          _buildAlertIcon(status),
          CoconutLayout.spacing_300w,
          Text(
            _getAlertString(status),
            style: CoconutTypography.body2_14_Bold,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertIcon(NodeConnectionStatus status) {
    switch (status) {
      case NodeConnectionStatus.unconnected:
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
          return const CupertinoActivityIndicator(
            radius: 10,
          );
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
      case NodeConnectionStatus.unconnected:
        {
          return t.settings_screen.electrum_server.alert
              .connection_failed_to_server(server: 'TODO.com'); // TODO: 도메인
        }
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

  Widget _buildBottomButton() {
    final viewModel = context.read<ElectrumServerViewModel>();
    return Selector<ElectrumServerViewModel, Tuple3<NodeConnectionStatus, bool, bool>>(
        selector: (_, viewModel) => Tuple3(viewModel.nodeConnectionStatus,
            viewModel.isServerAddressFormatError, viewModel.isPortOutOfRangeError),
        builder: (context, data, child) {
          final nodeConnectionStatus = data.item1;
          final isServerAddressFormatError = data.item2;
          final isPortOutOfRangeError = data.item3;
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom <= 40
                    ? 40
                    : MediaQuery.of(context).viewInsets.bottom + 16,
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
                          isActive: nodeConnectionStatus != NodeConnectionStatus.connecting,
                          defaultColor: CoconutColors.white,
                          pressedColor: CoconutColors.gray350,
                          onPressed: () {},
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
                          isActive: _serverAddressController.text.isNotEmpty &&
                              _portController.text.isNotEmpty &&
                              !isServerAddressFormatError &&
                              !isPortOutOfRangeError &&
                              nodeConnectionStatus != NodeConnectionStatus.connecting,
                          defaultColor: CoconutColors.white,
                          pressedColor: CoconutColors.gray350,
                          onPressed: () {
                            _unFocus();

                            if (viewModel.isServerAddressFormatError ||
                                viewModel.isPortOutOfRangeError ||
                                _serverAddressController.text.isEmpty ||
                                _portController.text.isEmpty) return;

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
        });
  }
}

class DefaultServer {
  final String address;
  final int port;

  const DefaultServer({required this.address, required this.port});
}

enum NodeConnectionStatus {
  unconnected, // %s에 연결할 수 없습니다!
  connecting, // 연결 중입니다
  connected, // 연결되었습니다
  failed, // 연결할 수 없습니다!
  waiting, // 대기중
}
