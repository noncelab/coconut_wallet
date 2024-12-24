import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/screens/bottomsheet/tag_bottom_sheet_container.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_chip.dart';
import 'package:coconut_wallet/widgets/highlighted_Info_area.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/model/utxo.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/label_value.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UtxoDetailScreen extends StatefulWidget {
  final UTXO utxo;

  const UtxoDetailScreen({
    super.key,
    required this.utxo,
  });

  @override
  State<UtxoDetailScreen> createState() => _UtxoDetailScreenState();
}

class _UtxoDetailScreenState extends State<UtxoDetailScreen> {
  late List<String> _dateString;
  late bool _isUtxoTooltipVisible;

  final GlobalKey _utxoTooltipIconKey = GlobalKey();
  late RenderBox _utxoTooltipIconRenderBox;
  late Size _utxoTooltipIconSize;
  late Offset _utxoTooltipIconPosition;

  final String _utxoTip =
      'UTXO란 Unspent Tx Output을 줄인 말로\n아직 쓰이지 않은 잔액이란 뜻이에요. 비트코인에는 잔액 개념이 없어요.\n지갑에 표시되는 잔액은 UTXO의 총합이라는 것을 알아두세요.';

  @override
  void initState() {
    super.initState();
    _dateString = DateTimeUtil.formatDatetime(widget.utxo.timestamp).split('|');
    _isUtxoTooltipVisible = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _utxoTooltipIconRenderBox =
          _utxoTooltipIconKey.currentContext?.findRenderObject() as RenderBox;
      _utxoTooltipIconPosition =
          _utxoTooltipIconRenderBox.localToGlobal(Offset.zero);
      _utxoTooltipIconSize = _utxoTooltipIconRenderBox.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _removeUtxoTooltip();
      },
      child: GestureDetector(
        onTap: () => _removeUtxoTooltip(),
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: MyColors.black,
              appBar: CustomAppBar.build(
                title: 'UTXO',
                context: context,
                showTestnetLabel: false,
                hasRightIcon: true,
                rightIconButton: IconButton(
                  key: _utxoTooltipIconKey,
                  icon: SvgPicture.asset('assets/svg/question-mark.svg'),
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _isUtxoTooltipVisible = !_isUtxoTooltipVisible;
                      });
                    }
                  },
                ),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        HighlightedInfoArea(
                          textList: _dateString,
                          textStyle: Styles.body2Number.merge(
                            const TextStyle(
                              color: MyColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 24,
                        ),
                        Center(
                            child: RichText(
                                text: TextSpan(
                                    text: satoshiToBitcoinString(
                                        widget.utxo.amount),
                                    style: Styles.h1Number.merge(
                                        const TextStyle(
                                            fontSize: 24, height: 1)),
                                    children: const <TextSpan>[
                              TextSpan(text: ' BTC', style: Styles.body2)
                            ]))),
                        const SizedBox(
                          height: 8,
                        ),
                        Center(
                            child: Selector<UpbitConnectModel, int?>(
                          selector: (context, model) => model.bitcoinPriceKrw,
                          builder: (context, bitcoinPriceKrw, child) {
                            return Text(
                              bitcoinPriceKrw != null
                                  ? '₩ ${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(widget.utxo.amount, bitcoinPriceKrw).toDouble())}'
                                  : '',
                              style: Styles.balance2,
                            );
                          },
                        )),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: MyColors.transparentWhite_12),
                          child: Column(children: [
                            const InputOutputDetailRow(
                              address: 'bcrtTestDataTestDataTestDataTestData',
                              balance: 4001234,
                              rowType: InputOutputRowType.input,
                            ),
                            const SizedBox(height: 8),
                            const InputOutputDetailRow(
                              address: 'bcrtTestDataTestDataTestDataTestData',
                              balance: 4001234,
                              rowType: InputOutputRowType.input,
                            ),
                            const SizedBox(height: 8),
                            const InputOutputDetailRow(
                              address: 'bcrtTestDataTestDataTestDataTestData',
                              balance: 4001234,
                              rowType: InputOutputRowType.input,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '...',
                              style: Styles.caption.merge(const TextStyle(
                                  color: MyColors.transparentWhite_40,
                                  height: 8 / 12)),
                            ),
                            const SizedBox(height: 8),
                            const InputOutputDetailRow(
                              address: '수수료',
                              balance: 142,
                              rowType: InputOutputRowType.fee,
                            ),
                            const SizedBox(height: 8),
                            const InputOutputDetailRow(
                              address: 'bcrtTestDataTestDataTestDataTestData',
                              balance: 4001234,
                              rowType: InputOutputRowType.output,
                              isCurrentAddress: true,
                            ),
                            const SizedBox(height: 8),
                            const InputOutputDetailRow(
                              address:
                                  'bcrtTestDataTestDataTestDataTestDataTestData',
                              balance: 4001234,
                              rowType: InputOutputRowType.output,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '...',
                              style: Styles.caption.merge(const TextStyle(
                                  color: MyColors.transparentWhite_40,
                                  height: 8 / 12)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 25),
                        InfoRow(
                            label: '보유 주소',
                            subLabel: '멤풀 보기',
                            onSubLabelClicked: () => launchUrl(Uri.parse(
                                "${PowWalletApp.kMempoolHost}/address/${widget.utxo.to}")),
                            isChangeTagVisible:
                                widget.utxo.derivationPath.split('/')[4] == '1',
                            value: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.utxo.to,
                                  style: Styles.body2Number
                                      .merge(const TextStyle(height: 22 / 14)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.utxo.derivationPath,
                                  style: Styles.caption.merge(const TextStyle(
                                      color: MyColors.white,
                                      height: 18 / 12,
                                      fontFamily: 'Pretendard')),
                                )
                              ],
                            )),
                        _divider,
                        InfoRow(
                            // TODO: 메모 불러오기
                            label: '거래 메모',
                            value: Text(
                              '-',
                              style: Styles.body2Number
                                  .merge(const TextStyle(height: 22 / 14)),
                            )),
                        _divider,
                        InfoRow(
                            // TODO: 태그 불러오기
                            label: '태그',
                            subLabel: '편집',
                            onSubLabelClicked: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: MyColors.black,
                                builder: (context) => TagBottomSheetContainer(
                                  type: TagBottomSheetType.select,
                                  onComplete: (_, utxo) =>
                                      debugPrint(utxo.toString()),
                                  utxoTags: const [
                                    UtxoTag(tag: 'kyc', colorIndex: 0),
                                    UtxoTag(tag: 'coconut', colorIndex: 2),
                                    UtxoTag(tag: 'strike', colorIndex: 7),
                                    UtxoTag(tag: '1', colorIndex: 7),
                                    UtxoTag(tag: '2', colorIndex: 7),
                                    UtxoTag(tag: '3', colorIndex: 7),
                                    UtxoTag(tag: '4', colorIndex: 7),
                                    UtxoTag(tag: '5', colorIndex: 7),
                                  ],
                                ),
                              );
                            },
                            value: Text(
                              '-',
                              style: Styles.body2Number
                                  .merge(const TextStyle(height: 22 / 14)),
                            )),
                        _divider,
                        InfoRow(
                          label: '트랜잭션 ID',
                          subLabel: '거래 자세히 보기',
                          onSubLabelClicked: () {
                            // Navigator.pushNamed(context, '/transaction-detail',
                            //     arguments: {'id': widget.id, 'tx': widget.tx});
                          },
                          value: Text(
                            widget.utxo.txHash,
                            style: Styles.body2Number
                                .merge(const TextStyle(height: 22 / 14)),
                          ),
                        ),
                        _divider,
                        InfoRow(
                            label: '블록 번호',
                            subLabel: '멤풀 보기',
                            onSubLabelClicked: () => launchUrl(Uri.parse(
                                "${PowWalletApp.kMempoolHost}/block/${widget.utxo.blockHeight}")),
                            value: Text(
                              widget.utxo.blockHeight,
                              style: Styles.body2Number
                                  .merge(const TextStyle(height: 22 / 14)),
                            )),
                        const SizedBox(
                          height: 40,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _utxoTooltipWidget(context),
          ],
        ),
      ),
    );
  }

  Widget _utxoTooltipWidget(BuildContext context) {
    return _isUtxoTooltipVisible
        ? Positioned(
            top: _utxoTooltipIconPosition.dy + _utxoTooltipIconSize.height - 10,
            right: MediaQuery.of(context).size.width -
                _utxoTooltipIconPosition.dx -
                _utxoTooltipIconSize.width +
                5,
            child: GestureDetector(
              onTap: _removeUtxoTooltip,
              child: ClipPath(
                clipper: RightTriangleBubbleClipper(),
                child: Container(
                  padding: const EdgeInsets.only(
                    top: 25,
                    left: 18,
                    right: 18,
                    bottom: 10,
                  ),
                  color: MyColors.skybule,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _utxoTip,
                        style: Styles.caption.merge(TextStyle(
                          height: 1.3,
                          fontFamily: CustomFonts.text.getFontFamily,
                          color: MyColors.darkgrey,
                        )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : Container();
  }

  void _removeUtxoTooltip() {
    // if (_overlayEntry != null) {
    //   _faucetTipVisible = false;
    //   _overlayEntry!.remove();
    //   _overlayEntry = null;
    // }
    setState(() {
      _isUtxoTooltipVisible = false;
    });
  }
}

const _divider = Divider(color: MyColors.transparentWhite_15);

class InfoRow extends StatelessWidget {
  final String label;
  final bool isChangeTagVisible;
  final Widget value;
  final String? subLabel;
  final VoidCallback? onSubLabelClicked;

  const InfoRow(
      {super.key,
      required this.label,
      this.isChangeTagVisible = false,
      required this.value,
      this.subLabel,
      this.onSubLabelClicked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(
              label,
              style: Styles.body2.merge(
                const TextStyle(
                  color: MyColors.transparentWhite_70,
                  height: 21 / 14,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (isChangeTagVisible) const CustomChip(text: '잔돈'),
            if (subLabel != null)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: CustomUnderlinedButton(
                    text: subLabel!,
                    onTap: () {
                      if (onSubLabelClicked != null) {
                        onSubLabelClicked!();
                      }
                    },
                    fontSize: 12,
                    lineHeight: 18,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          value
        ],
      ),
    );
  }
}

class InputOutputDetailRow extends StatelessWidget {
  final String address;
  final int balance;
  final InputOutputRowType rowType;
  final bool isCurrentAddress;
  final TransactionStatus? transactionStatus;

  const InputOutputDetailRow({
    super.key,
    required this.address,
    required this.balance,
    required this.rowType,
    this.isCurrentAddress = false,
    this.transactionStatus,
  });

  @override
  Widget build(BuildContext context) {
    Color leftItemColor = MyColors.white;
    Color rightItemColor = MyColors.white;
    String assetAddress = 'assets/svg/circle-arrow-right-white.svg';

    if (transactionStatus != null) {
      /// transactionStatus가 null이 아니면 거래 자세히 보기 화면
      if (transactionStatus == TransactionStatus.received ||
          transactionStatus == TransactionStatus.receiving) {
        /// transaction 받기 결과
        if (rowType == InputOutputRowType.input) {
          /// 인풋
          if (isCurrentAddress) {
            /// 현재 주소인 경우
            leftItemColor = rightItemColor = MyColors.white;
            assetAddress = 'assets/svg/circle-arrow-right-white.svg';
          } else {
            /// 현재 주소가 아닌 경우
            leftItemColor = rightItemColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right-transparent.svg';
          }
        } else if (rowType == InputOutputRowType.output) {
          /// 아웃풋
          if (isCurrentAddress) {
            /// 현재 주소인 경우
            leftItemColor = MyColors.white;
            rightItemColor = MyColors.secondary;
            assetAddress = 'assets/svg/circle-arrow-right-blue.svg';
          } else {
            /// 현재 주소가 아닌 경우
            leftItemColor = rightItemColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right-transparent.svg';
          }
        } else {
          /// 수수료
          leftItemColor = rightItemColor = MyColors.white;
          assetAddress = 'assets/svg/circle-pick-white.svg';
        }
      } else if (transactionStatus == TransactionStatus.sending ||
          transactionStatus == TransactionStatus.sent) {
        /// transaction 보내기 결과
        if (rowType == InputOutputRowType.input) {
          /// 안풋
          leftItemColor = MyColors.white;
          rightItemColor = MyColors.primary;
          assetAddress = 'assets/svg/circle-arrow-right-green.svg';
        } else if (rowType == InputOutputRowType.output) {
          /// 아웃풋
          if (isCurrentAddress) {
            /// 현재 주소인 경우
            leftItemColor = MyColors.white;
            rightItemColor = MyColors.white;
            assetAddress = 'assets/svg/circle-arrow-right-white.svg';
          } else {
            /// 현재 주소가 아닌 경우
            leftItemColor = rightItemColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right-transparent.svg';
          }
        } else {
          /// 수수료
          leftItemColor = rightItemColor = MyColors.white;
          assetAddress = 'assets/svg/circle-pick-white.svg';
        }
      } else if (transactionStatus == TransactionStatus.self ||
          transactionStatus == TransactionStatus.selfsending) {
        if (rowType == InputOutputRowType.input) {
          if (isCurrentAddress) {
            leftItemColor = MyColors.white;
            rightItemColor = MyColors.primary;
            assetAddress = 'assets/svg/circle-arrow-right-green.svg';
          } else {
            leftItemColor = MyColors.transparentWhite_40;
            rightItemColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right-transparent.svg';
          }
        } else if (rowType == InputOutputRowType.output) {
          leftItemColor = MyColors.transparentWhite_40;
          rightItemColor = MyColors.transparentWhite_40;
          assetAddress = 'assets/svg/circle-arrow-right-transparent.svg';
        } else {
          leftItemColor = MyColors.white;
          rightItemColor = MyColors.white;
          assetAddress = 'assets/svg/circle-pick-white.svg';
        }
      }
    } else {
      /// transactionStatus가 null이면 UTXO 상세 화면
      if (rowType == InputOutputRowType.input) {
        /// 인풋
        leftItemColor = rightItemColor = MyColors.transparentWhite_40;
        assetAddress = 'assets/svg/circle-arrow-right-transparent.svg';
      } else if (rowType == InputOutputRowType.output) {
        /// 아웃풋
        if (isCurrentAddress) {
          /// 현재 주소인 경우
          leftItemColor = rightItemColor = MyColors.white;
        } else {
          /// 현재 주소가 아닌 경우
          leftItemColor = rightItemColor = MyColors.transparentWhite_40;
          assetAddress = 'assets/svg/circle-arrow-right-transparent.svg';
        }
      } else {
        /// 수수료
        leftItemColor = rightItemColor = MyColors.transparentWhite_40;
        assetAddress = 'assets/svg/circle-pick-transparent.svg';
      }
    }

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            TextUtils.truncateNameMax19(address),
            style: Styles.body2Number.merge(
              TextStyle(
                color: leftItemColor,
                fontSize: 14,
                height: 16 / 14,
              ),
            ),
            maxLines: 1,
          ),
        ),
        Expanded(
          flex: 5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (rowType == InputOutputRowType.output ||
                  rowType == InputOutputRowType.fee)
                Row(
                  children: [
                    SvgPicture.asset(
                      assetAddress,
                      width: 16,
                      height: 12,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              Text(
                '${satoshiToBitcoinString(balance).normalizeTo11Characters()} BTC',
                style: Styles.body2Number.merge(
                  TextStyle(
                    color: rightItemColor,
                    fontSize: 14,
                    height: 16 / 14,
                  ),
                ),
              ),
              if (rowType == InputOutputRowType.input)
                Row(
                  children: [
                    const SizedBox(width: 6),
                    SvgPicture.asset(
                      assetAddress,
                      width: 16,
                      height: 12,
                    ),
                  ],
                )
            ],
          ),
        ),
      ],
    );
  }
}

enum InputOutputRowType { input, output, fee }

enum InputOutputDetailRowStatus {
  /// input, output 컬럼의 색상구분을 편하게 하기 위해 enum으로 관리하였습니다.
  txInputSend,
  txInputReceive,
  txOutputSend,
  txOutputReceive,
  txOutputFee,
  txInputReceiveCurrentAddress,
  txOutputSendCurrentAddress,
  txOutputReceiveCurrentAddress,
  utxoInput,
  utxoOutput,
  utxoOutputFee,
  utxoOutputCurrentAddress,
}
