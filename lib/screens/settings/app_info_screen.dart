import 'dart:io';
import 'dart:ui';

import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:coconut_wallet/constants/app_info.dart';
import 'package:coconut_wallet/widgets/overlays/license_bottom_sheet.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  late ScrollController _scrollController;
  double topPadding = 0;
  bool _isScrollOverTitleHeight = false;
  bool _appbarTitleVisible = false;
  late Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _packageInfoFuture = _initPackageInfo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(_scrollListener);
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= 30) {
      if (!_isScrollOverTitleHeight) {
        setState(() {
          _isScrollOverTitleHeight = true;
        });
      }
    } else {
      if (_isScrollOverTitleHeight) {
        setState(() {
          _isScrollOverTitleHeight = false;
        });
      }
    }

    if (_scrollController.position.pixels >= 15) {
      if (!_appbarTitleVisible) {
        setState(() {
          _appbarTitleVisible = true;
        });
      }
    } else {
      if (_appbarTitleVisible) {
        setState(() {
          _appbarTitleVisible = false;
        });
      }
    }
  }

  Future<String> _getDeviceInfo(Future<PackageInfo> packageInfoFuture) async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    String info = "";

    try {
      PackageInfo packageInfo = await packageInfoFuture;

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        return info = 'Android Device Info:\n'
            'Brand: ${androidInfo.brand}\n'
            'Model: ${androidInfo.model}\n'
            'Android Version: ${androidInfo.version.release}\n'
            'SDK: ${androidInfo.version.sdkInt}\n'
            'Manufacturer: ${androidInfo.manufacturer}\n'
            'App Version: ${packageInfo.appName} ver.${packageInfo.version}\n'
            'Build Number: ${packageInfo.buildNumber}\n\n'
            '------------------------------------------------------------\n'
            '${t.app_info_screen.inquiry}: \n\n\n\n\n';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        return info = 'iOS Device Info:\n'
            'Name: ${iosInfo.name}\n'
            'Model: ${iosInfo.model}\n'
            'System Name: ${iosInfo.systemName}\n'
            'System Version: ${iosInfo.systemVersion}\n'
            'Identifier For Vendor: ${iosInfo.identifierForVendor}\n'
            'App Version: ${packageInfo.appName} ver.${packageInfo.version}\n'
            'Build Number: ${packageInfo.buildNumber}\n\n'
            '------------------------------------------------------------\n'
            '${t.app_info_screen.inquiry}: \n\n';
      }
    } catch (e) {
      throw '디바이스 정보를 불러올 수 없음 : $e';
    }
    return info;
  }

  Future<PackageInfo> _initPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    topPadding = kToolbarHeight + MediaQuery.of(context).padding.top + 30;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: MyColors.black,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: _isScrollOverTitleHeight
            ? MyColors.transparentBlack_50
            : MyColors.black,
        toolbarHeight: kToolbarHeight,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close_rounded,
                color: MyColors.white, size: 22)),
        flexibleSpace: _isScrollOverTitleHeight
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: MyColors.transparentWhite_06,
                  ),
                ),
              )
            : null,
        title: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _appbarTitleVisible ? 1 : 0,
          child: const Text(
            '앱 정보',
            style: Styles.appbarTitle,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          controller: _scrollController,
          child: Container(
            color: MyColors.black,
            child: Column(
              children: [
                Container(
                  height: topPadding,
                  color: MyColors.black,
                ),
                headerWidget(_packageInfoFuture),
                Container(
                  height: 50,
                  color: MyColors.black,
                ),
                socialMediaWidget(),
                Container(
                  height: 50,
                  color: MyColors.black,
                ),
                githubWidget(),
                Container(
                  height: 50,
                  color: MyColors.black,
                ),
                footerWidget(_packageInfoFuture),
              ],
            ),
          )),
    );
  }

  Widget headerWidget(Future<PackageInfo> packageInfoFuture) {
    return FutureBuilder<PackageInfo>(
        future: packageInfoFuture,
        builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
              color: MyColors.white,
            ));
          } else if (snapshot.hasError) {
            return Center(child: Text(t.errors.data_loading_failed));
          } else if (!snapshot.hasData) {
            return Center(child: Text(t.errors.data_not_found));
          }

          PackageInfo packageInfo = snapshot.data!;

          return Container(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: const BoxDecoration(
              color: MyColors.black,
            ),
            child: Row(
              children: [
                Container(
                  width: 80.0,
                  height: 80.0,
                  padding: const EdgeInsets.all(
                    16,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: MyColors.borderGrey,
                      width: 2.0,
                    ),
                    color: Colors.black,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/splash_logo.png',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 30,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      packageInfo.appName,
                      style: Styles.body1Bold.merge(
                        const TextStyle(
                          fontSize: 24,
                        ),
                      ),
                    ),
                    Text(
                      'ver.${packageInfo.version}',
                      style: Styles.body2Bold.merge(
                        const TextStyle(
                          color: MyColors.lightgrey,
                        ),
                      ),
                    ),
                    Text(
                      t.app_info_screen.made_by_team_pow,
                      style: Styles.body2.merge(
                        const TextStyle(
                          color: MyColors.transparentWhite_70,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          );
        });
  }

  Widget socialMediaWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: const BoxDecoration(
        color: MyColors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _category(t.app_info_screen.category1_ask),
          ButtonGroup(buttons: [
            SingleButton(
              title: t.app_info_screen.go_to_pow,
              leftElement: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  'assets/images/pow-full-logo.jpg',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
              onPressed: () {
                launchURL(POW_URL);
              },
            ),
            SingleButton(
              title: t.app_info_screen.ask_to_telegram,
              leftElement: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  'assets/images/telegram-circle-logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
              onPressed: () {
                launchURL(TELEGRAM_POW);
              },
            ),
            SingleButton(
              title: t.app_info_screen.ask_to_x,
              leftElement: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  'assets/images/x-logo.jpg',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
              onPressed: () {
                launchURL(X_POW);
              },
            ),
            SingleButton(
                title: t.app_info_screen.ask_to_email,
                leftElement: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.asset(
                    'assets/images/mail-icon.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                  ),
                ),
                onPressed: () async {
                  String info = await _getDeviceInfo(_packageInfoFuture);
                  final Uri params = Uri(
                      scheme: 'mailto',
                      path: CONTACT_EMAIL_ADDRESS,
                      query: 'subject=${t.email_subject}&body=$info');

                  launchURL(params.toString());
                }),
          ]),
        ],
      ),
    );
  }

  Widget githubWidget() {
    Widget githubLogo = SvgPicture.asset(
      'assets/svg/github-logo-white.svg',
      width: 24,
      height: 24,
      fit: BoxFit.cover,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: const BoxDecoration(
        color: MyColors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _category(t.app_info_screen.category2_opensource),
          ButtonGroup(buttons: [
            SingleButton(
              title: t.coconut_lib,
              leftElement: githubLogo,
              onPressed: () {
                launchURL(GITHUB_URL_COCONUT_LIBRARY);
              },
            ),
            SingleButton(
              title: t.coconut_wallet,
              leftElement: githubLogo,
              onPressed: () {
                launchURL(GITHUB_URL_WALLET);
              },
            ),
            SingleButton(
              title: t.coconut_vault,
              leftElement: githubLogo,
              onPressed: () {
                launchURL(GITHUB_URL_VAULT);
              },
            ),
            SingleButton(
              title: t.app_info_screen.license,
              onPressed: () {
                CommonBottomSheets.showBottomSheet_95(
                    context: context, child: const LicenseBottomSheet());
              },
            ),
            SingleButton(
              title: t.app_info_screen.contribution,
              onPressed: () {
                launchURL(CONTRIBUTING_URL);
              },
            )
          ]),
        ],
      ),
    );
  }

  Widget footerWidget(Future<PackageInfo> packageInfoFuture) {
    return FutureBuilder<PackageInfo>(
        future: packageInfoFuture,
        builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
              color: MyColors.white,
            ));
          } else if (snapshot.hasError) {
            return Center(child: Text(t.errors.data_loading_failed));
          } else if (!snapshot.hasData) {
            return Center(child: Text(t.errors.data_not_found));
          }

          PackageInfo packageInfo = snapshot.data!;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 50),
            color: MyColors.transparentWhite_06,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      t.app_info_screen.version_and_date(
                          version: packageInfo.version,
                          releasedAt: RELEASE_DATE),
                      style: Styles.body2.merge(
                        const TextStyle(
                          color: MyColors.transparentWhite_50,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () => launchURL(LICENSE_URL, defaultMode: true),
                    child: Text(
                      COPYRIGHT_TEXT,
                      style: Styles.body2.merge(
                        const TextStyle(
                          color: MyColors.transparentWhite_50,
                          decoration: TextDecoration.underline,
                          decorationColor: MyColors.transparentWhite_30,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          );
        });
  }

  Widget _category(String label) => Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 0, 12),
      child: Text(label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            color: Colors.white,
            fontSize: 16,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.bold,
          )));
}
