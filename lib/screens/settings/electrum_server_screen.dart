import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/settings/electrum_server_view_model.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class ElectrumServerScreen extends StatefulWidget {
  const ElectrumServerScreen({super.key});

  @override
  State<ElectrumServerScreen> createState() => _ElectrumServerScreen();
}

class _ElectrumServerScreen extends State<ElectrumServerScreen> {
  final TextEditingController _serverAddressController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  FocusNode serverAddressFocusNode = FocusNode();
  FocusNode portFocusNode = FocusNode();

  final GlobalKey _bottomButtonKey = GlobalKey();
  Size _bottomButtonSize = const Size(0, 0);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      serverAddressFocusNode.addListener(() {
        if (serverAddressFocusNode.hasFocus) {
          context.read<ElectrumServerViewModel>().setDefaultServerMenuVisible(true);
        }
      });

      // 하단 버튼 사이즈 계산
      if (_bottomButtonKey.currentContext != null) {
        final bottomButtonRenderBox =
            _bottomButtonKey.currentContext?.findRenderObject() as RenderBox;
        setState(() {
          _bottomButtonSize = bottomButtonRenderBox.size;
        });
      }
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

  bool isValidDomain(String input) {
    final domainRegExp = RegExp(r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z]{2,})+$');
    return domainRegExp.hasMatch(input);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _unFocus(),
      child: Scaffold(
        backgroundColor: CoconutColors.black,
        appBar: CoconutAppBar.build(
          title: t.electrum_server,
          context: context,
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
                  Selector<ElectrumServerViewModel, bool>(
                    selector: (_, viewModel) => viewModel.isDefaultServerMenuVisible,
                    builder: (context, isDefaultServerMenuVisible, child) =>
                        isDefaultServerMenuVisible
                            ? Container()
                            : Column(
                                children: [
                                  _buildPortTextField(),
                                  _buildSslToggle(),
                                ],
                              ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                  key: _bottomButtonKey,
                  padding: const EdgeInsets.only(
                    bottom: 16,
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
                              defaultColor: CoconutColors.white,
                              pressedColor: CoconutColors.gray350,
                              onPressed: () {},
                              borderRadius: CoconutStyles.radius_200,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  t.settings_screen.electrum_server.reset,
                                  textAlign: TextAlign.center,
                                  style:
                                      CoconutTypography.body2_14_Bold.setColor(CoconutColors.black),
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
                              defaultColor: CoconutColors.white,
                              pressedColor: CoconutColors.gray350,
                              onPressed: () {},
                              borderRadius: CoconutStyles.radius_200,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  t.settings_screen.electrum_server.save,
                                  textAlign: TextAlign.center,
                                  style:
                                      CoconutTypography.body2_14_Bold.setColor(CoconutColors.black),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            )
          ],
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
              child: Column(
                children: [
                  Row(
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
                          context
                              .read<ElectrumServerViewModel>()
                              .setDefaultServerMenuVisible(false);
                        },
                      )
                    ],
                  ),
                  for (DefaultServer server in tempDefaultServers) ...[
                    ShrinkAnimationButton(
                      defaultColor: CoconutColors.black,
                      pressedColor: CoconutColors.gray850,
                      borderRadius: 12,
                      onPressed: () {
                        setState(() {
                          _serverAddressController.text = server.address;
                          _portController.text = server.port.toString();
                          _unFocus();
                        });
                      },
                      child: Container(
                        width: MediaQuery.sizeOf(context).width,
                        padding: const EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              server.address,
                              style: CoconutTypography.body3_12,
                            ),
                            Text(
                              t.settings_screen.electrum_server.ssl_port(
                                port: server.port,
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
              ),
            )
          : Container(),
    );
  }

  Widget _buildServerAddressTextField() {
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
          CoconutTextField(
            controller: _serverAddressController,
            focusNode: serverAddressFocusNode,
            textInputAction: TextInputAction.done,
            height: 54,
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            isError: _serverAddressController.text.isNotEmpty &&
                context.read<ElectrumServerViewModel>().isServerAddressFormatError,
            errorText: t.settings_screen.electrum_server.error_msg.invalid_domain_format,
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
                if (context.read<ElectrumServerViewModel>().isServerAddressFormatError) {
                  context.read<ElectrumServerViewModel>().setServerAddressFormatError(false);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPortTextField() {
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
          CoconutTextField(
            controller: _portController,
            focusNode: portFocusNode,
            textInputAction: TextInputAction.done,
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
          Selector<ElectrumServerViewModel, bool>(
            selector: (_, viewModel) => viewModel.useSsl,
            builder: (context, value, child) {
              return CoconutSwitch(
                isOn: value,
                onChanged: (value) => {
                  context.read<ElectrumServerViewModel>().setUseSsl(value),
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

const tempDefaultServers = [
  // TODO: 실제 기본 서버 배정, const 변수 위치 이동
  DefaultServer(address: 'mainnet.foundationdevices.com', port: 5002),
  DefaultServer(address: 'electrum1.bluewallet.io', port: 443),
  DefaultServer(address: 'electrum.acinq.co', port: 50002),
];

class DefaultServer {
  final String address;
  final int port;

  const DefaultServer({required this.address, required this.port});
}
