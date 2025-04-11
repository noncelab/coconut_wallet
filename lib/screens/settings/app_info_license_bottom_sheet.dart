import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';

import '../../oss_licenses.dart';

class LicenseBottomSheet extends StatefulWidget {
  const LicenseBottomSheet({super.key});

  @override
  State<LicenseBottomSheet> createState() => _LicenseBottomSheetState();
}

class _LicenseBottomSheetState extends State<LicenseBottomSheet> {
  late List<bool> licenseExplanationVisible = List.filled(dependencies.length, false);
  final defaultTextStyle = CoconutTypography.body2_14;

  String? identifyLicense(String licenseText) {
    final Map<String, String> licenseKeywords = {
      'MIT License': 'Permission is hereby granted,',
      'Apache License': 'Apache License',
      'BSD License': 'Redistribution and use in source and binary forms,',
      'GPL License': 'This program is free software:',
      'EPL License': 'Eclipse Public License - v 2.0',
      'Creative Commons License': 'This work is licensed under a Creative Commons Attribution',
      'Proprietary License': 'This software is proprietary and confidential',
      'Public Domain': 'The person who associated a work with this',
      'LGPL License': 'This library is free software; you can redistribute it',
    };

    for (var license in licenseKeywords.keys) {
      if (licenseText.contains(licenseKeywords[license]!)) {
        return license;
      }
    }

    return null;
  }

  TextSpan linkSpan({
    required String text,
    required String url,
  }) {
    return TextSpan(
      text: text,
      style: defaultTextStyle.copyWith(
        color: CoconutColors.sky,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          launchURL(url);
        },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
      child: Scaffold(
        backgroundColor: CoconutColors.black,
        appBar: CustomAppBar.build(
          title: t.license_bottom_sheet.title,
          context: context,
          onBackPressed: null,
          hasRightIcon: false,
          isBottom: true,
          showTestnetLabel: false,
        ),
        body: SafeArea(
          child: ListView.builder(
            itemCount: dependencies.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    CoconutLayout.spacing_600h,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      child: RichText(
                        text: TextSpan(
                          text: t.license_bottom_sheet.copyright_text1,
                          style: defaultTextStyle,
                          children: <TextSpan>[
                            linkSpan(
                              text: MIT_LICENSE_URL,
                              url: MIT_LICENSE_URL,
                            ),
                            TextSpan(text: t.license_bottom_sheet.copyright_text2),
                            linkSpan(
                              text: CONTACT_EMAIL_ADDRESS,
                              url:
                                  'mailto:$CONTACT_EMAIL_ADDRESS?subject=${t.license_bottom_sheet.email_subject}',
                            ),
                            TextSpan(
                              text: t.license_bottom_sheet.copyright_text3,
                              style: defaultTextStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    const Divider(),
                  ],
                );
              } else {
                final license = dependencies[index - 1];
                final licenseName = license.name;
                String copyRight = '';
                List<String>? licenseClassExplanation = license.license?.split('\n');
                String? licenseClass = '';

                /// License 종류 찾기
                licenseClass = identifyLicense(license.license!);

                /// CopyRight 문구 찾기
                if (licenseClassExplanation != null) {
                  for (String line in licenseClassExplanation) {
                    if (line.startsWith('Copyright')) {
                      copyRight = line;
                      if (copyRight.contains('All rights reserved')) {
                        copyRight = copyRight.split('.')[0];
                      }
                      break;
                    }
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (licenseClass != null && licenseClass.isNotEmpty) {
                          setState(() {
                            licenseExplanationVisible[index - 1] =
                                !licenseExplanationVisible[index - 1];
                          });
                        }
                      },
                      child: Ink(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              licenseName,
                              style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                            ),
                            if (copyRight.isNotEmpty)
                              Text(copyRight, style: CoconutTypography.body3_12),
                            SizedBox(
                              width: MediaQuery.of(context).size.width,
                              child: Text(licenseClass ?? 'Unknown License',
                                  style: CoconutTypography.body3_12),
                            ),
                            if (licenseExplanationVisible[index - 1])
                              Container(
                                margin: const EdgeInsets.only(
                                  top: 8,
                                ),
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(width: 1, color: CoconutColors.gray700),
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  child: Text(
                                    license.license!,
                                    style: const TextStyle(
                                      color: CoconutColors.gray700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
