import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coconut_wallet/styles.dart';

enum FileType {
  license,
  contributing,
}

@Deprecated("ReadFileViewScreen Deprecated")
class ReadFileViewScreen extends StatefulWidget {
  final FileType fileType;
  const ReadFileViewScreen({super.key, required this.fileType});

  @override
  State<ReadFileViewScreen> createState() => _ReadFileViewScreenState();
}

class _ReadFileViewScreenState extends State<ReadFileViewScreen> {
  String viewText = '';
  String appTitleText = '';
  List<Widget> parsedMarkdown = [];

  @override
  void initState() {
    super.initState();
    loadFile();
  }

  Future<void> loadFile() async {
    String text = '';
    String titleText = '';
    List<Widget> widgets = [];

    switch (widget.fileType) {
      case FileType.license:
        text = await rootBundle.loadString('assets/files/LICENSE');
        titleText = 'MIT LICENSE';
        break;
      case FileType.contributing:
        text = await rootBundle.loadString('assets/files/CONTRIBUTING.md');
        List<String> lines = text.split('\n');
        for (String line in lines) {
          if (line.startsWith('## ')) {
            widgets.add(
              Text(
                line.substring(3),
                style: Styles.body1,
              ),
            );
          } else if (line.startsWith('# ')) {
            widgets.add(
              Text(
                line.substring(2),
                style: Styles.body1Bold,
              ),
            );
          } else {
            widgets.add(
              Text(
                line,
                style: Styles.body2.merge(
                  const TextStyle(
                    color: MyColors.transparentWhite_70,
                  ),
                ),
              ),
            );
          }
        }
        titleText = '오픈소스 개발 참여하기';
        break;
    }
    setState(() {
      viewText = text;
      appTitleText = titleText;
      parsedMarkdown = widgets;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.black,
      appBar: CoconutAppBar.build(
          title: appTitleText,
          context: context,
          hasRightIcon: false,
          isBottom: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: widget.fileType == FileType.license
                ? Text(viewText, style: Styles.body2)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: parsedMarkdown,
                  ),
          ),
        ),
      ),
    );
  }
}
