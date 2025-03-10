import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/card/address_and_quantity_card.dart';
import 'package:flutter/material.dart';

class SendAddressBodyBatch extends StatefulWidget {
  final Future<void> Function(String recipient) validateAddress;
  final bool Function(int totalSendAmount) checkSendAvailable;
  final void Function(Map<String, int> recipients) onRecipientsConfirmed;
  final void Function() onReset;
  const SendAddressBodyBatch(
      {super.key,
      required this.validateAddress,
      required this.checkSendAvailable,
      required this.onRecipientsConfirmed,
      required this.onReset});

  @override
  State<SendAddressBodyBatch> createState() => _SendAddressBodyBatchState();
}

class _SendAddressBodyBatchState extends State<SendAddressBodyBatch> {
  final List<Map<String, int>> _recipients = [{}];
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      semanticChildCount: 1,
      slivers: [
        SliverSafeArea(
          minimum: const EdgeInsets.symmetric(
              horizontal: CoconutLayout.defaultPadding, vertical: Sizes.size28),
          sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
            return index != _recipients.length
                ? AddressAndQuantityCard(
                    title: '받는 사람1', showAddressScanner: () {})
                : CoconutUnderlinedButton(
                    text: t.send_address_screen.add_recipient,
                    onTap: () {
                      throw 'imple';
                    },
                    textStyle: CoconutTypography.body3_12,
                    brightness: Brightness.dark,
                    padding: const EdgeInsets.symmetric(vertical: Sizes.size36),
                  );
          }, childCount: _recipients.length + 1)),
        ),
      ],
    );
  }
}
