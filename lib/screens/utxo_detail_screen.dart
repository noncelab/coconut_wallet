import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/screens/bottomsheet/tag_bottom_sheet_container.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_chip.dart';
import 'package:coconut_wallet/widgets/custom_tag_chip.dart';
import 'package:coconut_wallet/widgets/highlighted_Info_area.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/model/utxo.dart' as model;
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UtxoDetailScreen extends StatefulWidget {
  final int id;
  final model.UTXO utxo;

  const UtxoDetailScreen({
    super.key,
    required this.id,
    required this.utxo,
  });

  @override
  State<UtxoDetailScreen> createState() => _UtxoDetailScreenState();
}

class _UtxoDetailScreenState extends State<UtxoDetailScreen> {
  late AppStateModel _model;
  late List<String> _dateString;
  late bool _isUtxoTooltipVisible;

  final GlobalKey _utxoTooltipIconKey = GlobalKey();
  late Size _utxoTooltipIconSize;
  late Offset _utxoTooltipIconPosition;

  final String _utxoTip =
      'UTXO란 Unspent Tx Output을 줄인 말로 아직 쓰이지 않은 잔액이란 뜻이에요. 비트코인에는 잔액 개념이 없어요. 지갑에 표시되는 잔액은 UTXO의 총합이라는 것을 알아두세요.';

  final GlobalKey _balanceWidthKey = GlobalKey();
  Size _balanceWidthSize = const Size(0, 0);

  int initialInputMaxCount = 3;
  int initialOutputMaxCount = 2;

  String _txHashIndex = '';

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);
    _txHashIndex = '${widget.utxo.txHash}${widget.utxo.index}';
    _dateString = DateTimeUtil.formatDatetime(widget.utxo.timestamp).split('|');
    _isUtxoTooltipVisible = false;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _model.initUtxoDetailScreenTagData(
          widget.id, widget.utxo.txHash, widget.utxo.index);

      await Future.delayed(const Duration(milliseconds: 100));

      RenderBox utxoTooltipIconRenderBox =
          _utxoTooltipIconKey.currentContext?.findRenderObject() as RenderBox;
      _utxoTooltipIconPosition =
          utxoTooltipIconRenderBox.localToGlobal(Offset.zero);
      _utxoTooltipIconSize = utxoTooltipIconRenderBox.size;

      RenderBox balanceWidthRenderBox =
          _balanceWidthKey.currentContext?.findRenderObject() as RenderBox;
      setState(() {
        _balanceWidthSize = balanceWidthRenderBox.size;
      });
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
            Selector<AppStateModel, Map<String, dynamic>>(
              selector: (_, model) => {
                'transaction': model.transaction,
                'utxoTagList': model.utxoTagList,
                'selectedUtxoTags': model.selectedTagList,
              },
              builder: (context, dataMap, child) {
                final tx = dataMap['transaction'] as Transfer?;
                final utxoTagList = dataMap['utxoTagList'] as List<UtxoTag>;
                final selectedUtxoTags =
                    dataMap['selectedUtxoTags'] as List<UtxoTag>;

                if (tx == null) return Container();

                if (tx.inputAddressList.length <= initialInputMaxCount) {
                  initialInputMaxCount = tx.inputAddressList.length;
                }
                if (tx.outputAddressList.length <= initialOutputMaxCount) {
                  initialOutputMaxCount = tx.outputAddressList.length;
                }

                if (tx.outputAddressList.isNotEmpty) {
                  tx.outputAddressList.sort((a, b) {
                    if (a.address == widget.utxo.to) return -1;
                    if (b.address == widget.utxo.to) return 1;
                    return 0;
                  });
                }

                return Scaffold(
                  backgroundColor: MyColors.black,
                  appBar: CustomAppBar.build(
                    title: 'UTXO',
                    context: context,
                    showTestnetLabel: false,
                    hasRightIcon: true,
                    onBackPressed: () {
                      Navigator.pop(context);
                    },
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
                                  TextSpan(
                                      text: ' BTC', style: Styles.body2Number)
                                ]))),
                            const SizedBox(
                              height: 8,
                            ),
                            Center(
                                child: Selector<UpbitConnectModel, int?>(
                              selector: (context, model) =>
                                  model.bitcoinPriceKrw,
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
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: initialInputMaxCount,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (context, index) {
                                        return Column(
                                          children: [
                                            InputOutputDetailRow(
                                              address: tx
                                                  .inputAddressList[index]
                                                  .address,
                                              balance: tx
                                                  .inputAddressList[index]
                                                  .amount,
                                              balanceMaxWidth:
                                                  _balanceWidthSize.width > 0
                                                      ? _balanceWidthSize.width
                                                      : 100,
                                              rowType: InputOutputRowType.input,
                                              isCurrentAddress: tx
                                                      .inputAddressList[index]
                                                      .address ==
                                                  widget.utxo.to,
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        );
                                      },
                                    ),
                                    Visibility(
                                      visible: tx.inputAddressList.length >
                                          initialInputMaxCount,
                                      child: Text(
                                        '...',
                                        style: Styles.caption.merge(
                                            const TextStyle(
                                                color: MyColors
                                                    .transparentWhite_40,
                                                height: 8 / 12)),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InputOutputDetailRow(
                                      address: '수수료',
                                      balance: 142,
                                      balanceMaxWidth:
                                          _balanceWidthSize.width > 0
                                              ? _balanceWidthSize.width
                                              : 100,
                                      rowType: InputOutputRowType.fee,
                                    ),
                                    const SizedBox(height: 8),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: initialOutputMaxCount,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (context, index) {
                                        return Column(
                                          children: [
                                            InputOutputDetailRow(
                                              address: tx
                                                  .outputAddressList[index]
                                                  .address,
                                              balance: tx
                                                  .outputAddressList[index]
                                                  .amount,
                                              balanceMaxWidth:
                                                  _balanceWidthSize.width > 0
                                                      ? _balanceWidthSize.width
                                                      : 100,
                                              rowType:
                                                  InputOutputRowType.output,
                                              isCurrentAddress: tx
                                                      .outputAddressList[index]
                                                      .address ==
                                                  widget.utxo.to,
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        );
                                      },
                                    ),
                                    Visibility(
                                      visible: tx.outputAddressList.length >
                                          initialOutputMaxCount,
                                      child: Text(
                                        '...',
                                        style: Styles.caption.merge(
                                            const TextStyle(
                                                color: MyColors
                                                    .transparentWhite_40,
                                                height: 8 / 12)),
                                      ),
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
                                    widget.utxo.derivationPath.split('/')[4] ==
                                        '1',
                                value: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.utxo.to,
                                      style: Styles.body2Number.merge(
                                          const TextStyle(height: 22 / 14)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.utxo.derivationPath,
                                      style: Styles.caption.merge(
                                          const TextStyle(
                                              color: MyColors.white,
                                              height: 18 / 12,
                                              fontFamily: 'Pretendard')),
                                    )
                                  ],
                                )),
                            _divider,
                            InfoRow(
                              label: '거래 메모',
                              value: Text(
                                tx.memo?.isNotEmpty == true ? tx.memo! : '-',
                                style: Styles.body2Number
                                    .merge(const TextStyle(height: 22 / 14)),
                              ),
                            ),
                            _divider,
                            InfoRow(
                              label: '태그',
                              subLabel: '편집',
                              onSubLabelClicked: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: MyColors.black,
                                  isScrollControlled: true,
                                  builder: (context) => TagBottomSheetContainer(
                                    type: TagBottomSheetType.select,
                                    utxoTags: utxoTagList,
                                    selectedUtxoTagNames: selectedUtxoTags
                                        .map((e) => e.name)
                                        .toList(),
                                    onSelected: (selectedNames, addTags) {
                                      // print(addTags);
                                      _model.updateUtxoTagList(
                                        selectedNames: selectedNames,
                                        addTags: addTags,
                                        walletId: widget.id,
                                        txHashIndex: _txHashIndex,
                                      );
                                    },
                                  ),
                                );
                              },
                              value: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (selectedUtxoTags.isEmpty) ...{
                                    Text(
                                      '-',
                                      style: Styles.body2Number.merge(
                                        const TextStyle(height: 22 / 14),
                                      ),
                                    ),
                                  } else ...{
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: List.generate(
                                        selectedUtxoTags.length,
                                        (index) => IntrinsicWidth(
                                          child: CustomTagChip(
                                            tag: selectedUtxoTags[index].name,
                                            colorIndex: selectedUtxoTags[index]
                                                .colorIndex,
                                            type: CustomTagChipType.fix,
                                          ),
                                        ),
                                      ),
                                    ),
                                  },
                                ],
                              ),
                            ),
                            _divider,
                            InfoRow(
                              label: '트랜잭션 ID',
                              subLabel: '거래 자세히 보기',
                              onSubLabelClicked: () {
                                Navigator.pushNamed(
                                    context, '/transaction-detail', arguments: {
                                  'id': widget.id,
                                  'txHash': widget.utxo.txHash
                                });
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
                            Text(
                              /// inputOutput 위젯에 들어갈 balance 최대 너비 체크용
                              key: _balanceWidthKey,
                              '0.0000 0000',
                              style: Styles.body2Number.merge(
                                const TextStyle(
                                  color: Colors.transparent,
                                  fontSize: 14,
                                  height: 16 / 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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
                  width: MediaQuery.sizeOf(context).width * 0.68,
                  padding: const EdgeInsets.only(
                    top: 25,
                    left: 18,
                    right: 18,
                    bottom: 10,
                  ),
                  color: MyColors.skybule,
                  child: Text(
                    _utxoTip,
                    style: Styles.caption.merge(TextStyle(
                      height: 1.3,
                      fontFamily: CustomFonts.text.getFontFamily,
                      color: MyColors.darkgrey,
                    )),
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
  final double balanceMaxWidth;
  final InputOutputRowType rowType;
  final bool isCurrentAddress;
  final TransactionStatus? transactionStatus;

  const InputOutputDetailRow({
    super.key,
    required this.address,
    required this.balance,
    required this.balanceMaxWidth,
    required this.rowType,
    this.isCurrentAddress = false,
    this.transactionStatus,
  });

  @override
  Widget build(BuildContext context) {
    Color leftItemColor = MyColors.white;
    Color rightItemColor = MyColors.white;
    String assetAddress = 'assets/svg/circle-arrow-right.svg';
    Color assetColor = MyColors.white;

    if (transactionStatus != null) {
      /// transactionStatus가 null이 아니면 거래 자세히 보기 화면
      if (transactionStatus == TransactionStatus.received ||
          transactionStatus == TransactionStatus.receiving) {
        /// transaction 받기 결과
        if (rowType == InputOutputRowType.input) {
          /// 인풋
          if (isCurrentAddress) {
            /// 현재 주소인 경우
            leftItemColor = rightItemColor = assetColor = MyColors.white;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          } else {
            /// 현재 주소가 아닌 경우
            leftItemColor =
                rightItemColor = assetColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          }
        } else if (rowType == InputOutputRowType.output) {
          /// 아웃풋
          if (isCurrentAddress) {
            /// 현재 주소인 경우
            leftItemColor = MyColors.white;
            rightItemColor = MyColors.secondary;
            assetColor = rightItemColor;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          } else {
            /// 현재 주소가 아닌 경우
            leftItemColor =
                rightItemColor = assetColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          }
        } else {
          /// 수수료
          leftItemColor = rightItemColor = assetColor = MyColors.white;
          assetAddress = 'assets/svg/circle-pick.svg';
        }
      } else if (transactionStatus == TransactionStatus.sending ||
          transactionStatus == TransactionStatus.sent) {
        /// transaction 보내기 결과
        if (rowType == InputOutputRowType.input) {
          /// 안풋
          leftItemColor = MyColors.white;
          rightItemColor = assetColor = MyColors.primary;
          assetAddress = 'assets/svg/circle-arrow-right.svg';
        } else if (rowType == InputOutputRowType.output) {
          /// 아웃풋
          if (isCurrentAddress) {
            /// 현재 주소인 경우
            leftItemColor = MyColors.white;
            rightItemColor = assetColor = MyColors.white;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          } else {
            /// 현재 주소가 아닌 경우
            leftItemColor =
                rightItemColor = assetColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          }
        } else {
          /// 수수료
          leftItemColor = rightItemColor = assetColor = MyColors.white;
          assetAddress = 'assets/svg/circle-pick.svg';
        }
      } else if (transactionStatus == TransactionStatus.self ||
          transactionStatus == TransactionStatus.selfsending) {
        if (rowType == InputOutputRowType.input) {
          if (isCurrentAddress) {
            leftItemColor = MyColors.white;
            rightItemColor = assetColor = MyColors.primary;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          } else {
            leftItemColor = MyColors.transparentWhite_40;
            rightItemColor = assetColor = MyColors.transparentWhite_40;
            assetAddress = 'assets/svg/circle-arrow-right.svg';
          }
        } else if (rowType == InputOutputRowType.output) {
          if (isCurrentAddress) {
            leftItemColor = MyColors.white;
            rightItemColor = assetColor = MyColors.secondary;
          } else {
            leftItemColor = MyColors.transparentWhite_40;
            rightItemColor = assetColor = MyColors.transparentWhite_40;
          }
          assetAddress = 'assets/svg/circle-arrow-right.svg';
        } else {
          leftItemColor = MyColors.white;
          rightItemColor = assetColor = MyColors.white;
          assetAddress = 'assets/svg/circle-pick.svg';
        }
      }
    } else {
      /// transactionStatus가 null이면 UTXO 상세 화면
      if (rowType == InputOutputRowType.input) {
        /// 인풋
        leftItemColor =
            rightItemColor = assetColor = MyColors.transparentWhite_40;
        assetAddress = 'assets/svg/circle-arrow-right.svg';
      } else if (rowType == InputOutputRowType.output) {
        /// 아웃풋
        if (isCurrentAddress) {
          /// 현재 주소인 경우
          leftItemColor = rightItemColor = assetColor = MyColors.white;
        } else {
          /// 현재 주소가 아닌 경우
          leftItemColor =
              rightItemColor = assetColor = MyColors.transparentWhite_40;
          assetAddress = 'assets/svg/circle-arrow-right.svg';
        }
      } else {
        /// 수수료
        leftItemColor =
            rightItemColor = assetColor = MyColors.transparentWhite_40;
        assetAddress = 'assets/svg/circle-pick.svg';
      }
    }

    return Row(
      children: [
        Text(
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
        if (rowType == InputOutputRowType.output ||
            rowType == InputOutputRowType.fee)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SvgPicture.asset(
                  assetAddress,
                  width: 16,
                  height: 12,
                  colorFilter: ColorFilter.mode(assetColor, BlendMode.srcIn),
                ),
                const SizedBox(
                  width: 10,
                ),
                SizedBox(
                  width: balanceMaxWidth,
                  child: Text(
                    textAlign: TextAlign.end,
                    satoshiToBitcoinString(balance).normalizeTo11Characters(),
                    style: Styles.body2Number.merge(
                      TextStyle(
                        color: rightItemColor,
                        fontSize: 14,
                        height: 16 / 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (rowType == InputOutputRowType.input)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: balanceMaxWidth,
                  child: Text(
                    satoshiToBitcoinString(balance).normalizeTo11Characters(),
                    style: Styles.body2Number.merge(
                      TextStyle(
                        color: rightItemColor,
                        fontSize: 14,
                        height: 16 / 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                SvgPicture.asset(
                  assetAddress,
                  width: 16,
                  height: 12,
                  colorFilter: ColorFilter.mode(assetColor, BlendMode.srcIn),
                ),
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
