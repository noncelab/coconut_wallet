import 'dart:io';
import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:coconut_wallet/constants/app_info.dart';
import 'package:coconut_wallet/screens/settings/app_info_license_bottom_sheet.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  late ScrollController _scrollController;
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: CoconutColors.black,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor:
            _isScrollOverTitleHeight ? CoconutColors.black.withOpacity(0.5) : CoconutColors.black,
        toolbarHeight: kToolbarHeight,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: SvgPicture.asset(
            'assets/svg/close.svg',
            colorFilter: ColorFilter.mode(
              CoconutColors.onPrimary(Brightness.dark),
              BlendMode.srcIn,
            ),
            width: 24,
            height: 24,
          ),
        ),
        flexibleSpace: _isScrollOverTitleHeight
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: CoconutColors.black.withOpacity(0.06)),
                ),
              )
            : null,
        title: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _appbarTitleVisible ? 1 : 0,
          child: Text(
            t.app_info,
            style: CoconutTypography.heading4_18.setColor(CoconutColors.white),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height / 2,
                color: CoconutColors.black,
              ),
              Container(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height / 2,
                color: CoconutColors.gray800,
              ),
            ],
          ),
          SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              controller: _scrollController,
              child: Container(
                color: CoconutColors.black,
                child: Column(
                  children: [
                    SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 30),
                    headerWidget(_packageInfoFuture),
                    CoconutLayout.spacing_400h,
                    coconutCrewWidget(),
                    CoconutLayout.spacing_400h,
                    socialMediaWidget(),
                    CoconutLayout.spacing_400h,
                    githubWidget(),
                    CoconutLayout.spacing_400h,
                    termsOfServiceWidget(),
                    CoconutLayout.spacing_1200h,
                    footerWidget(_packageInfoFuture),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget headerWidget(Future<PackageInfo> packageInfoFuture) {
    return FutureBuilder<PackageInfo>(
        future: packageInfoFuture,
        builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
              color: CoconutColors.white,
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
              color: CoconutColors.black,
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
                      color: CoconutColors.gray500,
                      width: 2.0,
                    ),
                    color: Colors.black,
                  ),
                  child: Image.asset(
                    'assets/images/splash_logo_${NetworkType.currentNetworkType.isTestnet ? "regtest" : "mainnet"}.png',
                  ),
                ),
                const SizedBox(
                  width: 30,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      child: Text(
                        packageInfo.appName,
                        style: CoconutTypography.heading3_21_Bold.setColor(CoconutColors.white),
                      ),
                    ),
                    Text('ver.${packageInfo.version}',
                        style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white)),
                    CoconutLayout.spacing_100h,
                    Text(t.app_info_screen.made_by_team_pow,
                        style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.gray400)),
                  ],
                )
              ],
            ),
          );
        });
  }

  Widget coconutCrewWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: ShrinkAnimationButton(
        defaultColor: CoconutColors.gray800,
        pressedColor: CoconutColors.gray750,
        onPressed: () {
          Navigator.pushNamed(context, '/coconut-crew');
        },
        borderRadius: CoconutStyles.radius_200,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Image.asset(
                'assets/images/laurel-wreath.png',
                width: 28,
                height: 28,
              ),
              CoconutLayout.spacing_300w,
              Text(
                t.app_info_screen.coconut_crew_genesis_member,
                style: CoconutTypography.body2_14_Bold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget socialMediaWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: const BoxDecoration(
        color: CoconutColors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _category(t.app_info_screen.category1_ask),
          ButtonGroup(buttons: [
            SingleButton(
              enableShrinkAnim: true,
              buttonPosition: SingleButtonPosition.top,
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
              enableShrinkAnim: true,
              buttonPosition: SingleButtonPosition.middle,
              title: t.app_info_screen.ask_to_discord,
              leftElement: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  'assets/images/discord-full-logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
              onPressed: () {
                launchURL(DISCORD_COCONUT);
              },
            ),
            SingleButton(
              enableShrinkAnim: true,
              buttonPosition: SingleButtonPosition.middle,
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
                enableShrinkAnim: true,
                buttonPosition: SingleButtonPosition.bottom,
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
        color: CoconutColors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _category(t.app_info_screen.category2_opensource),
          ButtonGroup(buttons: [
            SingleButton(
              enableShrinkAnim: true,
              buttonPosition: SingleButtonPosition.top,
              title: t.coconut_lib,
              leftElement: githubLogo,
              onPressed: () {
                launchURL(GITHUB_URL_COCONUT_LIBRARY);
              },
            ),
            SingleButton(
              enableShrinkAnim: true,
              buttonPosition: SingleButtonPosition.middle,
              title: t.coconut_wallet,
              leftElement: githubLogo,
              onPressed: () {
                launchURL(GITHUB_URL_WALLET);
              },
            ),
            SingleButton(
              enableShrinkAnim: true,
              buttonPosition: SingleButtonPosition.middle,
              title: t.coconut_vault,
              leftElement: githubLogo,
              onPressed: () {
                launchURL(GITHUB_URL_VAULT);
              },
            ),
            SingleButton(
              enableShrinkAnim: true,
              buttonPosition: SingleButtonPosition.bottom,
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

  Widget termsOfServiceWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: const BoxDecoration(
        color: CoconutColors.black,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _category(t.app_info_screen.tos_and_policy),
          ButtonGroup(buttons: [
            SingleButton(
              enableShrinkAnim: true,
              buttonPosition: SingleButtonPosition.top,
              title: t.app_info_screen.terms_of_service,
              onPressed: () {
                launchURL(TERMS_OF_SERVICE_URL);
              },
            ),
            SingleButton(
              enableShrinkAnim: true,
              buttonPosition: SingleButtonPosition.middle,
              title: t.app_info_screen.privacy_policy,
              onPressed: () {
                launchURL(PRIVACY_POLICY_URL);
              },
            ),
            SingleButton(
              enableShrinkAnim: true,
              buttonPosition: SingleButtonPosition.bottom,
              title: t.app_info_screen.license,
              onPressed: () {
                CommonBottomSheets.showBottomSheet_95(
                    context: context, child: const LicenseBottomSheet());
              },
            ),
            if (appFlavor == "mainnet")
              SingleButton(
                buttonPosition: SingleButtonPosition.bottom,
                title: t.app_info_screen.data_collection,
                onPressed: () {
                  launchURL(DATA_COLLECTION_URL);
                },
              ),
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
              color: CoconutColors.white,
            ));
          } else if (snapshot.hasError) {
            return Center(child: Text(t.errors.data_loading_failed));
          } else if (!snapshot.hasData) {
            return Center(child: Text(t.errors.data_not_found));
          }

          PackageInfo packageInfo = snapshot.data!;
          return Container(
            padding: const EdgeInsets.only(top: 20, bottom: 40),
            color: CoconutColors.gray800,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                        t.app_info_screen.version_and_date(
                            version: packageInfo.version, releasedAt: RELEASE_DATE),
                        style: CoconutTypography.body2_14.setColor(CoconutColors.gray300)),
                  ),
                ),
                CoconutLayout.spacing_200h,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () => launchURL(LICENSE_URL, defaultMode: true),
                    child: Text(
                      COPYRIGHT_TEXT,
                      style: CoconutTypography.body2_14.merge(
                        TextStyle(
                          decoration: TextDecoration.underline,
                          decorationColor: CoconutColors.white.withOpacity(0.3),
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
      child: Text(label, style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.gray300)));
}
