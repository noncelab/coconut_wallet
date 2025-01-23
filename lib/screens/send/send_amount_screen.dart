import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_amount_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/tooltip/custom_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/model/app/send/send_info.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/key_button.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:provider/provider.dart';

class SendAmountScreen extends StatefulWidget {
  const SendAmountScreen({
    super.key,
  });

  @override
  State<SendAmountScreen> createState() => _SendAmountScreenState();
}

class _SendAmountScreenState extends State<SendAmountScreen> {
  final errorMessages = [
    '잔액이 부족해요',
    '${UnitUtil.satoshiToBitcoin(dustLimit + 1)}BTC 부터 전송할 수 있어요'
  ];
  String _input = '';
  int? _errorIndex;
  bool _enableNextButton = false;
  late SendAmountViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = SendAmountViewModel(
        Provider.of<SendInfoProvider>(context, listen: false),
        Provider.of<WalletProvider>(context, listen: false),
        Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn);
  }

  void _onKeyTap(String value) {
    setState(() {
      if (value == '<') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
      } else if (value == '.') {
        if (_input.isEmpty) {
          _input = "0.";
        } else {
          if (!_input.contains('.')) {
            _input += value;
          }
        }
      } else {
        if (_input.isEmpty) {
          // 첫 입력이 0인 경우는 바로 추가
          if (value == '0') {
            _input += value;
          } else if (value != '0' || _input.contains('.')) {
            _input += value;
          }
        } else if (_input == '0' && value != '.') {
          // 첫 입력이 0이고, 그 후 0이 아닌 숫자가 올 경우에는 기존 0을 대체
          _input = value;
        } else if (_input.contains('.')) {
          // 소수점 이후 숫자가 8자리 이하인 경우 추가
          int decimalIndex = _input.indexOf('.');
          if (_input.length - decimalIndex <= 8) {
            _input += value;
          }
        } else {
          // 일반적인 경우 추가
          _input += value;
        }
      }

      if (_input.isNotEmpty && double.parse(_input) > 0) {
        if (double.parse(_input) > _viewModel.confirmedBalance / 1e8) {
          _errorIndex = 0;
          _enableNextButton = false;
        } else if (double.parse(_input) <= dustLimit / 1e8) {
          _errorIndex = 1;
          _enableNextButton = false;
        } else {
          _errorIndex = null;
          _enableNextButton = true;
        }
      } else {
        _errorIndex = null;
        _enableNextButton = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<ConnectivityProvider, WalletProvider,
        SendAmountViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, walletProvider, viewModel) {
        if (connectivityProvider.isNetworkOn != viewModel!.isNetworkOn) {
          viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);
        }
        return viewModel;
      },
      child: Consumer<SendAmountViewModel>(
        builder: (context, viewModel, child) => Scaffold(
            appBar: CustomAppBar.buildWithNext(
              title: '보내기',
              context: context,
              onNextPressed: () {
                // 다음 화면으로 넘어가기 전에 네트워크 상태 확인하기
                if (viewModel.isNetworkOn == false) {
                  CustomToast.showWarningToast(
                      context: context, text: ErrorCodes.networkError.message);
                  return;
                }

                viewModel.setAmount(_input);
                Navigator.pushNamed(context, '/fee-selection');
              },
              isActive: _enableNextButton,
              backgroundColor: MyColors.black,
              isBottom: false,
            ),
            body: Stack(children: [
              Container(
                  color: MyColors.black,
                  child: Column(
                    children: [
                      Expanded(
                          child: Align(
                              alignment: Alignment.center,
                              child: Column(children: [
                                const SizedBox(height: 16),
                                if (viewModel.unconfirmedBalance > 0)
                                  CustomTooltip(
                                      backgroundColor:
                                          MyColors.white.withOpacity(0.9),
                                      richText: RichText(
                                          text: TextSpan(
                                        text:
                                            '받기 완료된 비트코인만 전송 가능해요.\n받는 중인 금액: ${satoshiToBitcoinString(viewModel.unconfirmedBalance)} BTC',
                                        style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.normal,
                                          fontSize: 15,
                                          height: 1.4,
                                          letterSpacing: 0.5,
                                          color: MyColors.black,
                                        ),
                                      )),
                                      showIcon: true,
                                      type: TooltipType.info),
                                Expanded(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // 최대
                                        GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _input =
                                                    UnitUtil.satoshiToBitcoin(
                                                            viewModel
                                                                .confirmedBalance)
                                                        .toStringAsFixed(8);

                                                if (double.parse(_input) <=
                                                    dustLimit / 1e8) {
                                                  _errorIndex = 1;
                                                  _enableNextButton = false;
                                                  return;
                                                }

                                                _errorIndex = null;
                                                _enableNextButton = true;
                                              });
                                            },
                                            child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6.0),
                                                margin: const EdgeInsets.only(
                                                    bottom: 4),
                                                decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                    border: Border.all(
                                                        color: _errorIndex == 0
                                                            ? MyColors
                                                                .warningRed
                                                            : Colors
                                                                .transparent,
                                                        width: 1),
                                                    color: _errorIndex == 0
                                                        ? Colors.transparent
                                                        : MyColors.grey),
                                                child: RichText(
                                                    text: TextSpan(children: [
                                                  TextSpan(
                                                      text: '최대 ',
                                                      style: Styles.caption
                                                          .merge(TextStyle(
                                                              color: _errorIndex ==
                                                                      0
                                                                  ? MyColors
                                                                      .warningRed
                                                                  : MyColors
                                                                      .white,
                                                              fontFamily:
                                                                  CustomFonts
                                                                      .text
                                                                      .getFontFamily))),
                                                  TextSpan(
                                                      text:
                                                          '${UnitUtil.satoshiToBitcoin(viewModel.confirmedBalance)} BTC',
                                                      style: Styles.caption
                                                          .merge(TextStyle(
                                                              color: _errorIndex ==
                                                                      0
                                                                  ? MyColors
                                                                      .warningRed
                                                                  : MyColors
                                                                      .white))),
                                                ])))),
                                        // BTC
                                        Text(
                                          _input.isEmpty
                                              ? '0 BTC'
                                              : "$_input BTC",
                                          style: TextStyle(
                                            fontFamily: CustomFonts
                                                .number.getFontFamily,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 38,
                                            color: _input.isEmpty
                                                ? MyColors.transparentWhite_20
                                                : MyColors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        // Error
                                        Text(
                                          _errorIndex != null
                                              ? errorMessages[_errorIndex!]
                                              : '',
                                          style: Styles.caption.merge(
                                              const TextStyle(
                                                  color: MyColors.warningRed)),
                                        ),

                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: CustomUnderlinedButton(
                                            text: 'UTXO 고르기',
                                            fontSize: 14,
                                            lineHeight: 21,
                                            isEnable: _errorIndex == null &&
                                                _enableNextButton,
                                            onTap: () {
                                              viewModel.setAmount(_input);
                                              // TODO: remove sendInfo
                                              Navigator.pushNamed(
                                                  context, '/utxo-selection',
                                                  arguments: {
                                                    'sendInfo': SendInfo(
                                                        address: '',
                                                        amount: double.parse(
                                                            _input))
                                                  });
                                            },
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                )
                              ]))),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 3,
                          childAspectRatio: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            '1',
                            '2',
                            '3',
                            '4',
                            '5',
                            '6',
                            '7',
                            '8',
                            '9',
                            '.',
                            '0',
                            '<'
                          ].map((key) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: KeyButton(
                                keyValue: key,
                                onKeyTap: _onKeyTap,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  )),
            ])),
      ),
    );
  }
}
