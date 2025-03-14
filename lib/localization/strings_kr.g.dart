///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsKr = Translations; // ignore: unused_element

class Translations implements BaseTranslations<AppLocale, Translations> {
  /// Returns the current translations of the given [context].
  ///
  /// Usage:
  /// final t = Translations.of(context);
  static Translations of(BuildContext context) =>
      InheritedLocaleData.of<AppLocale, Translations>(context).translations;

  /// You can call this constructor and build your own translation instance of this locale.
  /// Constructing via the enum [AppLocale.build] is preferred.
  Translations(
      {Map<String, Node>? overrides,
      PluralResolver? cardinalResolver,
      PluralResolver? ordinalResolver})
      : assert(overrides == null,
            'Set "translation_overrides: true" in order to enable this feature.'),
        $meta = TranslationMetadata(
          locale: AppLocale.kr,
          overrides: overrides ?? {},
          cardinalResolver: cardinalResolver,
          ordinalResolver: ordinalResolver,
        ) {
    $meta.setFlatMapFunction(_flatMapFunction);
  }

  /// Metadata for the translations of <kr>.
  @override
  final TranslationMetadata<AppLocale, Translations> $meta;

  /// Access flat map
  dynamic operator [](String key) => $meta.getTranslation(key);

  late final Translations _root = this; // ignore: unused_field

  // Translations
  String get coconut_wallet => 'coconut_wallet';
  String get coconut_vault => 'coconut_vault';
  String get coconut_lib => 'coconut_lib';
  String get wallet => 'Wallet';
  String get btc => 'BTC';
  String get sats => 'sats';
  String get testnet => '테스트넷';
  String get address => '주소';
  String get fee => '수수료';
  String get send => '보내기';
  String get receive => '받기';
  String get paste => '붙여넣기';
  String get export => '내보내기';
  String get edit => '편집';
  String get max => '최대';
  String get all => '전체';
  String get no => '아니오';
  String get delete => '삭제';
  String get complete => '완료';
  String get close => '닫기';
  String get next => '다음';
  String get modify => '변경';
  String get confirm => '확인';
  String get security => '보안';
  String get utxo => 'UTXO';
  String get tag => '태그';
  String get change => '잔돈';
  String get sign => '서명하기';
  String get glossary => '용어집';
  String get settings => '설정';
  String get tx_list => '거래 내역';
  String get utxo_list => 'UTXO 목록';
  String get wallet_id => '지갑 ID';
  String get tag_manage => '태그 관리';
  String get extended_public_key => '확장 공개키';
  String get tx_memo => '거래 메모';
  String get tx_id => '트랜잭션 ID';
  String get block_num => '블록 번호';
  String get inquiry_details => '문의 내용';
  String get utxo_total => 'UTXO 합계';
  String get recipient => '보낼 주소';
  String get estimated_fee => '예상 수수료';
  String get total_cost => '총 소요 수량';
  String get input_directly => '직접 입력';
  String get mnemonic_wordlist => '니모닉 문구 단어집';
  String get self_security_check => '셀프 보안 점검';
  String get app_info => '앱 정보';
  String get update_failed => '업데이트 실패';
  String get calculation_failed => '계산 실패';
  String get contact_email => 'hello@noncelab.com';
  String get email_subject => '[코코넛 월렛] 이용 관련 문의';
  String get send_amount => '보낼 수량';
  String get fetch_fee_failed => '수수료 조회 실패';
  String get fetch_balance_failed => '잔액 조회 불가';
  String get status_used => '사용됨';
  String get status_unused => '사용 전';
  String get status_receiving => '받는 중';
  String get status_received => '받기 완료';
  String get status_sending => '보내는 중';
  String get status_sent => '보내기 완료';
  String get status_updating => '업데이트 중';
  String get no_status => '상태 없음';
  String get quick_receive => '빨리 받기';
  String get quick_send => '빨리 보내기';
  String bitcoin_text({required Object bitcoin}) => '${bitcoin} BTC';
  String apply_item({required Object count}) => '${count}개에 적용';
  String fee_sats({required Object value}) => ' (${value} sats/vb)';
  String utxo_count({required Object count}) => '(${count}개)';
  String total_utxo_count({required Object count}) => '(총 ${count}개)';
  String get view_app_info => '앱 정보 보기';
  String get view_tx_details => '거래 자세히 보기';
  String get view_more => '더보기';
  String get view_mempool => '멤풀 보기';
  String get view_all_addresses => '전체 주소 보기';
  String get select_utxo => 'UTXO 고르기';
  String get select_all => '모두 선택';
  String get unselect_all => '모두 해제';
  String get delete_confirm => '삭제하기';
  String get sign_multisig => '다중 서명하기';
  String get forgot_password => '비밀번호가 기억나지 않나요?';
  String get tx_not_found => '거래 내역이 없어요';
  String get utxo_not_found => 'UTXO가 없어요';
  String get utxo_loading => 'UTXO를 확인하는 중이에요';
  String get faucet_request => '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.';
  String get faucet_already_request =>
      '해당 주소로 이미 요청했습니다. 입금까지 최대 5분이 걸릴 수 있습니다.';
  String get faucet_failed => '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
  String get bio_auth_required => '생체 인증을 진행해 주세요';
  late final TranslationsTransactionEnumsKr transaction_enums =
      TranslationsTransactionEnumsKr.internal(_root);
  late final TranslationsUtxoOrderEnumsKr utxo_order_enums =
      TranslationsUtxoOrderEnumsKr.internal(_root);
  late final TranslationsPinCheckScreenKr pin_check_screen =
      TranslationsPinCheckScreenKr.internal(_root);
  late final TranslationsWalletAddScannerScreenKr wallet_add_scanner_screen =
      TranslationsWalletAddScannerScreenKr.internal(_root);
  late final TranslationsNegativeFeedbackScreenKr negative_feedback_screen =
      TranslationsNegativeFeedbackScreenKr.internal(_root);
  late final TranslationsPositiveFeedbackScreenKr positive_feedback_screen =
      TranslationsPositiveFeedbackScreenKr.internal(_root);
  late final TranslationsBroadcastingCompleteScreenKr
      broadcasting_complete_screen =
      TranslationsBroadcastingCompleteScreenKr.internal(_root);
  late final TranslationsBroadcastingScreenKr broadcasting_screen =
      TranslationsBroadcastingScreenKr.internal(_root);
  late final TranslationsSendAddressScreenKr send_address_screen =
      TranslationsSendAddressScreenKr.internal(_root);
  late final TranslationsSendConfirmScreenKr send_confirm_screen =
      TranslationsSendConfirmScreenKr.internal(_root);
  late final TranslationsSignedPsbtScannerScreenKr signed_psbt_scanner_screen =
      TranslationsSignedPsbtScannerScreenKr.internal(_root);
  late final TranslationsAppInfoScreenKr app_info_screen =
      TranslationsAppInfoScreenKr.internal(_root);
  late final TranslationsBip39ListScreenKr bip39_list_screen =
      TranslationsBip39ListScreenKr.internal(_root);
  late final TranslationsPinSettingScreenKr pin_setting_screen =
      TranslationsPinSettingScreenKr.internal(_root);
  late final TranslationsSettingsScreenKr settings_screen =
      TranslationsSettingsScreenKr.internal(_root);
  late final TranslationsAddressListScreenKr address_list_screen =
      TranslationsAddressListScreenKr.internal(_root);
  late final TranslationsUtxoListScreenKr utxo_list_screen =
      TranslationsUtxoListScreenKr.internal(_root);
  late final TranslationsTransactionDetailScreenKr transaction_detail_screen =
      TranslationsTransactionDetailScreenKr.internal(_root);
  late final TranslationsUtxoDetailScreenKr utxo_detail_screen =
      TranslationsUtxoDetailScreenKr.internal(_root);
  late final TranslationsUtxoTagScreenKr utxo_tag_screen =
      TranslationsUtxoTagScreenKr.internal(_root);
  late final TranslationsWalletInfoScreenKr wallet_info_screen =
      TranslationsWalletInfoScreenKr.internal(_root);
  late final TranslationsTransactionFeeBumpingScreenKr
      transaction_fee_bumping_screen =
      TranslationsTransactionFeeBumpingScreenKr.internal(_root);
  late final TranslationsWalletListAddGuideCardKr wallet_list_add_guide_card =
      TranslationsWalletListAddGuideCardKr.internal(_root);
  late final TranslationsWalletListTermsShortcutCardKr
      wallet_list_terms_shortcut_card =
      TranslationsWalletListTermsShortcutCardKr.internal(_root);
  late final TranslationsFaucetRequestBottomSheetKr
      faucet_request_bottom_sheet =
      TranslationsFaucetRequestBottomSheetKr.internal(_root);
  late final TranslationsLicenseBottomSheetKr license_bottom_sheet =
      TranslationsLicenseBottomSheetKr.internal(_root);
  late final TranslationsOnboardingBottomSheetKr onboarding_bottom_sheet =
      TranslationsOnboardingBottomSheetKr.internal(_root);
  late final TranslationsSecuritySelfCheckBottomSheetKr
      security_self_check_bottom_sheet =
      TranslationsSecuritySelfCheckBottomSheetKr.internal(_root);
  late final TranslationsTagBottomSheetKr tag_bottom_sheet =
      TranslationsTagBottomSheetKr.internal(_root);
  late final TranslationsTermsBottomSheetKr terms_bottom_sheet =
      TranslationsTermsBottomSheetKr.internal(_root);
  late final TranslationsUserExperienceSurveyBottomSheetKr
      user_experience_survey_bottom_sheet =
      TranslationsUserExperienceSurveyBottomSheetKr.internal(_root);
  late final TranslationsErrorsKr errors = TranslationsErrorsKr.internal(_root);
  late final TranslationsTextFieldKr text_field =
      TranslationsTextFieldKr.internal(_root);
  late final TranslationsTooltipKr tooltip =
      TranslationsTooltipKr.internal(_root);
  late final TranslationsSnackbarKr snackbar =
      TranslationsSnackbarKr.internal(_root);
  late final TranslationsToastKr toast = TranslationsToastKr.internal(_root);
  late final TranslationsAlertKr alert = TranslationsAlertKr.internal(_root);
}

// Path: transaction_enums
class TranslationsTransactionEnumsKr {
  TranslationsTransactionEnumsKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get high_priority => '빠른 전송';
  String get medium_priority => '보통 전송';
  String get low_priority => '느린 전송';
  String get expected_time_high_priority => '~10분';
  String get expected_time_medium_priority => '~30분';
  String get expected_time_low_priority => '~1시간';
}

// Path: utxo_order_enums
class TranslationsUtxoOrderEnumsKr {
  TranslationsUtxoOrderEnumsKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get amt_desc => '큰 금액순';
  String get amt_asc => '작은 금액순';
  String get time_desc => '최신순';
  String get time_asc => '오래된 순';
}

// Path: pin_check_screen
class TranslationsPinCheckScreenKr {
  TranslationsPinCheckScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text => '비밀번호를 눌러주세요';
}

// Path: wallet_add_scanner_screen
class TranslationsWalletAddScannerScreenKr {
  TranslationsWalletAddScannerScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text => '보기 전용 지갑 추가';
}

// Path: negative_feedback_screen
class TranslationsNegativeFeedbackScreenKr {
  TranslationsNegativeFeedbackScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '죄송합니다😭';
  String get text2 => '불편한 점이나 개선사항을 저희에게 알려주세요!';
  String get text3 => '1:1 메시지 보내기';
  String get text4 => '다음에 할게요';
}

// Path: positive_feedback_screen
class TranslationsPositiveFeedbackScreenKr {
  TranslationsPositiveFeedbackScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '감사합니다🥰';
  String get text2 => '그렇다면 스토어에 리뷰를 남겨주시겠어요?';
  String get text3 => '물론이죠';
  String get text4 => '다음에 할게요';
}

// Path: broadcasting_complete_screen
class TranslationsBroadcastingCompleteScreenKr {
  TranslationsBroadcastingCompleteScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get complete => '전송 요청 완료';
}

// Path: broadcasting_screen
class TranslationsBroadcastingScreenKr {
  TranslationsBroadcastingScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title => '최종 확인';
  String get description => '아래 정보로 송금할게요';
  String get self_sending => '내 지갑으로 보내는 트랜잭션입니다.';
}

// Path: send_address_screen
class TranslationsSendAddressScreenKr {
  TranslationsSendAddressScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text => 'QR을 스캔하거나\n복사한 주소를 붙여넣어 주세요';
}

// Path: send_confirm_screen
class TranslationsSendConfirmScreenKr {
  TranslationsSendConfirmScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title => '입력 정보 확인';
}

// Path: signed_psbt_scanner_screen
class TranslationsSignedPsbtScannerScreenKr {
  TranslationsSignedPsbtScannerScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title => '서명 트랜잭션 읽기';
}

// Path: app_info_screen
class TranslationsAppInfoScreenKr {
  TranslationsAppInfoScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get made_by_team_pow => '포우팀이 만듭니다.';
  String get category1_ask => '궁금한 점이 있으신가요?';
  String get go_to_pow => 'POW 커뮤니티 바로가기';
  String get ask_to_telegram => '텔레그램 채널로 문의하기';
  String get ask_to_x => 'X로 문의하기';
  String get ask_to_email => '이메일로 문의하기';
  String get category2_opensource => 'Coconut Wallet은 오픈소스입니다';
  String get license => '라이선스 안내';
  String get contribution => '오픈소스 개발 참여하기';
  String version_and_date(
          {required Object version, required Object releasedAt}) =>
      'CoconutWallet ver. ${version} (released at ${releasedAt})';
  String get inquiry => '문의 내용';
}

// Path: bip39_list_screen
class TranslationsBip39ListScreenKr {
  TranslationsBip39ListScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String result({required Object text}) => '\'${text}\' 검색 결과';
  String get no_result => '검색 결과가 없어요';
}

// Path: pin_setting_screen
class TranslationsPinSettingScreenKr {
  TranslationsPinSettingScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get new_password => '새로운 비밀번호를 눌러주세요';
  String get enter_again => '다시 한번 확인할게요';
}

// Path: settings_screen
class TranslationsSettingsScreenKr {
  TranslationsSettingsScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get set_password => '비밀번호 설정하기';
  String get use_biometric => '생체 인증 사용하기';
  String get change_password => '비밀번호 바꾸기';
  String get hide_balance => '홈 화면 잔액 숨기기';
}

// Path: address_list_screen
class TranslationsAddressListScreenKr {
  TranslationsAddressListScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String wallet_name({required Object name}) => '${name}의 주소';
  String address_index({required Object index}) => '주소 - ${index}';
  String get receiving => '입금';
  String get change => '잔돈';
}

// Path: utxo_list_screen
class TranslationsUtxoListScreenKr {
  TranslationsUtxoListScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get total_balance => '총 잔액';
}

// Path: transaction_detail_screen
class TranslationsTransactionDetailScreenKr {
  TranslationsTransactionDetailScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String confirmation({required Object height, required Object count}) =>
      '${height} (${count}승인)';
}

// Path: utxo_detail_screen
class TranslationsUtxoDetailScreenKr {
  TranslationsUtxoDetailScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get pending => '승인 대기중';
  String get address => '보유 주소';
}

// Path: utxo_tag_screen
class TranslationsUtxoTagScreenKr {
  TranslationsUtxoTagScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get no_such_tag => '태그가 없어요';
  String get add_tag => '+ 버튼을 눌러 태그를 추가해 보세요';
}

// Path: wallet_info_screen
class TranslationsWalletInfoScreenKr {
  TranslationsWalletInfoScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String title({required Object name}) => '${name} 정보';
  String get view_xpub => '확장 공개키 보기';
}

// Path: transaction_fee_bumping_screen
class TranslationsTransactionFeeBumpingScreenKr {
  TranslationsTransactionFeeBumpingScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get rbf => 'RBF';
  String get cpfp => 'CPFP';
  String get existing_fee => '기존 수수료';
  String existing_fee_value({required Object value}) => '${value} sats/vb';
  String total_fee({required Object fee, required Object vb}) =>
      '총 ${fee} sats / ${vb} vb';
  String get new_fee => '새 수수료';
  String get sats_vb => 'sats/vb';
  String recommend_fee({required Object fee}) => '추천 수수료: ${fee}sats/vb 이상';
  String get recommend_fee_info_rbf =>
      '기존 수수료 보다 1 sat/vb 이상 커야해요.\n하지만, (기존 수수료 + 1)값이 느린 전송 수수료 보다 작다면 느린 전송 수수료를 추천해요.';
  String get recommend_fee_info_cpfp =>
      '새로운 거래로 부족한 수수료를 보충해야 해요.\n • 새 거래의 크기 = {newTxSize} vb, 추천 수수료율 = {recommendedFeeRate} sat/vb\n • 필요한 총 수수료 = ({originalTxSize} + {newTxSize}) × {recommendedFeeRate} = {totalRequiredFee} sat\n • 새 거래의 수수료 = {totalRequiredFee} - {originalFee} = {newTxFee} sat\n • 새 거래의 수수료율 = {newTxFee} ÷ {newTxSize} {inequalitySign} {newTxFeeRate} sat/vb';
  String get current_fee => '현재 수수료';
  String estimated_fee({required Object fee}) => '예상 총 수수료 ${fee} sats';
  String get estimated_fee_too_high_error => '예상 총 수수료가 0.01 BTC 이상이에요!';
  String get recommended_fees_fetch_error => '추천 수수료를 조회할 수 없어요!';
}

// Path: wallet_list_add_guide_card
class TranslationsWalletListAddGuideCardKr {
  TranslationsWalletListAddGuideCardKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get add_watch_only => '보기 전용 지갑을 추가해 주세요';
  String get top_right_icon => '오른쪽 위 + 버튼을 눌러도 추가할 수 있어요';
  String get btn_add => '바로 추가하기';
}

// Path: wallet_list_terms_shortcut_card
class TranslationsWalletListTermsShortcutCardKr {
  TranslationsWalletListTermsShortcutCardKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get any_terms_you_dont_know => '모르는 용어가 있으신가요?';
  String get top_right => '오른쪽 위 ';
  String get click_to_jump => ' - 용어집 또는 여기를 눌러 바로가기';
}

// Path: faucet_request_bottom_sheet
class TranslationsFaucetRequestBottomSheetKr {
  TranslationsFaucetRequestBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title => '테스트 비트코인 받기';
  String get recipient => '받을 주소';
  String get placeholder => '주소를 입력해 주세요.\n주소는 [받기] 버튼을 눌러서 확인할 수 있어요.';
  String my_address({required Object name, required Object index}) =>
      '내 지갑(${name}) 주소 - ${index}';
  String get requesting => '요청 중...';
  String request_amount({required Object bitcoin}) => '${bitcoin} BTC 요청하기';
}

// Path: license_bottom_sheet
class TranslationsLicenseBottomSheetKr {
  TranslationsLicenseBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title => '라이선스 안내';
  String get coconut_wallet => 'Coconut Wallet';
  String get copyright_text1 =>
      '코코넛 월렛은 MIT 라이선스를 따르며 저작권은 대한민국의 논스랩 주식회사에 있습니다. MIT 라이선스 전문은 ';
  String get copyright_text2 =>
      '에서 확인해 주세요.\n\n이 애플리케이션에 포함된 타사 소프트웨어에 대한 저작권을 다음과 같이 명시합니다. 이에 대해 궁금한 사항이 있으시면 ';
  String get copyright_text3 => '으로 문의해 주시기 바랍니다.';
  String get email_subject => '[월렛] 라이선스 문의';
}

// Path: onboarding_bottom_sheet
class TranslationsOnboardingBottomSheetKr {
  TranslationsOnboardingBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get skip => '건너뛰기 |';
  String get when_need_help => '사용하시다 도움이 필요할 때';
  String get guide_btn => '튜토리얼 안내 버튼';
  String get press => '을 눌러주세요';
}

// Path: security_self_check_bottom_sheet
class TranslationsSecuritySelfCheckBottomSheetKr {
  TranslationsSecuritySelfCheckBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get check1 => '나의 개인키는 내가 스스로 책임집니다.';
  String get check2 => '니모닉 문구 화면을 캡처하거나 촬영하지 않습니다.';
  String get check3 => '니모닉 문구를 네트워크와 연결된 환경에 저장하지 않습니다.';
  String get check4 => '니모닉 문구의 순서와 단어의 철자를 확인합니다.';
  String get check5 => '패스프레이즈에 혹시 의도하지 않은 문자가 포함되지는 않았는지 한번 더 확인합니다.';
  String get check6 => '니모닉 문구와 패스프레이즈는 아무도 없는 안전한 곳에서 확인합니다.';
  String get check7 => '니모닉 문구와 패스프레이즈를 함께 보관하지 않습니다.';
  String get check8 => '소액으로 보내기 테스트를 한 후 지갑 사용을 시작합니다.';
  String get check9 => '위 사항을 주기적으로 점검하고, 안전하게 니모닉 문구를 보관하겠습니다.';
  String get guidance => '아래 자가 점검 항목을 숙지하고 니모닉 문구를 반드시 안전하게 보관합니다.';
}

// Path: tag_bottom_sheet
class TranslationsTagBottomSheetKr {
  TranslationsTagBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title_new_tag => '새 태그';
  String get title_edit_tag => '태그 편집';
  String get add_new_tag => '새 태그 만들기';
  String get max_tag_count => '태그는 최대 5개 지정할 수 있어요';
}

// Path: terms_bottom_sheet
class TranslationsTermsBottomSheetKr {
  TranslationsTermsBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get ask_to_pow => '포우에 물어보기';
  String get ask_to_telegram => '텔레그램에 물어보기';
  String get synonym => '같은 용어';
  String get related_terms => '관련 용어';
}

// Path: user_experience_survey_bottom_sheet
class TranslationsUserExperienceSurveyBottomSheetKr {
  TranslationsUserExperienceSurveyBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '비트코인 전송을 완료하셨군요👍';
  String get text2 => '코코넛 월렛이 도움이 되었나요?';
  String get text3 => '네, 좋아요!';
  String get text4 => '그냥 그래요';
}

// Path: errors
class TranslationsErrorsKr {
  TranslationsErrorsKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get storage_read_error => '저장소에서 데이터를 불러오는데 실패했습니다.';
  String get storage_write_error => '저장소에 데이터를 저장하는데 실패했습니다.';
  String get network_error => '네트워크에 연결할 수 없어요. 연결 상태를 확인해 주세요.';
  String get node_connection_error => '비트코인 노드와 연결하는데 실패했습니다.';
  String get fetch_wallet_error => '지갑을 가져오는데 실패했습니다.';
  String get wallet_sync_failed_error => '네트워크에서 지갑 정보 불러오기 실패';
  String get fetch_balance_error => '잔액 조회를 실패했습니다.';
  String get fetch_transaction_list_error => '트랜잭션 목록 조회를 실패했습니다.';
  String get fetch_transactions_error => '거래 내역을 가져오는데 실패했습니다.';
  String get database_path_error => 'DB 경로를 찾을 수 없습니다.';
  String get fee_estimation_error => '수수료 계산을 실패했습니다.';
  String get realm_unknown => '알 수 없는 오류가 발생했습니다.';
  String get realm_not_found => '데이터를 찾을 수 없습니다.';
  String get realm_exception => 'Realm 작업 중 오류가 발생했습니다.';
  String get node_unknown => '노드 연결 중 알 수 없는 오류가 발생했습니다.';
  String get network_connect => '네트워크 연결이 없습니다.';
  String get network_not_found => '네트워크가 연결되어 있지 않아요!';
  String get insufficient_balance => '잔액이 부족해요.';
  late final TranslationsErrorsFeeSelectionErrorKr fee_selection_error =
      TranslationsErrorsFeeSelectionErrorKr.internal(_root);
  late final TranslationsErrorsAddressErrorKr address_error =
      TranslationsErrorsAddressErrorKr.internal(_root);
  late final TranslationsErrorsPinCheckErrorKr pin_check_error =
      TranslationsErrorsPinCheckErrorKr.internal(_root);
  late final TranslationsErrorsPinSettingErrorKr pin_setting_error =
      TranslationsErrorsPinSettingErrorKr.internal(_root);
  String get data_loading_failed => '데이터를 불러오는 중 오류가 발생했습니다.';
  String get data_not_found => '데이터가 없습니다.';
}

// Path: text_field
class TranslationsTextFieldKr {
  TranslationsTextFieldKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get enter_fee_as_natural_number => '수수료를 자연수로 입력해 주세요.';
  String get enter_fee_directly => '직접 입력하기';
  String get search_mnemonic_word => '영문으로 검색해 보세요';
}

// Path: tooltip
class TranslationsTooltipKr {
  TranslationsTooltipKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get recommended_fee1 => '추천 수수료를 조회하지 못했어요. 수수료를 직접 입력해 주세요.';
  String recommended_fee2({required Object bitcoin}) =>
      '설정하신 수수료가 ${bitcoin} BTC 이상이에요.';
  String get wallet_add1 => '새로운 지갑을 추가하거나 이미 추가한 지갑의 정보를 업데이트할 수 있어요. ';
  String get wallet_add2 => '볼트';
  String get wallet_add3 => '에서 사용하시려는 지갑을 선택하고, ';
  String get wallet_add4 => '내보내기 ';
  String get wallet_add5 => '화면에 나타나는 QR 코드를 스캔해 주세요.';
  String amount_to_be_sent({required Object bitcoin}) =>
      '받기 완료된 비트코인만 전송 가능해요.\n받는 중인 금액: ${bitcoin} BTC';
  String get scan_signed_psbt =>
      '볼트 앱에서 생성된 서명 트랜잭션이 보이시나요? 이제, QR 코드를 스캔해 주세요.';
  late final TranslationsTooltipUnsignedTxQrKr unsigned_tx_qr =
      TranslationsTooltipUnsignedTxQrKr.internal(_root);
  String get address_receiving =>
      '비트코인을 받을 때 사용하는 주소예요. 영어로 Receiving 또는 External이라 해요.';
  String get address_change =>
      '다른 사람에게 비트코인을 보내고 남은 비트코인을 거슬러 받는 주소예요. 영어로 Change라 해요.';
  String get utxo =>
      'UTXO란 Unspent Tx Output을 줄인 말로 아직 쓰이지 않은 잔액이란 뜻이에요. 비트코인에는 잔액 개념이 없어요. 지갑에 표시되는 잔액은 UTXO의 총합이라는 것을 알아두세요.';
  String get faucet => '테스트용 비트코인으로 마음껏 테스트 해보세요';
  String multisig_wallet({required Object total, required Object count}) =>
      '${total}개의 키 중 ${count}개로 서명해야 하는\n다중 서명 지갑이에요.';
  String get mfp => '지갑의 고유 값이에요.\n마스터 핑거프린트(MFP)라고도 해요.';
  String get rbf => '수수료를 올려, 기존 거래를 새로운 거래로 대체하는 기능이에요. (RBF, Replace-By-Fee)';
  String get cpfp =>
      '새로운 거래(Child)에 높은 수수료를 지정해 기존 거래(Parent)가 빨리 처리되도록 우선순위를 높이는 기능이에요. (CPFP, Child-Pays-For-Parent)';
}

// Path: snackbar
class TranslationsSnackbarKr {
  TranslationsSnackbarKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get no_permission => 'no Permission';
}

// Path: toast
class TranslationsToastKr {
  TranslationsToastKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get back_exit => '뒤로 가기 버튼을 한 번 더 누르면 종료됩니다.';
  String min_fee({required Object minimum}) =>
      '현재 최소 수수료는 ${minimum} sats/vb 입니다.';
  String get fetching_onchain_data => '최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.';
  String get screen_capture => '스크린 캡처가 감지되었습니다.';
  String get no_balance => '잔액이 없습니다.';
  String get memo_update_failed => '메모를 업데이트하지 못했어요.';
  String get tag_add_failed => '태그를 추가하지 못했어요.';
  String get tag_update_failed => '태그를 편집할 수 없어요.';
  String get tag_delete_failed => '태그를 삭제할 수 없어요.';
  String get wallet_detail_refresh => '화면을 아래로 당겨 최신 데이터를 가져와 주세요.';
}

// Path: alert
class TranslationsAlertKr {
  TranslationsAlertKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  late final TranslationsAlertErrorTxKr error_tx =
      TranslationsAlertErrorTxKr.internal(_root);
  late final TranslationsAlertErrorSendKr error_send =
      TranslationsAlertErrorSendKr.internal(_root);
  late final TranslationsAlertSignedPsbtKr signed_psbt =
      TranslationsAlertSignedPsbtKr.internal(_root);
  String scan_failed({required Object error}) => '\'[스캔 실패] ${error}\'';
  String scan_failed_description({required Object error}) =>
      'QR코드 스캔에 실패했어요. 다시 시도해 주세요.\n${error}';
  late final TranslationsAlertTutorialKr tutorial =
      TranslationsAlertTutorialKr.internal(_root);
  late final TranslationsAlertForgotPasswordKr forgot_password =
      TranslationsAlertForgotPasswordKr.internal(_root);
  late final TranslationsAlertWalletAddKr wallet_add =
      TranslationsAlertWalletAddKr.internal(_root);
  late final TranslationsAlertWalletDeleteKr wallet_delete =
      TranslationsAlertWalletDeleteKr.internal(_root);
  late final TranslationsAlertUpdateKr update =
      TranslationsAlertUpdateKr.internal(_root);
  String get error_occurs => '오류 발생';
  String contact_admin({required Object error}) => '관리자에게 문의하세요. ${error}';
  late final TranslationsAlertTagApplyKr tag_apply =
      TranslationsAlertTagApplyKr.internal(_root);
  late final TranslationsAlertTxDetailKr tx_detail =
      TranslationsAlertTxDetailKr.internal(_root);
  late final TranslationsAlertTagDeleteKr tag_delete =
      TranslationsAlertTagDeleteKr.internal(_root);
  late final TranslationsAlertFaucetKr faucet =
      TranslationsAlertFaucetKr.internal(_root);
  late final TranslationsAlertFeeBumpingKr fee_bumping =
      TranslationsAlertFeeBumpingKr.internal(_root);
}

// Path: errors.fee_selection_error
class TranslationsErrorsFeeSelectionErrorKr {
  TranslationsErrorsFeeSelectionErrorKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get insufficient_balance => '잔액이 부족하여 수수료를 낼 수 없어요';
  String get recommended_fee_unavailable =>
      '추천 수수료를 조회하지 못했어요.\n\'변경\' 버튼을 눌러 수수료를 직접 입력해 주세요.';
  String get insufficient_utxo => 'UTXO 합계가 모자라요';
}

// Path: errors.address_error
class TranslationsErrorsAddressErrorKr {
  TranslationsErrorsAddressErrorKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get invalid => '올바른 주소가 아니에요.';
  String get not_for_testnet => '테스트넷 주소가 아니에요.';
  String get not_for_mainnet => '메인넷 주소가 아니에요.';
  String get not_for_regtest => '레그테스트넷 주소가 아니에요.';
}

// Path: errors.pin_check_error
class TranslationsErrorsPinCheckErrorKr {
  TranslationsErrorsPinCheckErrorKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String trial_count({required Object count}) => '${count}번 다시 시도할 수 있어요';
  String get failed => '더 이상 시도할 수 없어요\n앱을 종료해 주세요';
  String get incorrect => '비밀번호가 일치하지 않아요';
}

// Path: errors.pin_setting_error
class TranslationsErrorsPinSettingErrorKr {
  TranslationsErrorsPinSettingErrorKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get already_in_use => '이미 사용중인 비밀번호예요';
  String get process_failed => '처리 중 문제가 발생했어요';
  String get save_failed => '저장 중 문제가 발생했어요';
  String get incorrect => '비밀번호가 일치하지 않아요';
}

// Path: tooltip.unsigned_tx_qr
class TranslationsTooltipUnsignedTxQrKr {
  TranslationsTooltipUnsignedTxQrKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get in_vault => '볼트에서';
  String select_wallet({required Object name}) => '${name} 선택, ';
  String get scan_qr_below => '로 이동하여 아래 QR 코드를 스캔해 주세요.';
}

// Path: alert.error_tx
class TranslationsAlertErrorTxKr {
  TranslationsAlertErrorTxKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String not_parsed({required Object error}) => '트랜잭션 파싱 실패: ${error}';
  String not_created({required Object error}) => '트랜잭션 생성 실패 ${error}';
}

// Path: alert.error_send
class TranslationsAlertErrorSendKr {
  TranslationsAlertErrorSendKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String broadcasting_failed({required Object error}) => '[전송 실패]\n${error}';
  String get insufficient_balance => '잔액이 부족해요';
  String minimum_amount({required Object bitcoin}) =>
      '${bitcoin} BTC 부터 전송할 수 있어요';
  String get poor_network => '네트워크 상태가 좋지 않아\n처음으로 돌아갑니다.';
  String get insufficient_fee => '[전송 실패]\n수수료율을 높여서\n다시 시도해주세요.';
}

// Path: alert.signed_psbt
class TranslationsAlertSignedPsbtKr {
  TranslationsAlertSignedPsbtKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get invalid_qr => '잘못된 QR코드예요.\n다시 확인해 주세요.';
  String get wrong_send_info => '전송 정보가 달라요.\n처음부터 다시 시도해 주세요.';
  String need_more_sign({required Object count}) => '${count}개 서명이 더 필요해요';
  String get invalid_signature => '잘못된 서명 정보에요. 다시 시도해 주세요.';
}

// Path: alert.tutorial
class TranslationsAlertTutorialKr {
  TranslationsAlertTutorialKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title => '도움이 필요하신가요?';
  String get description => '튜토리얼 사이트로\n안내해 드릴게요';
  String get btn_view => '튜토리얼 보기';
}

// Path: alert.forgot_password
class TranslationsAlertForgotPasswordKr {
  TranslationsAlertForgotPasswordKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title => '비밀번호를 잊으셨나요?';
  String get description =>
      '[다시 설정]을 눌러 비밀번호를 초기화할 수 있어요. 비밀번호를 바꾸면 동기화된 지갑 목록이 초기화 돼요.';
  String get btn_reset => '다시 설정';
}

// Path: alert.wallet_add
class TranslationsAlertWalletAddKr {
  TranslationsAlertWalletAddKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get update_failed => '업데이트 실패';
  String update_failed_description({required Object name}) =>
      '${name}에 업데이트할 정보가 없어요';
  String get duplicate_name => '이름 중복';
  String get duplicate_name_description =>
      '같은 이름을 가진 지갑이 있습니다.\n이름을 변경한 후 동기화 해주세요.';
  String get add_failed => '보기 전용 지갑 추가 실패';
  String get add_failed_description => '잘못된 지갑 정보입니다.';
}

// Path: alert.wallet_delete
class TranslationsAlertWalletDeleteKr {
  TranslationsAlertWalletDeleteKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get confirm_delete => '지갑 삭제';
  String get confirm_delete_description => '지갑을 정말 삭제하시겠어요?';
}

// Path: alert.update
class TranslationsAlertUpdateKr {
  TranslationsAlertUpdateKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title => '업데이트 알림';
  String get description => '안정적인 서비스 이용을 위해\n최신 버전으로 업데이트 해주세요.';
  String get btn_update => '업데이트 하기';
  String get btn_do_later => '다음에 하기';
}

// Path: alert.tag_apply
class TranslationsAlertTagApplyKr {
  TranslationsAlertTagApplyKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title => '태그 적용';
  String get description => '기존 UTXO의 태그를 새 UTXO에도 적용하시겠어요?';
  String get btn_apply => '적용하기';
}

// Path: alert.tx_detail
class TranslationsAlertTxDetailKr {
  TranslationsAlertTxDetailKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get fetch_failed => '트랜잭션 가져오기 실패';
  String get fetch_failed_description => '잠시 후 다시 시도해 주세요';
}

// Path: alert.tag_delete
class TranslationsAlertTagDeleteKr {
  TranslationsAlertTagDeleteKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get title => '태그 삭제';
  String description({required Object name}) => '#${name}를 정말로 삭제하시겠어요?\n';
  String description_utxo_tag({required Object name, required Object count}) =>
      '${name}를 정말로 삭제하시겠어요?\n${count}개 UTXO에 적용되어 있어요.';
}

// Path: alert.faucet
class TranslationsAlertFaucetKr {
  TranslationsAlertFaucetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get no_test_bitcoin => '수도꼭지 단수 상태예요. 잠시 후 다시 시도해 주세요.';
  String get check_address => '올바른 주소인지 확인해 주세요';
  String try_again({required Object count}) => '${count} 후에 다시 시도해 주세요';
}

// Path: alert.fee_bumping
class TranslationsAlertFeeBumpingKr {
  TranslationsAlertFeeBumpingKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String not_enough_amount({required Object bumpingType}) =>
      '${bumpingType}를 실행하기에 충분한 잔액이 없습니다.\n현재 사용 가능한 잔액을 확인해 주세요.';
}

/// Flat map(s) containing all translations.
/// Only for edge cases! For simple maps, use the map function of this library.
extension on Translations {
  dynamic _flatMapFunction(String path) {
    switch (path) {
      case 'coconut_wallet':
        return 'coconut_wallet';
      case 'coconut_vault':
        return 'coconut_vault';
      case 'coconut_lib':
        return 'coconut_lib';
      case 'wallet':
        return 'Wallet';
      case 'btc':
        return 'BTC';
      case 'sats':
        return 'sats';
      case 'testnet':
        return '테스트넷';
      case 'address':
        return '주소';
      case 'fee':
        return '수수료';
      case 'send':
        return '보내기';
      case 'receive':
        return '받기';
      case 'paste':
        return '붙여넣기';
      case 'export':
        return '내보내기';
      case 'edit':
        return '편집';
      case 'max':
        return '최대';
      case 'all':
        return '전체';
      case 'no':
        return '아니오';
      case 'delete':
        return '삭제';
      case 'complete':
        return '완료';
      case 'close':
        return '닫기';
      case 'next':
        return '다음';
      case 'modify':
        return '변경';
      case 'confirm':
        return '확인';
      case 'security':
        return '보안';
      case 'utxo':
        return 'UTXO';
      case 'tag':
        return '태그';
      case 'change':
        return '잔돈';
      case 'sign':
        return '서명하기';
      case 'glossary':
        return '용어집';
      case 'settings':
        return '설정';
      case 'tx_list':
        return '거래 내역';
      case 'utxo_list':
        return 'UTXO 목록';
      case 'wallet_id':
        return '지갑 ID';
      case 'tag_manage':
        return '태그 관리';
      case 'extended_public_key':
        return '확장 공개키';
      case 'tx_memo':
        return '거래 메모';
      case 'tx_id':
        return '트랜잭션 ID';
      case 'block_num':
        return '블록 번호';
      case 'inquiry_details':
        return '문의 내용';
      case 'utxo_total':
        return 'UTXO 합계';
      case 'recipient':
        return '보낼 주소';
      case 'estimated_fee':
        return '예상 수수료';
      case 'total_cost':
        return '총 소요 수량';
      case 'input_directly':
        return '직접 입력';
      case 'mnemonic_wordlist':
        return '니모닉 문구 단어집';
      case 'self_security_check':
        return '셀프 보안 점검';
      case 'app_info':
        return '앱 정보';
      case 'update_failed':
        return '업데이트 실패';
      case 'calculation_failed':
        return '계산 실패';
      case 'contact_email':
        return 'hello@noncelab.com';
      case 'email_subject':
        return '[코코넛 월렛] 이용 관련 문의';
      case 'send_amount':
        return '보낼 수량';
      case 'fetch_fee_failed':
        return '수수료 조회 실패';
      case 'fetch_balance_failed':
        return '잔액 조회 불가';
      case 'status_used':
        return '사용됨';
      case 'status_unused':
        return '사용 전';
      case 'status_receiving':
        return '받는 중';
      case 'status_received':
        return '받기 완료';
      case 'status_sending':
        return '보내는 중';
      case 'status_sent':
        return '보내기 완료';
      case 'status_updating':
        return '업데이트 중';
      case 'no_status':
        return '상태 없음';
      case 'quick_receive':
        return '빨리 받기';
      case 'quick_send':
        return '빨리 보내기';
      case 'bitcoin_text':
        return ({required Object bitcoin}) => '${bitcoin} BTC';
      case 'apply_item':
        return ({required Object count}) => '${count}개에 적용';
      case 'fee_sats':
        return ({required Object value}) => ' (${value} sats/vb)';
      case 'utxo_count':
        return ({required Object count}) => '(${count}개)';
      case 'total_utxo_count':
        return ({required Object count}) => '(총 ${count}개)';
      case 'view_app_info':
        return '앱 정보 보기';
      case 'view_tx_details':
        return '거래 자세히 보기';
      case 'view_more':
        return '더보기';
      case 'view_mempool':
        return '멤풀 보기';
      case 'view_all_addresses':
        return '전체 주소 보기';
      case 'select_utxo':
        return 'UTXO 고르기';
      case 'select_all':
        return '모두 선택';
      case 'unselect_all':
        return '모두 해제';
      case 'delete_confirm':
        return '삭제하기';
      case 'sign_multisig':
        return '다중 서명하기';
      case 'forgot_password':
        return '비밀번호가 기억나지 않나요?';
      case 'tx_not_found':
        return '거래 내역이 없어요';
      case 'utxo_not_found':
        return 'UTXO가 없어요';
      case 'utxo_loading':
        return 'UTXO를 확인하는 중이에요';
      case 'faucet_request':
        return '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.';
      case 'faucet_already_request':
        return '해당 주소로 이미 요청했습니다. 입금까지 최대 5분이 걸릴 수 있습니다.';
      case 'faucet_failed':
        return '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      case 'bio_auth_required':
        return '생체 인증을 진행해 주세요';
      case 'transaction_enums.high_priority':
        return '빠른 전송';
      case 'transaction_enums.medium_priority':
        return '보통 전송';
      case 'transaction_enums.low_priority':
        return '느린 전송';
      case 'transaction_enums.expected_time_high_priority':
        return '~10분';
      case 'transaction_enums.expected_time_medium_priority':
        return '~30분';
      case 'transaction_enums.expected_time_low_priority':
        return '~1시간';
      case 'utxo_order_enums.amt_desc':
        return '큰 금액순';
      case 'utxo_order_enums.amt_asc':
        return '작은 금액순';
      case 'utxo_order_enums.time_desc':
        return '최신순';
      case 'utxo_order_enums.time_asc':
        return '오래된 순';
      case 'pin_check_screen.text':
        return '비밀번호를 눌러주세요';
      case 'wallet_add_scanner_screen.text':
        return '보기 전용 지갑 추가';
      case 'negative_feedback_screen.text1':
        return '죄송합니다😭';
      case 'negative_feedback_screen.text2':
        return '불편한 점이나 개선사항을 저희에게 알려주세요!';
      case 'negative_feedback_screen.text3':
        return '1:1 메시지 보내기';
      case 'negative_feedback_screen.text4':
        return '다음에 할게요';
      case 'positive_feedback_screen.text1':
        return '감사합니다🥰';
      case 'positive_feedback_screen.text2':
        return '그렇다면 스토어에 리뷰를 남겨주시겠어요?';
      case 'positive_feedback_screen.text3':
        return '물론이죠';
      case 'positive_feedback_screen.text4':
        return '다음에 할게요';
      case 'broadcasting_complete_screen.complete':
        return '전송 요청 완료';
      case 'broadcasting_screen.title':
        return '최종 확인';
      case 'broadcasting_screen.description':
        return '아래 정보로 송금할게요';
      case 'broadcasting_screen.self_sending':
        return '내 지갑으로 보내는 트랜잭션입니다.';
      case 'send_address_screen.text':
        return 'QR을 스캔하거나\n복사한 주소를 붙여넣어 주세요';
      case 'send_confirm_screen.title':
        return '입력 정보 확인';
      case 'signed_psbt_scanner_screen.title':
        return '서명 트랜잭션 읽기';
      case 'app_info_screen.made_by_team_pow':
        return '포우팀이 만듭니다.';
      case 'app_info_screen.category1_ask':
        return '궁금한 점이 있으신가요?';
      case 'app_info_screen.go_to_pow':
        return 'POW 커뮤니티 바로가기';
      case 'app_info_screen.ask_to_telegram':
        return '텔레그램 채널로 문의하기';
      case 'app_info_screen.ask_to_x':
        return 'X로 문의하기';
      case 'app_info_screen.ask_to_email':
        return '이메일로 문의하기';
      case 'app_info_screen.category2_opensource':
        return 'Coconut Wallet은 오픈소스입니다';
      case 'app_info_screen.license':
        return '라이선스 안내';
      case 'app_info_screen.contribution':
        return '오픈소스 개발 참여하기';
      case 'app_info_screen.version_and_date':
        return ({required Object version, required Object releasedAt}) =>
            'CoconutWallet ver. ${version} (released at ${releasedAt})';
      case 'app_info_screen.inquiry':
        return '문의 내용';
      case 'bip39_list_screen.result':
        return ({required Object text}) => '\'${text}\' 검색 결과';
      case 'bip39_list_screen.no_result':
        return '검색 결과가 없어요';
      case 'pin_setting_screen.new_password':
        return '새로운 비밀번호를 눌러주세요';
      case 'pin_setting_screen.enter_again':
        return '다시 한번 확인할게요';
      case 'settings_screen.set_password':
        return '비밀번호 설정하기';
      case 'settings_screen.use_biometric':
        return '생체 인증 사용하기';
      case 'settings_screen.change_password':
        return '비밀번호 바꾸기';
      case 'settings_screen.hide_balance':
        return '홈 화면 잔액 숨기기';
      case 'address_list_screen.wallet_name':
        return ({required Object name}) => '${name}의 주소';
      case 'address_list_screen.address_index':
        return ({required Object index}) => '주소 - ${index}';
      case 'address_list_screen.receiving':
        return '입금';
      case 'address_list_screen.change':
        return '잔돈';
      case 'utxo_list_screen.total_balance':
        return '총 잔액';
      case 'transaction_detail_screen.confirmation':
        return ({required Object height, required Object count}) =>
            '${height} (${count}승인)';
      case 'utxo_detail_screen.pending':
        return '승인 대기중';
      case 'utxo_detail_screen.address':
        return '보유 주소';
      case 'utxo_tag_screen.no_such_tag':
        return '태그가 없어요';
      case 'utxo_tag_screen.add_tag':
        return '+ 버튼을 눌러 태그를 추가해 보세요';
      case 'wallet_info_screen.title':
        return ({required Object name}) => '${name} 정보';
      case 'wallet_info_screen.view_xpub':
        return '확장 공개키 보기';
      case 'transaction_fee_bumping_screen.rbf':
        return 'RBF';
      case 'transaction_fee_bumping_screen.cpfp':
        return 'CPFP';
      case 'transaction_fee_bumping_screen.existing_fee':
        return '기존 수수료';
      case 'transaction_fee_bumping_screen.existing_fee_value':
        return ({required Object value}) => '${value} sats/vb';
      case 'transaction_fee_bumping_screen.total_fee':
        return ({required Object fee, required Object vb}) =>
            '총 ${fee} sats / ${vb} vb';
      case 'transaction_fee_bumping_screen.new_fee':
        return '새 수수료';
      case 'transaction_fee_bumping_screen.sats_vb':
        return 'sats/vb';
      case 'transaction_fee_bumping_screen.recommend_fee':
        return ({required Object fee}) => '추천 수수료: ${fee}sats/vb 이상';
      case 'transaction_fee_bumping_screen.recommend_fee_info_rbf':
        return '기존 수수료 보다 1 sat/vb 이상 커야해요.\n하지만, (기존 수수료 + 1)값이 느린 전송 수수료 보다 작다면 느린 전송 수수료를 추천해요.';
      case 'transaction_fee_bumping_screen.recommend_fee_info_cpfp':
        return '새로운 거래로 부족한 수수료를 보충해야 해요.\n • 새 거래의 크기 = {newTxSize} vb, 추천 수수료율 = {recommendedFeeRate} sat/vb\n • 필요한 총 수수료 = ({originalTxSize} + {newTxSize}) × {recommendedFeeRate} = {totalRequiredFee} sat\n • 새 거래의 수수료 = {totalRequiredFee} - {originalFee} = {newTxFee} sat\n • 새 거래의 수수료율 = {newTxFee} ÷ {newTxSize} {inequalitySign} {newTxFeeRate} sat/vb';
      case 'transaction_fee_bumping_screen.current_fee':
        return '현재 수수료';
      case 'transaction_fee_bumping_screen.estimated_fee':
        return ({required Object fee}) => '예상 총 수수료 ${fee} sats';
      case 'transaction_fee_bumping_screen.estimated_fee_too_high_error':
        return '예상 총 수수료가 0.01 BTC 이상이에요!';
      case 'transaction_fee_bumping_screen.recommended_fees_fetch_error':
        return '추천 수수료를 조회할 수 없어요!';
      case 'wallet_list_add_guide_card.add_watch_only':
        return '보기 전용 지갑을 추가해 주세요';
      case 'wallet_list_add_guide_card.top_right_icon':
        return '오른쪽 위 + 버튼을 눌러도 추가할 수 있어요';
      case 'wallet_list_add_guide_card.btn_add':
        return '바로 추가하기';
      case 'wallet_list_terms_shortcut_card.any_terms_you_dont_know':
        return '모르는 용어가 있으신가요?';
      case 'wallet_list_terms_shortcut_card.top_right':
        return '오른쪽 위 ';
      case 'wallet_list_terms_shortcut_card.click_to_jump':
        return ' - 용어집 또는 여기를 눌러 바로가기';
      case 'faucet_request_bottom_sheet.title':
        return '테스트 비트코인 받기';
      case 'faucet_request_bottom_sheet.recipient':
        return '받을 주소';
      case 'faucet_request_bottom_sheet.placeholder':
        return '주소를 입력해 주세요.\n주소는 [받기] 버튼을 눌러서 확인할 수 있어요.';
      case 'faucet_request_bottom_sheet.my_address':
        return ({required Object name, required Object index}) =>
            '내 지갑(${name}) 주소 - ${index}';
      case 'faucet_request_bottom_sheet.requesting':
        return '요청 중...';
      case 'faucet_request_bottom_sheet.request_amount':
        return ({required Object bitcoin}) => '${bitcoin} BTC 요청하기';
      case 'license_bottom_sheet.title':
        return '라이선스 안내';
      case 'license_bottom_sheet.coconut_wallet':
        return 'Coconut Wallet';
      case 'license_bottom_sheet.copyright_text1':
        return '코코넛 월렛은 MIT 라이선스를 따르며 저작권은 대한민국의 논스랩 주식회사에 있습니다. MIT 라이선스 전문은 ';
      case 'license_bottom_sheet.copyright_text2':
        return '에서 확인해 주세요.\n\n이 애플리케이션에 포함된 타사 소프트웨어에 대한 저작권을 다음과 같이 명시합니다. 이에 대해 궁금한 사항이 있으시면 ';
      case 'license_bottom_sheet.copyright_text3':
        return '으로 문의해 주시기 바랍니다.';
      case 'license_bottom_sheet.email_subject':
        return '[월렛] 라이선스 문의';
      case 'onboarding_bottom_sheet.skip':
        return '건너뛰기 |';
      case 'onboarding_bottom_sheet.when_need_help':
        return '사용하시다 도움이 필요할 때';
      case 'onboarding_bottom_sheet.guide_btn':
        return '튜토리얼 안내 버튼';
      case 'onboarding_bottom_sheet.press':
        return '을 눌러주세요';
      case 'security_self_check_bottom_sheet.check1':
        return '나의 개인키는 내가 스스로 책임집니다.';
      case 'security_self_check_bottom_sheet.check2':
        return '니모닉 문구 화면을 캡처하거나 촬영하지 않습니다.';
      case 'security_self_check_bottom_sheet.check3':
        return '니모닉 문구를 네트워크와 연결된 환경에 저장하지 않습니다.';
      case 'security_self_check_bottom_sheet.check4':
        return '니모닉 문구의 순서와 단어의 철자를 확인합니다.';
      case 'security_self_check_bottom_sheet.check5':
        return '패스프레이즈에 혹시 의도하지 않은 문자가 포함되지는 않았는지 한번 더 확인합니다.';
      case 'security_self_check_bottom_sheet.check6':
        return '니모닉 문구와 패스프레이즈는 아무도 없는 안전한 곳에서 확인합니다.';
      case 'security_self_check_bottom_sheet.check7':
        return '니모닉 문구와 패스프레이즈를 함께 보관하지 않습니다.';
      case 'security_self_check_bottom_sheet.check8':
        return '소액으로 보내기 테스트를 한 후 지갑 사용을 시작합니다.';
      case 'security_self_check_bottom_sheet.check9':
        return '위 사항을 주기적으로 점검하고, 안전하게 니모닉 문구를 보관하겠습니다.';
      case 'security_self_check_bottom_sheet.guidance':
        return '아래 자가 점검 항목을 숙지하고 니모닉 문구를 반드시 안전하게 보관합니다.';
      case 'tag_bottom_sheet.title_new_tag':
        return '새 태그';
      case 'tag_bottom_sheet.title_edit_tag':
        return '태그 편집';
      case 'tag_bottom_sheet.add_new_tag':
        return '새 태그 만들기';
      case 'tag_bottom_sheet.max_tag_count':
        return '태그는 최대 5개 지정할 수 있어요';
      case 'terms_bottom_sheet.ask_to_pow':
        return '포우에 물어보기';
      case 'terms_bottom_sheet.ask_to_telegram':
        return '텔레그램에 물어보기';
      case 'terms_bottom_sheet.synonym':
        return '같은 용어';
      case 'terms_bottom_sheet.related_terms':
        return '관련 용어';
      case 'user_experience_survey_bottom_sheet.text1':
        return '비트코인 전송을 완료하셨군요👍';
      case 'user_experience_survey_bottom_sheet.text2':
        return '코코넛 월렛이 도움이 되었나요?';
      case 'user_experience_survey_bottom_sheet.text3':
        return '네, 좋아요!';
      case 'user_experience_survey_bottom_sheet.text4':
        return '그냥 그래요';
      case 'errors.storage_read_error':
        return '저장소에서 데이터를 불러오는데 실패했습니다.';
      case 'errors.storage_write_error':
        return '저장소에 데이터를 저장하는데 실패했습니다.';
      case 'errors.network_error':
        return '네트워크에 연결할 수 없어요. 연결 상태를 확인해 주세요.';
      case 'errors.node_connection_error':
        return '비트코인 노드와 연결하는데 실패했습니다.';
      case 'errors.fetch_wallet_error':
        return '지갑을 가져오는데 실패했습니다.';
      case 'errors.wallet_sync_failed_error':
        return '네트워크에서 지갑 정보 불러오기 실패';
      case 'errors.fetch_balance_error':
        return '잔액 조회를 실패했습니다.';
      case 'errors.fetch_transaction_list_error':
        return '트랜잭션 목록 조회를 실패했습니다.';
      case 'errors.fetch_transactions_error':
        return '거래 내역을 가져오는데 실패했습니다.';
      case 'errors.database_path_error':
        return 'DB 경로를 찾을 수 없습니다.';
      case 'errors.fee_estimation_error':
        return '수수료 계산을 실패했습니다.';
      case 'errors.realm_unknown':
        return '알 수 없는 오류가 발생했습니다.';
      case 'errors.realm_not_found':
        return '데이터를 찾을 수 없습니다.';
      case 'errors.realm_exception':
        return 'Realm 작업 중 오류가 발생했습니다.';
      case 'errors.node_unknown':
        return '노드 연결 중 알 수 없는 오류가 발생했습니다.';
      case 'errors.network_connect':
        return '네트워크 연결이 없습니다.';
      case 'errors.network_not_found':
        return '네트워크가 연결되어 있지 않아요!';
      case 'errors.insufficient_balance':
        return '잔액이 부족해요.';
      case 'errors.fee_selection_error.insufficient_balance':
        return '잔액이 부족하여 수수료를 낼 수 없어요';
      case 'errors.fee_selection_error.recommended_fee_unavailable':
        return '추천 수수료를 조회하지 못했어요.\n\'변경\' 버튼을 눌러 수수료를 직접 입력해 주세요.';
      case 'errors.fee_selection_error.insufficient_utxo':
        return 'UTXO 합계가 모자라요';
      case 'errors.address_error.invalid':
        return '올바른 주소가 아니에요.';
      case 'errors.address_error.not_for_testnet':
        return '테스트넷 주소가 아니에요.';
      case 'errors.address_error.not_for_mainnet':
        return '메인넷 주소가 아니에요.';
      case 'errors.address_error.not_for_regtest':
        return '레그테스트넷 주소가 아니에요.';
      case 'errors.pin_check_error.trial_count':
        return ({required Object count}) => '${count}번 다시 시도할 수 있어요';
      case 'errors.pin_check_error.failed':
        return '더 이상 시도할 수 없어요\n앱을 종료해 주세요';
      case 'errors.pin_check_error.incorrect':
        return '비밀번호가 일치하지 않아요';
      case 'errors.pin_setting_error.already_in_use':
        return '이미 사용중인 비밀번호예요';
      case 'errors.pin_setting_error.process_failed':
        return '처리 중 문제가 발생했어요';
      case 'errors.pin_setting_error.save_failed':
        return '저장 중 문제가 발생했어요';
      case 'errors.pin_setting_error.incorrect':
        return '비밀번호가 일치하지 않아요';
      case 'errors.data_loading_failed':
        return '데이터를 불러오는 중 오류가 발생했습니다.';
      case 'errors.data_not_found':
        return '데이터가 없습니다.';
      case 'text_field.enter_fee_as_natural_number':
        return '수수료를 자연수로 입력해 주세요.';
      case 'text_field.enter_fee_directly':
        return '직접 입력하기';
      case 'text_field.search_mnemonic_word':
        return '영문으로 검색해 보세요';
      case 'tooltip.recommended_fee1':
        return '추천 수수료를 조회하지 못했어요. 수수료를 직접 입력해 주세요.';
      case 'tooltip.recommended_fee2':
        return ({required Object bitcoin}) => '설정하신 수수료가 ${bitcoin} BTC 이상이에요.';
      case 'tooltip.wallet_add1':
        return '새로운 지갑을 추가하거나 이미 추가한 지갑의 정보를 업데이트할 수 있어요. ';
      case 'tooltip.wallet_add2':
        return '볼트';
      case 'tooltip.wallet_add3':
        return '에서 사용하시려는 지갑을 선택하고, ';
      case 'tooltip.wallet_add4':
        return '내보내기 ';
      case 'tooltip.wallet_add5':
        return '화면에 나타나는 QR 코드를 스캔해 주세요.';
      case 'tooltip.amount_to_be_sent':
        return ({required Object bitcoin}) =>
            '받기 완료된 비트코인만 전송 가능해요.\n받는 중인 금액: ${bitcoin} BTC';
      case 'tooltip.scan_signed_psbt':
        return '볼트 앱에서 생성된 서명 트랜잭션이 보이시나요? 이제, QR 코드를 스캔해 주세요.';
      case 'tooltip.unsigned_tx_qr.in_vault':
        return '볼트에서';
      case 'tooltip.unsigned_tx_qr.select_wallet':
        return ({required Object name}) => '${name} 선택, ';
      case 'tooltip.unsigned_tx_qr.scan_qr_below':
        return '로 이동하여 아래 QR 코드를 스캔해 주세요.';
      case 'tooltip.address_receiving':
        return '비트코인을 받을 때 사용하는 주소예요. 영어로 Receiving 또는 External이라 해요.';
      case 'tooltip.address_change':
        return '다른 사람에게 비트코인을 보내고 남은 비트코인을 거슬러 받는 주소예요. 영어로 Change라 해요.';
      case 'tooltip.utxo':
        return 'UTXO란 Unspent Tx Output을 줄인 말로 아직 쓰이지 않은 잔액이란 뜻이에요. 비트코인에는 잔액 개념이 없어요. 지갑에 표시되는 잔액은 UTXO의 총합이라는 것을 알아두세요.';
      case 'tooltip.faucet':
        return '테스트용 비트코인으로 마음껏 테스트 해보세요';
      case 'tooltip.multisig_wallet':
        return ({required Object total, required Object count}) =>
            '${total}개의 키 중 ${count}개로 서명해야 하는\n다중 서명 지갑이에요.';
      case 'tooltip.mfp':
        return '지갑의 고유 값이에요.\n마스터 핑거프린트(MFP)라고도 해요.';
      case 'tooltip.rbf':
        return '수수료를 올려, 기존 거래를 새로운 거래로 대체하는 기능이에요. (RBF, Replace-By-Fee)';
      case 'tooltip.cpfp':
        return '새로운 거래(Child)에 높은 수수료를 지정해 기존 거래(Parent)가 빨리 처리되도록 우선순위를 높이는 기능이에요. (CPFP, Child-Pays-For-Parent)';
      case 'snackbar.no_permission':
        return 'no Permission';
      case 'toast.back_exit':
        return '뒤로 가기 버튼을 한 번 더 누르면 종료됩니다.';
      case 'toast.min_fee':
        return ({required Object minimum}) =>
            '현재 최소 수수료는 ${minimum} sats/vb 입니다.';
      case 'toast.fetching_onchain_data':
        return '최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.';
      case 'toast.screen_capture':
        return '스크린 캡처가 감지되었습니다.';
      case 'toast.no_balance':
        return '잔액이 없습니다.';
      case 'toast.memo_update_failed':
        return '메모를 업데이트하지 못했어요.';
      case 'toast.tag_add_failed':
        return '태그를 추가하지 못했어요.';
      case 'toast.tag_update_failed':
        return '태그를 편집할 수 없어요.';
      case 'toast.tag_delete_failed':
        return '태그를 삭제할 수 없어요.';
      case 'toast.wallet_detail_refresh':
        return '화면을 아래로 당겨 최신 데이터를 가져와 주세요.';
      case 'alert.error_tx.not_parsed':
        return ({required Object error}) => '트랜잭션 파싱 실패: ${error}';
      case 'alert.error_tx.not_created':
        return ({required Object error}) => '트랜잭션 생성 실패 ${error}';
      case 'alert.error_send.broadcasting_failed':
        return ({required Object error}) => '[전송 실패]\n${error}';
      case 'alert.error_send.insufficient_balance':
        return '잔액이 부족해요';
      case 'alert.error_send.minimum_amount':
        return ({required Object bitcoin}) => '${bitcoin} BTC 부터 전송할 수 있어요';
      case 'alert.error_send.poor_network':
        return '네트워크 상태가 좋지 않아\n처음으로 돌아갑니다.';
      case 'alert.error_send.insufficient_fee':
        return '[전송 실패]\n수수료율을 높여서\n다시 시도해주세요.';
      case 'alert.signed_psbt.invalid_qr':
        return '잘못된 QR코드예요.\n다시 확인해 주세요.';
      case 'alert.signed_psbt.wrong_send_info':
        return '전송 정보가 달라요.\n처음부터 다시 시도해 주세요.';
      case 'alert.signed_psbt.need_more_sign':
        return ({required Object count}) => '${count}개 서명이 더 필요해요';
      case 'alert.signed_psbt.invalid_signature':
        return '잘못된 서명 정보에요. 다시 시도해 주세요.';
      case 'alert.scan_failed':
        return ({required Object error}) => '\'[스캔 실패] ${error}\'';
      case 'alert.scan_failed_description':
        return ({required Object error}) =>
            'QR코드 스캔에 실패했어요. 다시 시도해 주세요.\n${error}';
      case 'alert.tutorial.title':
        return '도움이 필요하신가요?';
      case 'alert.tutorial.description':
        return '튜토리얼 사이트로\n안내해 드릴게요';
      case 'alert.tutorial.btn_view':
        return '튜토리얼 보기';
      case 'alert.forgot_password.title':
        return '비밀번호를 잊으셨나요?';
      case 'alert.forgot_password.description':
        return '[다시 설정]을 눌러 비밀번호를 초기화할 수 있어요. 비밀번호를 바꾸면 동기화된 지갑 목록이 초기화 돼요.';
      case 'alert.forgot_password.btn_reset':
        return '다시 설정';
      case 'alert.wallet_add.update_failed':
        return '업데이트 실패';
      case 'alert.wallet_add.update_failed_description':
        return ({required Object name}) => '${name}에 업데이트할 정보가 없어요';
      case 'alert.wallet_add.duplicate_name':
        return '이름 중복';
      case 'alert.wallet_add.duplicate_name_description':
        return '같은 이름을 가진 지갑이 있습니다.\n이름을 변경한 후 동기화 해주세요.';
      case 'alert.wallet_add.add_failed':
        return '보기 전용 지갑 추가 실패';
      case 'alert.wallet_add.add_failed_description':
        return '잘못된 지갑 정보입니다.';
      case 'alert.wallet_delete.confirm_delete':
        return '지갑 삭제';
      case 'alert.wallet_delete.confirm_delete_description':
        return '지갑을 정말 삭제하시겠어요?';
      case 'alert.update.title':
        return '업데이트 알림';
      case 'alert.update.description':
        return '안정적인 서비스 이용을 위해\n최신 버전으로 업데이트 해주세요.';
      case 'alert.update.btn_update':
        return '업데이트 하기';
      case 'alert.update.btn_do_later':
        return '다음에 하기';
      case 'alert.error_occurs':
        return '오류 발생';
      case 'alert.contact_admin':
        return ({required Object error}) => '관리자에게 문의하세요. ${error}';
      case 'alert.tag_apply.title':
        return '태그 적용';
      case 'alert.tag_apply.description':
        return '기존 UTXO의 태그를 새 UTXO에도 적용하시겠어요?';
      case 'alert.tag_apply.btn_apply':
        return '적용하기';
      case 'alert.tx_detail.fetch_failed':
        return '트랜잭션 가져오기 실패';
      case 'alert.tx_detail.fetch_failed_description':
        return '잠시 후 다시 시도해 주세요';
      case 'alert.tag_delete.title':
        return '태그 삭제';
      case 'alert.tag_delete.description':
        return ({required Object name}) => '#${name}를 정말로 삭제하시겠어요?\n';
      case 'alert.tag_delete.description_utxo_tag':
        return ({required Object name, required Object count}) =>
            '${name}를 정말로 삭제하시겠어요?\n${count}개 UTXO에 적용되어 있어요.';
      case 'alert.faucet.no_test_bitcoin':
        return '수도꼭지 단수 상태예요. 잠시 후 다시 시도해 주세요.';
      case 'alert.faucet.check_address':
        return '올바른 주소인지 확인해 주세요';
      case 'alert.faucet.try_again':
        return ({required Object count}) => '${count} 후에 다시 시도해 주세요';
      case 'alert.fee_bumping.not_enough_amount':
        return ({required Object bumpingType}) =>
            '${bumpingType}를 실행하기에 충분한 잔액이 없습니다.\n현재 사용 가능한 잔액을 확인해 주세요.';
      default:
        return null;
    }
  }
}
