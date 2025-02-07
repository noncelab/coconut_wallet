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
  String get glossary => '용어집';
  String get confirm => '확인';
  String get close => '닫기';
  String get export => '내보내기';
  String get settings => '설정';
  String get fee => '수수료';
  String get address => '주소';
  String get paste => '붙여넣기';
  String get send => '보내기';
  String get receive => '받기';
  String get max => '최대';
  String get complete => '완료';
  String get all => '전체';
  String get no => '아니오';
  String get security => '보안';
  String get edit => '편집';
  String get utxo => 'UTXO';
  String get tag => '태그';
  String get delete => '삭제';
  String get next => '다음';
  String get modify => '변경';
  String get change => '잔돈';
  String get sign => '서명하기';
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
  String get send_address => '보낼 주소';
  String get estimated_fee => '예상 수수료';
  String get total_cost => '총 소요 수량';
  String get manual_input => '직접 입력';
  String get mnemonic_wordlist => '니모닉 문구 단어집';
  String get self_security => '셀프 보안 점검';
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
  String bitcoin_text({required Object bitcoin}) => '${bitcoin} BTC';
  String apply_item({required Object count}) => '${count}개에 적용';
  String fee_sats({required Object value}) => ' (${value} sats/vb)';
  String utxo_count({required Object count}) => '(${count}개)';
  String get view_app_info => '앱 정보 보기';
  String get view_tx_details => '거래 자세히 보기';
  String get view_more => '더보기';
  String get view_mempool => '멤풀 보기';
  String get view_all_address => '전체 주소 보기';
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
  String get bio_auth => '생체 인증을 진행해 주세요';
  late final TranslationsTransactionEnumsKr transaction_enums =
      TranslationsTransactionEnumsKr.internal(_root);
  late final TranslationsUtxoEnumsKr utxo_enums =
      TranslationsUtxoEnumsKr.internal(_root);
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
  late final TranslationsBroadcastingScreeKr broadcasting_scree =
      TranslationsBroadcastingScreeKr.internal(_root);
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
  late final TranslationsTransactionDetailScreenKr transaction_detail_screen =
      TranslationsTransactionDetailScreenKr.internal(_root);
  late final TranslationsUtxoDetailScreenKr utxo_detail_screen =
      TranslationsUtxoDetailScreenKr.internal(_root);
  late final TranslationsUtxoTagScreenKr utxo_tag_screen =
      TranslationsUtxoTagScreenKr.internal(_root);
  late final TranslationsWalletInfoScreenKr wallet_info_screen =
      TranslationsWalletInfoScreenKr.internal(_root);
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
  late final TranslationsErrorKr error = TranslationsErrorKr.internal(_root);
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
  String get speed1 => '빠른 전송';
  String get speed2 => '보통 전송';
  String get speed3 => '느린 전송';
  String get time1 => '~10분';
  String get time2 => '~30분';
  String get time3 => '~1시간';
}

// Path: utxo_enums
class TranslationsUtxoEnumsKr {
  TranslationsUtxoEnumsKr.internal(this._root);

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
  String get text1 => '전송 요청 완료';
  String get text2 => '트랜잭션 보기';
}

// Path: broadcasting_scree
class TranslationsBroadcastingScreeKr {
  TranslationsBroadcastingScreeKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '최종 확인';
  String get text2 => '아래 정보로 송금할게요';
  String get text3 => '내 지갑으로 보내는 트랜잭션입니다.';
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
  String get text => '입력 정보 확인';
}

// Path: signed_psbt_scanner_screen
class TranslationsSignedPsbtScannerScreenKr {
  TranslationsSignedPsbtScannerScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text => '서명 트랜잭션 읽기';
}

// Path: app_info_screen
class TranslationsAppInfoScreenKr {
  TranslationsAppInfoScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '포우팀이 만듭니다.';
  String get text2 => '궁금한 점이 있으신가요?';
  String get text3 => 'POW 커뮤니티 바로가기';
  String get text4 => '텔레그램 채널로 문의하기';
  String get text5 => 'X로 문의하기';
  String get text6 => '이메일로 문의하기';
  String get text7 => '라이선스 안내';
  String get text8 => '오픈소스 개발 참여하기';
}

// Path: bip39_list_screen
class TranslationsBip39ListScreenKr {
  TranslationsBip39ListScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String text1({required Object text}) => '\'${text}\' 검색 결과';
  String get text2 => '검색 결과가 없어요';
}

// Path: pin_setting_screen
class TranslationsPinSettingScreenKr {
  TranslationsPinSettingScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '새로운 비밀번호를 눌러주세요';
  String get text2 => '다시 한번 확인할게요';
}

// Path: settings_screen
class TranslationsSettingsScreenKr {
  TranslationsSettingsScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '비밀번호 설정하기';
  String get text2 => '생체 인증 사용하기';
  String get text3 => '비밀번호 바꾸기';
  String get text4 => '홈 화면 잔액 숨기기';
}

// Path: address_list_screen
class TranslationsAddressListScreenKr {
  TranslationsAddressListScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String text1({required Object name}) => '${name}의 주소';
  String text2({required Object index}) => '주소 - ${index}';
  String get text3 => '입금';
}

// Path: transaction_detail_screen
class TranslationsTransactionDetailScreenKr {
  TranslationsTransactionDetailScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String text({required Object height, required Object count}) =>
      '\'${height} (${count} 승인)\'';
}

// Path: utxo_detail_screen
class TranslationsUtxoDetailScreenKr {
  TranslationsUtxoDetailScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '승인 대기중';
  String get text2 => '보유 주소';
}

// Path: utxo_tag_screen
class TranslationsUtxoTagScreenKr {
  TranslationsUtxoTagScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '태그가 없어요';
  String get text2 => '+ 버튼을 눌러 태그를 추가해 보세요';
}

// Path: wallet_info_screen
class TranslationsWalletInfoScreenKr {
  TranslationsWalletInfoScreenKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String text1({required Object name}) => '${name} 정보';
  String get text2 => '확장 공개키 보기';
}

// Path: wallet_list_add_guide_card
class TranslationsWalletListAddGuideCardKr {
  TranslationsWalletListAddGuideCardKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '보기 전용 지갑을 추가해 주세요';
  String get text2 => '오른쪽 위 + 버튼을 눌러도 추가할 수 있어요';
  String get text3 => '바로 추가하기';
}

// Path: wallet_list_terms_shortcut_card
class TranslationsWalletListTermsShortcutCardKr {
  TranslationsWalletListTermsShortcutCardKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '모르는 용어가 있으신가요?';
  String get text2 => '오른쪽 위 ';
  String get text3 => ' - 용어집 또는 여기를 눌러 바로가기';
}

// Path: faucet_request_bottom_sheet
class TranslationsFaucetRequestBottomSheetKr {
  TranslationsFaucetRequestBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '주소를 입력해 주세요.\n주소는 [받기] 버튼을 눌러서 확인할 수 있어요.';
  String get text2 => '테스트 비트코인 받기';
  String text3({required Object name, required Object index}) =>
      '내 지갑(${name}) 주소 - ${index}';
  String get text4 => '요청 중...';
  String text5({required Object bitcoin}) => '${bitcoin} BTC 요청하기';
}

// Path: license_bottom_sheet
class TranslationsLicenseBottomSheetKr {
  TranslationsLicenseBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => 'Coconut Wallet';
  String get text2 => '라이선스 안내';
  String get text3 =>
      '코코넛 월렛은 MIT 라이선스를 따르며 저작권은 대한민국의 논스랩 주식회사에 있습니다. MIT 라이선스 전문은 ';
  String get text4 =>
      '에서 확인해 주세요.\n\n이 애플리케이션에 포함된 타사 소프트웨어에 대한 저작권을 다음과 같이 명시합니다. 이에 대해 궁금한 사항이 있으시면 ';
  String get text5 => '으로 문의해 주시기 바랍니다.';
}

// Path: onboarding_bottom_sheet
class TranslationsOnboardingBottomSheetKr {
  TranslationsOnboardingBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '건너뛰기 |';
  String get text2 => '사용하시다 도움이 필요할 때';
  String get text3 => '튜토리얼 안내 버튼';
  String get text4 => '을 눌러주세요';
}

// Path: security_self_check_bottom_sheet
class TranslationsSecuritySelfCheckBottomSheetKr {
  TranslationsSecuritySelfCheckBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '나의 개인키는 내가 스스로 책임집니다.';
  String get text2 => '니모닉 문구 화면을 캡처하거나 촬영하지 않습니다.';
  String get text3 => '니모닉 문구를 네트워크와 연결된 환경에 저장하지 않습니다.';
  String get text4 => '니모닉 문구의 순서와 단어의 철자를 확인합니다.';
  String get text5 => '패스프레이즈에 혹시 의도하지 않은 문자가 포함되지는 않았는지 한번 더 확인합니다.';
  String get text6 => '니모닉 문구와 패스프레이즈는 아무도 없는 안전한 곳에서 확인합니다.';
  String get text7 => '니모닉 문구와 패스프레이즈를 함께 보관하지 않습니다.';
  String get text8 => '소액으로 보내기 테스트를 한 후 지갑 사용을 시작합니다.';
  String get text9 => '위 사항을 주기적으로 점검하고, 안전하게 니모닉 문구를 보관하겠습니다.';
  String get text10 => '아래 점검 항목을 숙지하고 비트코인을 반드시 안전하게 보관합니다.';
}

// Path: tag_bottom_sheet
class TranslationsTagBottomSheetKr {
  TranslationsTagBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '새 태그';
  String get text2 => '태그 편집';
  String get text3 => '새 태그 만들기';
  String get toast => '태그는 최대 5개 지정할 수 있어요';
}

// Path: terms_bottom_sheet
class TranslationsTermsBottomSheetKr {
  TranslationsTermsBottomSheetKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get text1 => '포우에 물어보기';
  String get text2 => '텔레그램에 물어보기';
  String get text3 => '같은 용어';
  String get text4 => '관련 용어';
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

// Path: error
class TranslationsErrorKr {
  TranslationsErrorKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get app_1001 => '저장소에서 데이터를 불러오는데 실패했습니다.';
  String get app_1002 => '저장소에 데이터를 저장하는데 실패했습니다.';
  String get app_1003 => '네트워크에 연결할 수 없어요. 연결 상태를 확인해 주세요.';
  String get app_1004 => '비트코인 노드와 연결하는데 실패했습니다.';
  String get app_1005 => '지갑을 가져오는데 실패했습니다.';
  String get app_1006 => '네트워크에서 지갑 정보 불러오기 실패';
  String get app_1007 => '잔액 조회를 실패했습니다.';
  String get app_1008 => '트랜잭션 목록 조회를 실패했습니다.';
  String get app_1009 => '거래 내역을 가져오는데 실패했습니다.';
  String get app_1010 => 'DB 경로를 찾을 수 없습니다.';
  String get app_1100 => '수수료 계산을 실패했습니다.';
  String get app_1201 => '알 수 없는 오류가 발생했습니다.';
  String get app_1202 => '데이터를 찾을 수 없습니다.';
  String get app_1203 => 'Realm 작업 중 오류가 발생했습니다.';
  String get network_connect => '네트워크 연결이 없습니다.';
  String get low_balance => '잔액이 부족해요.';
  String get dio_cancel => '(요청취소)Request to the server was cancelled.';
  String get dio_connect => '(연결시간초과)Connection timed out.';
  String get dio_receive => '(수신시간초과)Receiving timeout occurred.';
  String get dio_send => '(요청시간초과)Request send timeout.';
  String get dio_unknown => 'Unexpected error occurred.';
  String get dio_default => 'Something went wrong';
  String get utxo1 => '잔액이 부족하여 수수료를 낼 수 없어요';
  String get utxo2 => 'UTXO 합계가 모자라요';
  String get utxo3 => '추천 수수료를 조회하지 못했어요.\n\'변경\'버튼을 눌러서 수수료를 직접 입력해 주세요.';
  String get address1 => '올바른 주소가 아니에요.';
  String get address2 => '테스트넷 주소가 아니에요.';
  String get address3 => '메인넷 주소가 아니에요.';
  String get address4 => '레그테스트넷 주소가 아니에요.';
  String pin_check1({required Object count}) => '${count}번 다시 시도할 수 있어요';
  String get pin_check2 => '더 이상 시도할 수 없어요\n앱을 종료해 주세요';
  String get pin_check3 => '비밀번호가 일치하지 않아요';
  String get pin_already_in_use => '이미 사용중인 비밀번호예요';
  String get pin_processing_failed => '처리 중 문제가 발생했어요';
  String get pin_saving_failed => '저장 중 문제가 발생했어요';
  String get pin_incorrect => '비밀번호가 일치하지 않아요';
  String get data_loading_failed => '데이터를 불러오는 중 오류가 발생했습니다.';
  String get data_not_found => '데이터가 없습니다.';
}

// Path: text_field
class TranslationsTextFieldKr {
  TranslationsTextFieldKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get fee => '수수료를 자연수로 입력해 주세요.';
  String get fee_btn => '직접 입력하기';
  String get mnemonic_hint => '영문으로 검색해 보세요';
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
  String send({required Object bitcoin}) =>
      '받기 완료된 비트코인만 전송 가능해요.\n받는 중인 금액: ${bitcoin} BTC';
  String get psbt => '볼트 앱에서 생성된 서명 트랜잭션이 보이시나요? 이제, QR 코드를 스캔해 주세요.';
  String get tx1 => '볼트에서';
  String tx2({required Object name}) => '${name} 선택, ';
  String get tx3 => '로 이동하여 아래 QR 코드를 스캔해 주세요.';
  String get address_external =>
      '비트코인을 받을 때 사용하는 주소예요. 영어로 Receiving 또는 External이라 해요.';
  String get address_change =>
      '다른 사람에게 비트코인을 보내고 남은 비트코인을 거슬러 받는 주소예요. 영어로 Change라 해요.';
  String get utxo =>
      'UTXO란 Unspent Tx Output을 줄인 말로 아직 쓰이지 않은 잔액이란 뜻이에요. 비트코인에는 잔액 개념이 없어요. 지갑에 표시되는 잔액은 UTXO의 총합이라는 것을 알아두세요.';
  String get faucet => '테스트용 비트코인으로 마음껏 테스트 해보세요';
  String multisig_wallet({required Object total, required Object count}) =>
      '${total}개의 키 중 ${count}개로 서명해야 하는\n다중 서명 지갑이에요.';
  String get mfp => '지갑의 고유 값이에요.\n마스터 핑거프린트(MFP)라고도 해요.';
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
  String get loading => '최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.';
  String get screen_capture => '스크린 캡처가 감지되었습니다.';
  String get no_balance => '잔액이 없습니다.';
  String get memo_update_failed => '메모 업데이트에 실패 했습니다.';
  String get tag_add_failed => '태그 추가에 실패 했습니다.';
  String get tag_update_failed => '태그 편집에 실패 했습니다.';
  String get tag_delete_failed => '태그 삭제에 실패 했습니다.';
  String get wallet_detail_refresh => '화면을 아래로 당겨 최신 데이터를 가져와 주세요.';
}

// Path: alert
class TranslationsAlertKr {
  TranslationsAlertKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String error_tx1({required Object error}) => '트랜잭션 파싱 실패: ${error}';
  String error_tx2({required Object error}) => '트랜잭션 생성 실패 ${error}';
  String error_send1({required Object error}) => '[전송 실패]\n${error}';
  String get error_send2 => '잔액이 부족해요';
  String error_send3({required Object bitcoin}) =>
      '${bitcoin} BTC 부터 전송할 수 있어요';
  String get error_send4 => '네트워크 상태가 좋지 않아\n처음으로 돌아갑니다.';
  String get error_sign1 => '잘못된 QR코드예요.\n다시 확인해 주세요.';
  String get error_sign2 => '전송 정보가 달라요.\n처음부터 다시 시도해 주세요.';
  String error_sign3({required Object count}) => '${count}개 서명이 더 필요해요';
  String get error_sign5 => '잘못된 서명 정보에요. 다시 시도해 주세요.';
  String error_scan1({required Object error}) => '\'[스캔 실패] ${error}\'';
  String error_scan2({required Object error}) =>
      'QR코드 스캔에 실패했어요. 다시 시도해 주세요.\n${error}';
  String get tutorial_title => '도움이 필요하신가요?';
  String get tutorial_msg => '튜토리얼 사이트로\n안내해 드릴게요';
  String get tutorial_btn => '튜토리얼 보기';
  String get pin1_title => '비밀번호를 잊으셨나요?';
  String get pin1_text =>
      '[다시 설정]을 눌러 비밀번호를 초기화할 수 있어요. 비밀번호를 바꾸면 동기화된 지갑 목록이 초기화 돼요.';
  String get pin1_btn => '다시 설정';
  String get wallet1_title => '업데이트 실패';
  String wallet1_text({required Object name}) => '${name}에 업데이트할 정보가 없어요';
  String get wallet2_title => '이름 중복';
  String get wallet2_text => '같은 이름을 가진 지갑이 있습니다.\n이름을 변경한 후 동기화 해주세요.';
  String get wallet3_title => '보기 전용 지갑 추가 실패';
  String get wallet3_text => '잘못된 지갑 정보입니다.';
  String get wallet4_title => '지갑 삭제';
  String get wallet5_text => '지갑을 정말 삭제하시겠어요?';
  String get app_title => '업데이트 알림';
  String get app_text => '안정적인 서비스 이용을 위해\n최신 버전으로 업데이트 해주세요.';
  String get app_btn1 => '업데이트 하기';
  String get app_btn2 => '다음에 하기';
  String get utxo1_title => '오류 발생';
  String utxo1_text({required Object error}) => '관리자에게 문의하세요. ${error}';
  String get utxo2_title => '태그 적용';
  String get utxo2_text => '기존 UTXO의 태그를 새 UTXO에도 적용하시겠어요?';
  String get utxo2_btn => '적용하기';
  String get tx_detail_title => '트랜잭션 가져오기 실패';
  String get tx_detail_text => '잠시 후 다시 시도해 주세요';
  String get tag_title => '태그 삭제';
  String tag_text1({required Object name}) => '#${name}를 정말로 삭제하시겠어요?\n';
  String tag_text2({required Object count}) => '${count}개  UTXO에 적용되어 있어요.';
  String get faucet1 => '올바른 주소인지 확인해 주세요';
  String faucet2({required Object count}) => '${count} 후에 다시 시도해 주세요';
}

/// Flat map(s) containing all translations.
/// Only for edge cases! For simple maps, use the map function of this library.
extension on Translations {
  dynamic _flatMapFunction(String path) {
    switch (path) {
      case 'glossary':
        return '용어집';
      case 'confirm':
        return '확인';
      case 'close':
        return '닫기';
      case 'export':
        return '내보내기';
      case 'settings':
        return '설정';
      case 'fee':
        return '수수료';
      case 'address':
        return '주소';
      case 'paste':
        return '붙여넣기';
      case 'send':
        return '보내기';
      case 'receive':
        return '받기';
      case 'max':
        return '최대';
      case 'complete':
        return '완료';
      case 'all':
        return '전체';
      case 'no':
        return '아니오';
      case 'security':
        return '보안';
      case 'edit':
        return '편집';
      case 'utxo':
        return 'UTXO';
      case 'tag':
        return '태그';
      case 'delete':
        return '삭제';
      case 'next':
        return '다음';
      case 'modify':
        return '변경';
      case 'change':
        return '잔돈';
      case 'sign':
        return '서명하기';
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
      case 'send_address':
        return '보낼 주소';
      case 'estimated_fee':
        return '예상 수수료';
      case 'total_cost':
        return '총 소요 수량';
      case 'manual_input':
        return '직접 입력';
      case 'mnemonic_wordlist':
        return '니모닉 문구 단어집';
      case 'self_security':
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
      case 'bitcoin_text':
        return ({required Object bitcoin}) => '${bitcoin} BTC';
      case 'apply_item':
        return ({required Object count}) => '${count}개에 적용';
      case 'fee_sats':
        return ({required Object value}) => ' (${value} sats/vb)';
      case 'utxo_count':
        return ({required Object count}) => '(${count}개)';
      case 'view_app_info':
        return '앱 정보 보기';
      case 'view_tx_details':
        return '거래 자세히 보기';
      case 'view_more':
        return '더보기';
      case 'view_mempool':
        return '멤풀 보기';
      case 'view_all_address':
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
      case 'bio_auth':
        return '생체 인증을 진행해 주세요';
      case 'transaction_enums.speed1':
        return '빠른 전송';
      case 'transaction_enums.speed2':
        return '보통 전송';
      case 'transaction_enums.speed3':
        return '느린 전송';
      case 'transaction_enums.time1':
        return '~10분';
      case 'transaction_enums.time2':
        return '~30분';
      case 'transaction_enums.time3':
        return '~1시간';
      case 'utxo_enums.amt_desc':
        return '큰 금액순';
      case 'utxo_enums.amt_asc':
        return '작은 금액순';
      case 'utxo_enums.time_desc':
        return '최신순';
      case 'utxo_enums.time_asc':
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
      case 'broadcasting_complete_screen.text1':
        return '전송 요청 완료';
      case 'broadcasting_complete_screen.text2':
        return '트랜잭션 보기';
      case 'broadcasting_scree.text1':
        return '최종 확인';
      case 'broadcasting_scree.text2':
        return '아래 정보로 송금할게요';
      case 'broadcasting_scree.text3':
        return '내 지갑으로 보내는 트랜잭션입니다.';
      case 'send_address_screen.text':
        return 'QR을 스캔하거나\n복사한 주소를 붙여넣어 주세요';
      case 'send_confirm_screen.text':
        return '입력 정보 확인';
      case 'signed_psbt_scanner_screen.text':
        return '서명 트랜잭션 읽기';
      case 'app_info_screen.text1':
        return '포우팀이 만듭니다.';
      case 'app_info_screen.text2':
        return '궁금한 점이 있으신가요?';
      case 'app_info_screen.text3':
        return 'POW 커뮤니티 바로가기';
      case 'app_info_screen.text4':
        return '텔레그램 채널로 문의하기';
      case 'app_info_screen.text5':
        return 'X로 문의하기';
      case 'app_info_screen.text6':
        return '이메일로 문의하기';
      case 'app_info_screen.text7':
        return '라이선스 안내';
      case 'app_info_screen.text8':
        return '오픈소스 개발 참여하기';
      case 'bip39_list_screen.text1':
        return ({required Object text}) => '\'${text}\' 검색 결과';
      case 'bip39_list_screen.text2':
        return '검색 결과가 없어요';
      case 'pin_setting_screen.text1':
        return '새로운 비밀번호를 눌러주세요';
      case 'pin_setting_screen.text2':
        return '다시 한번 확인할게요';
      case 'settings_screen.text1':
        return '비밀번호 설정하기';
      case 'settings_screen.text2':
        return '생체 인증 사용하기';
      case 'settings_screen.text3':
        return '비밀번호 바꾸기';
      case 'settings_screen.text4':
        return '홈 화면 잔액 숨기기';
      case 'address_list_screen.text1':
        return ({required Object name}) => '${name}의 주소';
      case 'address_list_screen.text2':
        return ({required Object index}) => '주소 - ${index}';
      case 'address_list_screen.text3':
        return '입금';
      case 'transaction_detail_screen.text':
        return ({required Object height, required Object count}) =>
            '\'${height} (${count} 승인)\'';
      case 'utxo_detail_screen.text1':
        return '승인 대기중';
      case 'utxo_detail_screen.text2':
        return '보유 주소';
      case 'utxo_tag_screen.text1':
        return '태그가 없어요';
      case 'utxo_tag_screen.text2':
        return '+ 버튼을 눌러 태그를 추가해 보세요';
      case 'wallet_info_screen.text1':
        return ({required Object name}) => '${name} 정보';
      case 'wallet_info_screen.text2':
        return '확장 공개키 보기';
      case 'wallet_list_add_guide_card.text1':
        return '보기 전용 지갑을 추가해 주세요';
      case 'wallet_list_add_guide_card.text2':
        return '오른쪽 위 + 버튼을 눌러도 추가할 수 있어요';
      case 'wallet_list_add_guide_card.text3':
        return '바로 추가하기';
      case 'wallet_list_terms_shortcut_card.text1':
        return '모르는 용어가 있으신가요?';
      case 'wallet_list_terms_shortcut_card.text2':
        return '오른쪽 위 ';
      case 'wallet_list_terms_shortcut_card.text3':
        return ' - 용어집 또는 여기를 눌러 바로가기';
      case 'faucet_request_bottom_sheet.text1':
        return '주소를 입력해 주세요.\n주소는 [받기] 버튼을 눌러서 확인할 수 있어요.';
      case 'faucet_request_bottom_sheet.text2':
        return '테스트 비트코인 받기';
      case 'faucet_request_bottom_sheet.text3':
        return ({required Object name, required Object index}) =>
            '내 지갑(${name}) 주소 - ${index}';
      case 'faucet_request_bottom_sheet.text4':
        return '요청 중...';
      case 'faucet_request_bottom_sheet.text5':
        return ({required Object bitcoin}) => '${bitcoin} BTC 요청하기';
      case 'license_bottom_sheet.text1':
        return 'Coconut Wallet';
      case 'license_bottom_sheet.text2':
        return '라이선스 안내';
      case 'license_bottom_sheet.text3':
        return '코코넛 월렛은 MIT 라이선스를 따르며 저작권은 대한민국의 논스랩 주식회사에 있습니다. MIT 라이선스 전문은 ';
      case 'license_bottom_sheet.text4':
        return '에서 확인해 주세요.\n\n이 애플리케이션에 포함된 타사 소프트웨어에 대한 저작권을 다음과 같이 명시합니다. 이에 대해 궁금한 사항이 있으시면 ';
      case 'license_bottom_sheet.text5':
        return '으로 문의해 주시기 바랍니다.';
      case 'onboarding_bottom_sheet.text1':
        return '건너뛰기 |';
      case 'onboarding_bottom_sheet.text2':
        return '사용하시다 도움이 필요할 때';
      case 'onboarding_bottom_sheet.text3':
        return '튜토리얼 안내 버튼';
      case 'onboarding_bottom_sheet.text4':
        return '을 눌러주세요';
      case 'security_self_check_bottom_sheet.text1':
        return '나의 개인키는 내가 스스로 책임집니다.';
      case 'security_self_check_bottom_sheet.text2':
        return '니모닉 문구 화면을 캡처하거나 촬영하지 않습니다.';
      case 'security_self_check_bottom_sheet.text3':
        return '니모닉 문구를 네트워크와 연결된 환경에 저장하지 않습니다.';
      case 'security_self_check_bottom_sheet.text4':
        return '니모닉 문구의 순서와 단어의 철자를 확인합니다.';
      case 'security_self_check_bottom_sheet.text5':
        return '패스프레이즈에 혹시 의도하지 않은 문자가 포함되지는 않았는지 한번 더 확인합니다.';
      case 'security_self_check_bottom_sheet.text6':
        return '니모닉 문구와 패스프레이즈는 아무도 없는 안전한 곳에서 확인합니다.';
      case 'security_self_check_bottom_sheet.text7':
        return '니모닉 문구와 패스프레이즈를 함께 보관하지 않습니다.';
      case 'security_self_check_bottom_sheet.text8':
        return '소액으로 보내기 테스트를 한 후 지갑 사용을 시작합니다.';
      case 'security_self_check_bottom_sheet.text9':
        return '위 사항을 주기적으로 점검하고, 안전하게 니모닉 문구를 보관하겠습니다.';
      case 'security_self_check_bottom_sheet.text10':
        return '아래 점검 항목을 숙지하고 비트코인을 반드시 안전하게 보관합니다.';
      case 'tag_bottom_sheet.text1':
        return '새 태그';
      case 'tag_bottom_sheet.text2':
        return '태그 편집';
      case 'tag_bottom_sheet.text3':
        return '새 태그 만들기';
      case 'tag_bottom_sheet.toast':
        return '태그는 최대 5개 지정할 수 있어요';
      case 'terms_bottom_sheet.text1':
        return '포우에 물어보기';
      case 'terms_bottom_sheet.text2':
        return '텔레그램에 물어보기';
      case 'terms_bottom_sheet.text3':
        return '같은 용어';
      case 'terms_bottom_sheet.text4':
        return '관련 용어';
      case 'user_experience_survey_bottom_sheet.text1':
        return '비트코인 전송을 완료하셨군요👍';
      case 'user_experience_survey_bottom_sheet.text2':
        return '코코넛 월렛이 도움이 되었나요?';
      case 'user_experience_survey_bottom_sheet.text3':
        return '네, 좋아요!';
      case 'user_experience_survey_bottom_sheet.text4':
        return '그냥 그래요';
      case 'error.app_1001':
        return '저장소에서 데이터를 불러오는데 실패했습니다.';
      case 'error.app_1002':
        return '저장소에 데이터를 저장하는데 실패했습니다.';
      case 'error.app_1003':
        return '네트워크에 연결할 수 없어요. 연결 상태를 확인해 주세요.';
      case 'error.app_1004':
        return '비트코인 노드와 연결하는데 실패했습니다.';
      case 'error.app_1005':
        return '지갑을 가져오는데 실패했습니다.';
      case 'error.app_1006':
        return '네트워크에서 지갑 정보 불러오기 실패';
      case 'error.app_1007':
        return '잔액 조회를 실패했습니다.';
      case 'error.app_1008':
        return '트랜잭션 목록 조회를 실패했습니다.';
      case 'error.app_1009':
        return '거래 내역을 가져오는데 실패했습니다.';
      case 'error.app_1010':
        return 'DB 경로를 찾을 수 없습니다.';
      case 'error.app_1100':
        return '수수료 계산을 실패했습니다.';
      case 'error.app_1201':
        return '알 수 없는 오류가 발생했습니다.';
      case 'error.app_1202':
        return '데이터를 찾을 수 없습니다.';
      case 'error.app_1203':
        return 'Realm 작업 중 오류가 발생했습니다.';
      case 'error.network_connect':
        return '네트워크 연결이 없습니다.';
      case 'error.low_balance':
        return '잔액이 부족해요.';
      case 'error.dio_cancel':
        return '(요청취소)Request to the server was cancelled.';
      case 'error.dio_connect':
        return '(연결시간초과)Connection timed out.';
      case 'error.dio_receive':
        return '(수신시간초과)Receiving timeout occurred.';
      case 'error.dio_send':
        return '(요청시간초과)Request send timeout.';
      case 'error.dio_unknown':
        return 'Unexpected error occurred.';
      case 'error.dio_default':
        return 'Something went wrong';
      case 'error.utxo1':
        return '잔액이 부족하여 수수료를 낼 수 없어요';
      case 'error.utxo2':
        return 'UTXO 합계가 모자라요';
      case 'error.utxo3':
        return '추천 수수료를 조회하지 못했어요.\n\'변경\'버튼을 눌러서 수수료를 직접 입력해 주세요.';
      case 'error.address1':
        return '올바른 주소가 아니에요.';
      case 'error.address2':
        return '테스트넷 주소가 아니에요.';
      case 'error.address3':
        return '메인넷 주소가 아니에요.';
      case 'error.address4':
        return '레그테스트넷 주소가 아니에요.';
      case 'error.pin_check1':
        return ({required Object count}) => '${count}번 다시 시도할 수 있어요';
      case 'error.pin_check2':
        return '더 이상 시도할 수 없어요\n앱을 종료해 주세요';
      case 'error.pin_check3':
        return '비밀번호가 일치하지 않아요';
      case 'error.pin_already_in_use':
        return '이미 사용중인 비밀번호예요';
      case 'error.pin_processing_failed':
        return '처리 중 문제가 발생했어요';
      case 'error.pin_saving_failed':
        return '저장 중 문제가 발생했어요';
      case 'error.pin_incorrect':
        return '비밀번호가 일치하지 않아요';
      case 'error.data_loading_failed':
        return '데이터를 불러오는 중 오류가 발생했습니다.';
      case 'error.data_not_found':
        return '데이터가 없습니다.';
      case 'text_field.fee':
        return '수수료를 자연수로 입력해 주세요.';
      case 'text_field.fee_btn':
        return '직접 입력하기';
      case 'text_field.mnemonic_hint':
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
      case 'tooltip.send':
        return ({required Object bitcoin}) =>
            '받기 완료된 비트코인만 전송 가능해요.\n받는 중인 금액: ${bitcoin} BTC';
      case 'tooltip.psbt':
        return '볼트 앱에서 생성된 서명 트랜잭션이 보이시나요? 이제, QR 코드를 스캔해 주세요.';
      case 'tooltip.tx1':
        return '볼트에서';
      case 'tooltip.tx2':
        return ({required Object name}) => '${name} 선택, ';
      case 'tooltip.tx3':
        return '로 이동하여 아래 QR 코드를 스캔해 주세요.';
      case 'tooltip.address_external':
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
      case 'snackbar.no_permission':
        return 'no Permission';
      case 'toast.back_exit':
        return '뒤로 가기 버튼을 한 번 더 누르면 종료됩니다.';
      case 'toast.min_fee':
        return ({required Object minimum}) =>
            '현재 최소 수수료는 ${minimum} sats/vb 입니다.';
      case 'toast.loading':
        return '최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.';
      case 'toast.screen_capture':
        return '스크린 캡처가 감지되었습니다.';
      case 'toast.no_balance':
        return '잔액이 없습니다.';
      case 'toast.memo_update_failed':
        return '메모 업데이트에 실패 했습니다.';
      case 'toast.tag_add_failed':
        return '태그 추가에 실패 했습니다.';
      case 'toast.tag_update_failed':
        return '태그 편집에 실패 했습니다.';
      case 'toast.tag_delete_failed':
        return '태그 삭제에 실패 했습니다.';
      case 'toast.wallet_detail_refresh':
        return '화면을 아래로 당겨 최신 데이터를 가져와 주세요.';
      case 'alert.error_tx1':
        return ({required Object error}) => '트랜잭션 파싱 실패: ${error}';
      case 'alert.error_tx2':
        return ({required Object error}) => '트랜잭션 생성 실패 ${error}';
      case 'alert.error_send1':
        return ({required Object error}) => '[전송 실패]\n${error}';
      case 'alert.error_send2':
        return '잔액이 부족해요';
      case 'alert.error_send3':
        return ({required Object bitcoin}) => '${bitcoin} BTC 부터 전송할 수 있어요';
      case 'alert.error_send4':
        return '네트워크 상태가 좋지 않아\n처음으로 돌아갑니다.';
      case 'alert.error_sign1':
        return '잘못된 QR코드예요.\n다시 확인해 주세요.';
      case 'alert.error_sign2':
        return '전송 정보가 달라요.\n처음부터 다시 시도해 주세요.';
      case 'alert.error_sign3':
        return ({required Object count}) => '${count}개 서명이 더 필요해요';
      case 'alert.error_sign5':
        return '잘못된 서명 정보에요. 다시 시도해 주세요.';
      case 'alert.error_scan1':
        return ({required Object error}) => '\'[스캔 실패] ${error}\'';
      case 'alert.error_scan2':
        return ({required Object error}) =>
            'QR코드 스캔에 실패했어요. 다시 시도해 주세요.\n${error}';
      case 'alert.tutorial_title':
        return '도움이 필요하신가요?';
      case 'alert.tutorial_msg':
        return '튜토리얼 사이트로\n안내해 드릴게요';
      case 'alert.tutorial_btn':
        return '튜토리얼 보기';
      case 'alert.pin1_title':
        return '비밀번호를 잊으셨나요?';
      case 'alert.pin1_text':
        return '[다시 설정]을 눌러 비밀번호를 초기화할 수 있어요. 비밀번호를 바꾸면 동기화된 지갑 목록이 초기화 돼요.';
      case 'alert.pin1_btn':
        return '다시 설정';
      case 'alert.wallet1_title':
        return '업데이트 실패';
      case 'alert.wallet1_text':
        return ({required Object name}) => '${name}에 업데이트할 정보가 없어요';
      case 'alert.wallet2_title':
        return '이름 중복';
      case 'alert.wallet2_text':
        return '같은 이름을 가진 지갑이 있습니다.\n이름을 변경한 후 동기화 해주세요.';
      case 'alert.wallet3_title':
        return '보기 전용 지갑 추가 실패';
      case 'alert.wallet3_text':
        return '잘못된 지갑 정보입니다.';
      case 'alert.wallet4_title':
        return '지갑 삭제';
      case 'alert.wallet5_text':
        return '지갑을 정말 삭제하시겠어요?';
      case 'alert.app_title':
        return '업데이트 알림';
      case 'alert.app_text':
        return '안정적인 서비스 이용을 위해\n최신 버전으로 업데이트 해주세요.';
      case 'alert.app_btn1':
        return '업데이트 하기';
      case 'alert.app_btn2':
        return '다음에 하기';
      case 'alert.utxo1_title':
        return '오류 발생';
      case 'alert.utxo1_text':
        return ({required Object error}) => '관리자에게 문의하세요. ${error}';
      case 'alert.utxo2_title':
        return '태그 적용';
      case 'alert.utxo2_text':
        return '기존 UTXO의 태그를 새 UTXO에도 적용하시겠어요?';
      case 'alert.utxo2_btn':
        return '적용하기';
      case 'alert.tx_detail_title':
        return '트랜잭션 가져오기 실패';
      case 'alert.tx_detail_text':
        return '잠시 후 다시 시도해 주세요';
      case 'alert.tag_title':
        return '태그 삭제';
      case 'alert.tag_text1':
        return ({required Object name}) => '#${name}를 정말로 삭제하시겠어요?\n';
      case 'alert.tag_text2':
        return ({required Object count}) => '${count}개  UTXO에 적용되어 있어요.';
      case 'alert.faucet1':
        return '올바른 주소인지 확인해 주세요';
      case 'alert.faucet2':
        return ({required Object count}) => '${count} 후에 다시 시도해 주세요';
      default:
        return null;
    }
  }
}
