import 'package:flutter/material.dart';
import 'package:coconut_wallet/model/send_info.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';

class SendUtxoSelectionScreen extends StatefulWidget {
  final SendInfo sendInfo;
  final int id;

  const SendUtxoSelectionScreen(
      {super.key, required this.sendInfo, required this.id});

  @override
  State<SendUtxoSelectionScreen> createState() =>
      _SendUtxoSelectionScreenState();
}

class _SendUtxoSelectionScreenState extends State<SendUtxoSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.black,
      appBar: CustomAppBar.buildWithNext(
        title: 'UTXO 고르기',
        nextButtonTitle: '완료',
        context: context,
        isActive: false,
        onNextPressed: () {
          // TODO:
        },
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // TODO:
            ],
          ),
        ),
      ),
    );
  }
}
