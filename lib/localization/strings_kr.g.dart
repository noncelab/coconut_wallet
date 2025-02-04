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
  String get btc => 'BTC';
  String get sats => 'sats';
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
  String get tx_list => '거래 내역';
  String get utxo_list => 'UTXO 목록';
  String get wallet_id => '지갑 ID';
  String get tag_manage => '태그 관리';
  String get extended_public_key => '확장 공개키';
  String get transaction_memo => '거래 메모';
  String get transaction_id => '트랜잭션 ID';
  String get block_num => '블록 번호';
  String get inquiry_detail => '문의 내용';
  String get select_all => '모두 선택';
  String get unselect_all => '모두 해제';
  String get utxo_total => 'UTXO 합계';
  String get send_address => '보낼 주소';
  String get estimated_fee => '예상 수수료';
  String get calculation_failed => '계산 실패';
  String get total_cost => '총 소요 수량';
  String bitcoin_text({required Object bitcoin}) => '${bitcoin} BTC';
  String get manual_input => '직접 입력';
  String get mnemonic_wordlist => '니모닉 문구 단어집';
  String get self_security => '셀프 보안 점검';
  String get app_info => '앱 정보';
  String get app_info_details => '앱 정보 보기';
  String get update_failed => '업데이트 실패';
  String get contact_email => 'hello@noncelab.com';
  String get email_subject => '[코코넛 월렛] 이용 관련 문의';
  String get act_delete => '삭제하기';
  String get act_more => '더보기';
  String get act_mempool => '멤풀 보기';
  String get act_tx => '거래 자세히 보기';
  String get act_utxo => 'UTXO 고르기';
  String get act_all_address => '전체 주소 보기';
  String get no_tx => '거래 내역이 없어요';
  String get no_utxo => 'UTXO가 없어요';
  String get loading_utxo => 'UTXO를 확인하는 중이에요';
  String get used => '사용됨';
  String get unused => '사용 전';
  String fee_sats({required Object value}) => ' (${value} sats/vb)';
  String get failed_fetch_fee => '수수료 조회 실패';
  String get failed_fetch_balance => '잔액 조회 불가';
  String get send_amount => '보낼 수량';
  String get receiving => '받는 중';
  String get received => '받는 완료';
  String get sending => '보내는 중';
  String get sent => '보내기 완료';
  String get no_status => '상태 없음';
  String apply_item({required Object count}) => '${count}개에 적용';
  String get updating => '업데이트 중';
  late final TranslationsTextFieldKr text_field =
      TranslationsTextFieldKr.internal(_root);
  late final TranslationsTooltipKr tooltip =
      TranslationsTooltipKr.internal(_root);
  late final TranslationsSnackbarKr snackbar =
      TranslationsSnackbarKr.internal(_root);
  late final TranslationsToastKr toast = TranslationsToastKr.internal(_root);
  late final TranslationsAlertKr alert = TranslationsAlertKr.internal(_root);
  String get te_fast1 => '빠른 전송';
  String get te_fast2 => '보통 전송';
  String get te_fast3 => '느린 전송';
  String get te_time1 => '~10분';
  String get te_time2 => '~30분';
  String get te_time3 => '~1시간';
  String get ue_amt_desc => '큰 금액순';
  String get ue_amt_asc => '작은 금액순';
  String get ue_time_desc => '최신순';
  String get ue_time_asc => '오래된 순';
  String get savm_error1 => '올바른 주소가 아니에요.';
  String get savm_error2 => '테스트넷 주소가 아니에요.';
  String get savm_error3 => '메인넷 주소가 아니에요.';
  String get savm_error4 => '레그테스트넷 주소가 아니에요.';
  String get susvm_error1 => '잔액이 부족하여 수수료를 낼 수 없어요';
  String get susvm_error2 => 'UTXO 합계가 모자라요';
  String get susvm_error3 =>
      '추천 수수료를 조회하지 못했어요.\n\'변경\'버튼을 눌러서 수수료를 직접 입력해 주세요.';
  String get frvm_success => '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.';
  String get frvm_failed1 => '해당 주소로 이미 요청했습니다. 입금까지 최대 5분이 걸릴 수 있습니다.';
  String get frvm_failed2 => '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
  String get ap_bio => '생체 인증을 진행해 주세요';
  String pcs_error1({required Object count}) => '${count}번 다시 시도할 수 있어요';
  String get pcs_error2 => '더 이상 시도할 수 없어요\n앱을 종료해 주세요';
  String get pcs_error3 => '비밀번호가 일치하지 않아요';
  String get pcs_alert_title => '비밀번호를 잊으셨나요?';
  String get pcs_alert_msg =>
      '[다시 설정]을 눌러 비밀번호를 초기화할 수 있어요. 비밀번호를 바꾸면 동기화된 지갑 목록이 초기화 돼요.';
  String get pcs_alert_btn => '다시 설정';
  String get pcs_title => '비밀번호를 눌러주세요';
  String get pcs_pad_text => '비밀번호가 기억나지 않나요?';
  String get wass_title => '보기 전용 지갑 추가';
  String get wass_tooltip1 => '새로운 지갑을 추가하거나 이미 추가한 지갑의 정보를 업데이트할 수 있어요. ';
  String get wass_tooltip2 => '볼트';
  String get wass_tooltip3 => '에서 사용하시려는 지갑을 선택하고, ';
  String get wass_tooltip4 => '내보내기 ';
  String get wass_tooltip5 => '화면에 나타나는 QR 코드를 스캔해 주세요.';
  String get wass_alert_title1 => '업데이트 실패';
  String wass_alert_msg1({required Object name}) => '${name}에 업데이트할 정보가 없어요';
  String get wass_alert_title2 => '이름 중복';
  String get wass_alert_msg2 => '같은 이름을 가진 지갑이 있습니다.\n이름을 변경한 후 동기화 해주세요.';
  String get wass_alert_title3 => '보기 전용 지갑 추가 실패';
  String get wass_alert_msg3 => '잘못된 지갑 정보입니다.';
  String get wls_toast => '뒤로 가기 버튼을 한 번 더 누르면 종료됩니다.';
  String get wls_guide_text1 => '보기 전용 지갑을 추가해 주세요';
  String get wls_guide_text2 => '오른쪽 위 + 버튼을 눌러도 추가할 수 있어요';
  String get wls_guide_text3 => '바로 추가하기';
  String get wls_terms_text1 => '모르는 용어가 있으신가요?';
  String get wls_terms_text2 => '오른쪽 위 ';
  String get wls_terms_text3 => ' - 용어집 또는 여기를 눌러 바로가기';
  String get ss_alert_title => '업데이트 알림';
  String get ss_alert_msg => '안정적인 서비스 이용을 위해\n최신 버전으로 업데이트 해주세요.';
  String get ss_alert_btn1 => '업데이트 하기';
  String get ss_alert_btn2 => '다음에 하기';
  String get nfs_title => '죄송합니다😭';
  String get nfs_msg => '불편한 점이나 개선사항을 저희에게 알려주세요!';
  String get nfs_btn1 => '1:1 메시지 보내기';
  String get nfs_btn2 => '다음에 할게요';
  String get pfs_title => '감사합니다🥰';
  String get pfs_msg => '그렇다면 스토어에 리뷰를 남겨주시겠어요?';
  String get pfs_btn1 => '물론이죠';
  String get pfs_btn2 => '다음에 할게요';
  String get bcs_title => '전송 요청 완료';
  String get bcs_btn => '트랜잭션 보기';
  String get bs_title => '최종 확인';
  String get bs_subtitle1 => '아래 정보로 송금할게요';
  String get bs_subtitle2 => '내 지갑으로 보내는 트랜잭션입니다.';
  String bs_error1({required Object error}) => '[전송 실패]\n${error}';
  String bs_error2({required Object error}) => '트랜잭션 파싱 실패: ${error}';
  String get sas_subtitle => 'QR을 스캔하거나\n복사한 주소를 붙여넣어 주세요';
  String get sams_error1 => '잔액이 부족해요';
  String sams_error2({required Object bitcoin}) =>
      '${bitcoin} BTC 부터 전송할 수 있어요';
  String sams_tooltip({required Object bitcoin}) =>
      '받기 완료된 비트코인만 전송 가능해요.\n받는 중인 금액: ${bitcoin} BTC';
  String get scs_title => '입력 정보 확인';
  String scs_error({required Object error}) => '트랜잭션 생성 실패 ${error}';
  String get sfss_error => '네트워크 상태가 좋지 않아\n처음으로 돌아갑니다.';
  String get suss_alert_title1 => '오류 발생';
  String suss_alert_msg1({required Object error}) => '관리자에게 문의하세요. ${error}';
  String get suss_alert_title2 => '태그 적용';
  String get suss_alert_msg2 => '기존 UTXO의 태그를 새 UTXO에도 적용하시겠어요?';
  String get suss_alert_btn2 => '적용하기';
  String suss_utxo_count({required Object count}) => '(${count}개)';
  String get spss_title => '서명 트랜잭션 읽기';
  String get spss_tooltip => '볼트 앱에서 생성된 서명 트랜잭션이 보이시나요? 이제, QR 코드를 스캔해 주세요.';
  String get spss_error1 => '잘못된 QR코드예요.\n다시 확인해 주세요.';
  String get spss_error2 => '전송 정보가 달라요.\n처음부터 다시 시도해 주세요.';
  String spss_error3({required Object count}) => '${count}개 서명이 더 필요해요';
  String spss_error4({required Object error}) =>
      'QR코드 스캔에 실패했어요. 다시 시도해 주세요.\n${error}';
  String get spss_error5 => '잘못된 서명 정보에요. 다시 시도해 주세요.';
  String spss_error6({required Object error}) => '\'[스캔 실패] ${error}\'';
  String get utqs_sig => '서명하기';
  String get utqs_multisig => '다중 서명하기';
  String get utqs_tooltip1 => '볼트에서';
  String utqs_tooltip2({required Object name}) => '${name} 선택, ';
  String get utqs_tooltip3 => '로 이동하여 아래 QR 코드를 스캔해 주세요.';
  String get ai_error1 => '데이터를 불러오는 중 오류가 발생했습니다.';
  String get ai_error2 => '데이터가 없습니다.';
  String get ai_text1 => '포우팀이 만듭니다.';
  String get ai_text2 => '궁금한 점이 있으신가요?';
  String get ai_text3 => 'POW 커뮤니티 바로가기';
  String get ai_text4 => '텔레그램 채널로 문의하기';
  String get ai_text5 => 'X로 문의하기';
  String get ai_text6 => '이메일로 문의하기';
  String get ai_text7 => '라이선스 안내';
  String get ai_text8 => '오픈소스 개발 참여하기';
  String bls_text1({required Object text}) => '\'${text}\' 검색 결과';
  String get bls_text2 => '검색 결과가 없어요';
  String get pss_title1 => '새로운 비밀번호를 눌러주세요';
  String get pss_title2 => '다시 한번 확인할게요';
  String get pss_error1 => '이미 사용중인 비밀번호예요';
  String get pss_error2 => '처리 중 문제가 발생했어요';
  String get pss_error3 => '비밀번호가 일치하지 않아요';
  String get pss_error4 => '저장 중 문제가 발생했어요';
  String get ss_btn1 => '비밀번호 설정하기';
  String get ss_btn2 => '생체 인증 사용하기';
  String get ss_btn3 => '비밀번호 바꾸기';
  String get ss_btn4 => '홈 화면 잔액 숨기기';
  String als_text1({required Object name}) => '${name}의 주소';
  String als_text2({required Object index}) => '주소 - ${index}';
  String get als_text3 => '입금';
  String get als_tooltip1 =>
      '비트코인을 받을 때 사용하는 주소예요. 영어로 Receiving 또는 External이라 해요.';
  String get als_tooltip2 =>
      '다른 사람에게 비트코인을 보내고 남은 비트코인을 거슬러 받는 주소예요. 영어로 Change라 해요.';
  String tds_text({required Object height, required Object count}) =>
      '\'${height} (${count} 승인)\'';
  String get tds_toast => '메모 업데이트에 실패 했습니다.';
  String get tds_alert_title => '트랜잭션 가져오기 실패';
  String get tds_alert_msg => '잠시 후 다시 시도해 주세요';
  String get uds_text1 => '승인 대기중';
  String get uds_text2 => '보유 주소';
  String get uds_tooltip =>
      'UTXO란 Unspent Tx Output을 줄인 말로 아직 쓰이지 않은 잔액이란 뜻이에요. 비트코인에는 잔액 개념이 없어요. 지갑에 표시되는 잔액은 UTXO의 총합이라는 것을 알아두세요.';
  String get uts_text1 => '태그가 없어요';
  String get uts_text2 => '+ 버튼을 눌러 태그를 추가해 보세요';
  String get uts_alert_title => '태그 삭제';
  String uts_alert_msg1({required Object name}) => '#${name}를 정말로 삭제하시겠어요?\n';
  String uts_alert_msg2({required Object count}) =>
      '${count}개  UTXO에 적용되어 있어요.';
  String get uts_toast1 => '태그 추가에 실패 했습니다.';
  String get uts_toast2 => '태그 편집에 실패 했습니다.';
  String get uts_toast3 => '태그 삭제에 실패 했습니다.';
  String get wds_tooltip => '테스트용 비트코인으로 마음껏 테스트 해보세요';
  String get wds_toast1 => '화면을 아래로 당겨 최신 데이터를 가져와 주세요.';
  String wis_text1({required Object name}) => '${name} 정보';
  String get wis_text2 => '확장 공개키 보기';
  String get wis_alert_title => '지갑 삭제';
  String get wis_alert_msg => '지갑을 정말 삭제하시겠어요?';
  String wis_tooltip1({required Object total, required Object count}) =>
      '${total}개의 키 중 ${count}개로 서명해야 하는\n다중 서명 지갑이에요.';
  String get wis_tooltip2 => '지갑의 고유 값이에요.\n마스터 핑거프린트(MFP)라고도 해요.';
  String get frbs_hint => '주소를 입력해 주세요.\n주소는 [받기] 버튼을 눌러서 확인할 수 있어요.';
  String get frbs_text1 => '테스트 비트코인 받기';
  String frbs_text2({required Object name, required Object index}) =>
      '내 지갑(${name}) 주소 - ${index}';
  String get frbs_text3 => '요청 중...';
  String frbs_text4({required Object bitcoin}) => '${bitcoin} BTC 요청하기';
  String get frbs_error1 => '올바른 주소인지 확인해 주세요';
  String frbs_error2({required Object count}) => '${count} 후에 다시 시도해 주세요';
  String get lbs_text1 => 'Coconut Wallet';
  String get lbs_text2 => '라이선스 안내';
  String get lbs_text3 =>
      '코코넛 월렛은 MIT 라이선스를 따르며 저작권은 대한민국의 논스랩 주식회사에 있습니다. MIT 라이선스 전문은 ';
  String get lbs_text4 =>
      '에서 확인해 주세요.\n\n이 애플리케이션에 포함된 타사 소프트웨어에 대한 저작권을 다음과 같이 명시합니다. 이에 대해 궁금한 사항이 있으시면 ';
  String get lbs_text5 => '으로 문의해 주시기 바랍니다.';
  String get obs_text1 => '건너뛰기 |';
  String get obs_text2 => '사용하시다 도움이 필요할 때';
  String get obs_text3 => '튜토리얼 안내 버튼';
  String get obs_text4 => '을 눌러주세요';
  String get sscbs_text1 => '나의 개인키는 내가 스스로 책임집니다.';
  String get sscbs_text2 => '니모닉 문구 화면을 캡처하거나 촬영하지 않습니다.';
  String get sscbs_text3 => '니모닉 문구를 네트워크와 연결된 환경에 저장하지 않습니다.';
  String get sscbs_text4 => '니모닉 문구의 순서와 단어의 철자를 확인합니다.';
  String get sscbs_text5 => '패스프레이즈에 혹시 의도하지 않은 문자가 포함되지는 않았는지 한번 더 확인합니다.';
  String get sscbs_text6 => '니모닉 문구와 패스프레이즈는 아무도 없는 안전한 곳에서 확인합니다.';
  String get sscbs_text7 => '니모닉 문구와 패스프레이즈를 함께 보관하지 않습니다.';
  String get sscbs_text8 => '소액으로 보내기 테스트를 한 후 지갑 사용을 시작합니다.';
  String get sscbs_text9 => '위 사항을 주기적으로 점검하고, 안전하게 니모닉 문구를 보관하겠습니다.';
  String get sscbs_text10 => '아래 점검 항목을 숙지하고 비트코인을 반드시 안전하게 보관합니다.';
  String get tbs_text1 => '새 태그';
  String get tbs_text2 => '태그 편집';
  String get tbs_text3 => '새 태그 만들기';
  String get tbs_toast => '태그는 최대 5개 지정할 수 있어요';
  String get tebs_text1 => '포우에 물어보기';
  String get tebs_text2 => '텔레그램에 물어보기';
  String get tebs_text3 => '같은 용어';
  String get tebs_text4 => '관련 용어';
  String get uesbs_text1 => '비트코인 전송을 완료하셨군요👍';
  String get uesbs_text2 => '코코넛 월렛이 도움이 되었나요?';
  String get uesbs_text3 => '네, 좋아요!';
  String get uesbs_text4 => '그냥 그래요';
  late final TranslationsErrorKr error = TranslationsErrorKr.internal(_root);
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
  String min_fee({required Object minimum}) =>
      '현재 최소 수수료는 ${minimum} sats/vb 입니다.';
  String get loading => '최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.';
  String get screen_capture => '스크린 캡처가 감지되었습니다.';
  String get no_balance => '잔액이 없습니다.';
}

// Path: alert
class TranslationsAlertKr {
  TranslationsAlertKr.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations
  String get tutorial_title => '도움이 필요하신가요?';
  String get tutorial_msg => '튜토리얼 사이트로\n안내해 드릴게요';
  String get tutorial_btn => '튜토리얼 보기';
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
      case 'btc':
        return 'BTC';
      case 'sats':
        return 'sats';
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
      case 'transaction_memo':
        return '거래 메모';
      case 'transaction_id':
        return '트랜잭션 ID';
      case 'block_num':
        return '블록 번호';
      case 'inquiry_detail':
        return '문의 내용';
      case 'select_all':
        return '모두 선택';
      case 'unselect_all':
        return '모두 해제';
      case 'utxo_total':
        return 'UTXO 합계';
      case 'send_address':
        return '보낼 주소';
      case 'estimated_fee':
        return '예상 수수료';
      case 'calculation_failed':
        return '계산 실패';
      case 'total_cost':
        return '총 소요 수량';
      case 'bitcoin_text':
        return ({required Object bitcoin}) => '${bitcoin} BTC';
      case 'manual_input':
        return '직접 입력';
      case 'mnemonic_wordlist':
        return '니모닉 문구 단어집';
      case 'self_security':
        return '셀프 보안 점검';
      case 'app_info':
        return '앱 정보';
      case 'app_info_details':
        return '앱 정보 보기';
      case 'update_failed':
        return '업데이트 실패';
      case 'contact_email':
        return 'hello@noncelab.com';
      case 'email_subject':
        return '[코코넛 월렛] 이용 관련 문의';
      case 'act_delete':
        return '삭제하기';
      case 'act_more':
        return '더보기';
      case 'act_mempool':
        return '멤풀 보기';
      case 'act_tx':
        return '거래 자세히 보기';
      case 'act_utxo':
        return 'UTXO 고르기';
      case 'act_all_address':
        return '전체 주소 보기';
      case 'no_tx':
        return '거래 내역이 없어요';
      case 'no_utxo':
        return 'UTXO가 없어요';
      case 'loading_utxo':
        return 'UTXO를 확인하는 중이에요';
      case 'used':
        return '사용됨';
      case 'unused':
        return '사용 전';
      case 'fee_sats':
        return ({required Object value}) => ' (${value} sats/vb)';
      case 'failed_fetch_fee':
        return '수수료 조회 실패';
      case 'failed_fetch_balance':
        return '잔액 조회 불가';
      case 'send_amount':
        return '보낼 수량';
      case 'receiving':
        return '받는 중';
      case 'received':
        return '받는 완료';
      case 'sending':
        return '보내는 중';
      case 'sent':
        return '보내기 완료';
      case 'no_status':
        return '상태 없음';
      case 'apply_item':
        return ({required Object count}) => '${count}개에 적용';
      case 'updating':
        return '업데이트 중';
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
      case 'snackbar.no_permission':
        return 'no Permission';
      case 'toast.min_fee':
        return ({required Object minimum}) =>
            '현재 최소 수수료는 ${minimum} sats/vb 입니다.';
      case 'toast.loading':
        return '최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.';
      case 'toast.screen_capture':
        return '스크린 캡처가 감지되었습니다.';
      case 'toast.no_balance':
        return '잔액이 없습니다.';
      case 'alert.tutorial_title':
        return '도움이 필요하신가요?';
      case 'alert.tutorial_msg':
        return '튜토리얼 사이트로\n안내해 드릴게요';
      case 'alert.tutorial_btn':
        return '튜토리얼 보기';
      case 'te_fast1':
        return '빠른 전송';
      case 'te_fast2':
        return '보통 전송';
      case 'te_fast3':
        return '느린 전송';
      case 'te_time1':
        return '~10분';
      case 'te_time2':
        return '~30분';
      case 'te_time3':
        return '~1시간';
      case 'ue_amt_desc':
        return '큰 금액순';
      case 'ue_amt_asc':
        return '작은 금액순';
      case 'ue_time_desc':
        return '최신순';
      case 'ue_time_asc':
        return '오래된 순';
      case 'savm_error1':
        return '올바른 주소가 아니에요.';
      case 'savm_error2':
        return '테스트넷 주소가 아니에요.';
      case 'savm_error3':
        return '메인넷 주소가 아니에요.';
      case 'savm_error4':
        return '레그테스트넷 주소가 아니에요.';
      case 'susvm_error1':
        return '잔액이 부족하여 수수료를 낼 수 없어요';
      case 'susvm_error2':
        return 'UTXO 합계가 모자라요';
      case 'susvm_error3':
        return '추천 수수료를 조회하지 못했어요.\n\'변경\'버튼을 눌러서 수수료를 직접 입력해 주세요.';
      case 'frvm_success':
        return '테스트 비트코인을 요청했어요. 잠시만 기다려 주세요.';
      case 'frvm_failed1':
        return '해당 주소로 이미 요청했습니다. 입금까지 최대 5분이 걸릴 수 있습니다.';
      case 'frvm_failed2':
        return '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      case 'ap_bio':
        return '생체 인증을 진행해 주세요';
      case 'pcs_error1':
        return ({required Object count}) => '${count}번 다시 시도할 수 있어요';
      case 'pcs_error2':
        return '더 이상 시도할 수 없어요\n앱을 종료해 주세요';
      case 'pcs_error3':
        return '비밀번호가 일치하지 않아요';
      case 'pcs_alert_title':
        return '비밀번호를 잊으셨나요?';
      case 'pcs_alert_msg':
        return '[다시 설정]을 눌러 비밀번호를 초기화할 수 있어요. 비밀번호를 바꾸면 동기화된 지갑 목록이 초기화 돼요.';
      case 'pcs_alert_btn':
        return '다시 설정';
      case 'pcs_title':
        return '비밀번호를 눌러주세요';
      case 'pcs_pad_text':
        return '비밀번호가 기억나지 않나요?';
      case 'wass_title':
        return '보기 전용 지갑 추가';
      case 'wass_tooltip1':
        return '새로운 지갑을 추가하거나 이미 추가한 지갑의 정보를 업데이트할 수 있어요. ';
      case 'wass_tooltip2':
        return '볼트';
      case 'wass_tooltip3':
        return '에서 사용하시려는 지갑을 선택하고, ';
      case 'wass_tooltip4':
        return '내보내기 ';
      case 'wass_tooltip5':
        return '화면에 나타나는 QR 코드를 스캔해 주세요.';
      case 'wass_alert_title1':
        return '업데이트 실패';
      case 'wass_alert_msg1':
        return ({required Object name}) => '${name}에 업데이트할 정보가 없어요';
      case 'wass_alert_title2':
        return '이름 중복';
      case 'wass_alert_msg2':
        return '같은 이름을 가진 지갑이 있습니다.\n이름을 변경한 후 동기화 해주세요.';
      case 'wass_alert_title3':
        return '보기 전용 지갑 추가 실패';
      case 'wass_alert_msg3':
        return '잘못된 지갑 정보입니다.';
      case 'wls_toast':
        return '뒤로 가기 버튼을 한 번 더 누르면 종료됩니다.';
      case 'wls_guide_text1':
        return '보기 전용 지갑을 추가해 주세요';
      case 'wls_guide_text2':
        return '오른쪽 위 + 버튼을 눌러도 추가할 수 있어요';
      case 'wls_guide_text3':
        return '바로 추가하기';
      case 'wls_terms_text1':
        return '모르는 용어가 있으신가요?';
      case 'wls_terms_text2':
        return '오른쪽 위 ';
      case 'wls_terms_text3':
        return ' - 용어집 또는 여기를 눌러 바로가기';
      case 'ss_alert_title':
        return '업데이트 알림';
      case 'ss_alert_msg':
        return '안정적인 서비스 이용을 위해\n최신 버전으로 업데이트 해주세요.';
      case 'ss_alert_btn1':
        return '업데이트 하기';
      case 'ss_alert_btn2':
        return '다음에 하기';
      case 'nfs_title':
        return '죄송합니다😭';
      case 'nfs_msg':
        return '불편한 점이나 개선사항을 저희에게 알려주세요!';
      case 'nfs_btn1':
        return '1:1 메시지 보내기';
      case 'nfs_btn2':
        return '다음에 할게요';
      case 'pfs_title':
        return '감사합니다🥰';
      case 'pfs_msg':
        return '그렇다면 스토어에 리뷰를 남겨주시겠어요?';
      case 'pfs_btn1':
        return '물론이죠';
      case 'pfs_btn2':
        return '다음에 할게요';
      case 'bcs_title':
        return '전송 요청 완료';
      case 'bcs_btn':
        return '트랜잭션 보기';
      case 'bs_title':
        return '최종 확인';
      case 'bs_subtitle1':
        return '아래 정보로 송금할게요';
      case 'bs_subtitle2':
        return '내 지갑으로 보내는 트랜잭션입니다.';
      case 'bs_error1':
        return ({required Object error}) => '[전송 실패]\n${error}';
      case 'bs_error2':
        return ({required Object error}) => '트랜잭션 파싱 실패: ${error}';
      case 'sas_subtitle':
        return 'QR을 스캔하거나\n복사한 주소를 붙여넣어 주세요';
      case 'sams_error1':
        return '잔액이 부족해요';
      case 'sams_error2':
        return ({required Object bitcoin}) => '${bitcoin} BTC 부터 전송할 수 있어요';
      case 'sams_tooltip':
        return ({required Object bitcoin}) =>
            '받기 완료된 비트코인만 전송 가능해요.\n받는 중인 금액: ${bitcoin} BTC';
      case 'scs_title':
        return '입력 정보 확인';
      case 'scs_error':
        return ({required Object error}) => '트랜잭션 생성 실패 ${error}';
      case 'sfss_error':
        return '네트워크 상태가 좋지 않아\n처음으로 돌아갑니다.';
      case 'suss_alert_title1':
        return '오류 발생';
      case 'suss_alert_msg1':
        return ({required Object error}) => '관리자에게 문의하세요. ${error}';
      case 'suss_alert_title2':
        return '태그 적용';
      case 'suss_alert_msg2':
        return '기존 UTXO의 태그를 새 UTXO에도 적용하시겠어요?';
      case 'suss_alert_btn2':
        return '적용하기';
      case 'suss_utxo_count':
        return ({required Object count}) => '(${count}개)';
      case 'spss_title':
        return '서명 트랜잭션 읽기';
      case 'spss_tooltip':
        return '볼트 앱에서 생성된 서명 트랜잭션이 보이시나요? 이제, QR 코드를 스캔해 주세요.';
      case 'spss_error1':
        return '잘못된 QR코드예요.\n다시 확인해 주세요.';
      case 'spss_error2':
        return '전송 정보가 달라요.\n처음부터 다시 시도해 주세요.';
      case 'spss_error3':
        return ({required Object count}) => '${count}개 서명이 더 필요해요';
      case 'spss_error4':
        return ({required Object error}) =>
            'QR코드 스캔에 실패했어요. 다시 시도해 주세요.\n${error}';
      case 'spss_error5':
        return '잘못된 서명 정보에요. 다시 시도해 주세요.';
      case 'spss_error6':
        return ({required Object error}) => '\'[스캔 실패] ${error}\'';
      case 'utqs_sig':
        return '서명하기';
      case 'utqs_multisig':
        return '다중 서명하기';
      case 'utqs_tooltip1':
        return '볼트에서';
      case 'utqs_tooltip2':
        return ({required Object name}) => '${name} 선택, ';
      case 'utqs_tooltip3':
        return '로 이동하여 아래 QR 코드를 스캔해 주세요.';
      case 'ai_error1':
        return '데이터를 불러오는 중 오류가 발생했습니다.';
      case 'ai_error2':
        return '데이터가 없습니다.';
      case 'ai_text1':
        return '포우팀이 만듭니다.';
      case 'ai_text2':
        return '궁금한 점이 있으신가요?';
      case 'ai_text3':
        return 'POW 커뮤니티 바로가기';
      case 'ai_text4':
        return '텔레그램 채널로 문의하기';
      case 'ai_text5':
        return 'X로 문의하기';
      case 'ai_text6':
        return '이메일로 문의하기';
      case 'ai_text7':
        return '라이선스 안내';
      case 'ai_text8':
        return '오픈소스 개발 참여하기';
      case 'bls_text1':
        return ({required Object text}) => '\'${text}\' 검색 결과';
      case 'bls_text2':
        return '검색 결과가 없어요';
      case 'pss_title1':
        return '새로운 비밀번호를 눌러주세요';
      case 'pss_title2':
        return '다시 한번 확인할게요';
      case 'pss_error1':
        return '이미 사용중인 비밀번호예요';
      case 'pss_error2':
        return '처리 중 문제가 발생했어요';
      case 'pss_error3':
        return '비밀번호가 일치하지 않아요';
      case 'pss_error4':
        return '저장 중 문제가 발생했어요';
      case 'ss_btn1':
        return '비밀번호 설정하기';
      case 'ss_btn2':
        return '생체 인증 사용하기';
      case 'ss_btn3':
        return '비밀번호 바꾸기';
      case 'ss_btn4':
        return '홈 화면 잔액 숨기기';
      case 'als_text1':
        return ({required Object name}) => '${name}의 주소';
      case 'als_text2':
        return ({required Object index}) => '주소 - ${index}';
      case 'als_text3':
        return '입금';
      case 'als_tooltip1':
        return '비트코인을 받을 때 사용하는 주소예요. 영어로 Receiving 또는 External이라 해요.';
      case 'als_tooltip2':
        return '다른 사람에게 비트코인을 보내고 남은 비트코인을 거슬러 받는 주소예요. 영어로 Change라 해요.';
      case 'tds_text':
        return ({required Object height, required Object count}) =>
            '\'${height} (${count} 승인)\'';
      case 'tds_toast':
        return '메모 업데이트에 실패 했습니다.';
      case 'tds_alert_title':
        return '트랜잭션 가져오기 실패';
      case 'tds_alert_msg':
        return '잠시 후 다시 시도해 주세요';
      case 'uds_text1':
        return '승인 대기중';
      case 'uds_text2':
        return '보유 주소';
      case 'uds_tooltip':
        return 'UTXO란 Unspent Tx Output을 줄인 말로 아직 쓰이지 않은 잔액이란 뜻이에요. 비트코인에는 잔액 개념이 없어요. 지갑에 표시되는 잔액은 UTXO의 총합이라는 것을 알아두세요.';
      case 'uts_text1':
        return '태그가 없어요';
      case 'uts_text2':
        return '+ 버튼을 눌러 태그를 추가해 보세요';
      case 'uts_alert_title':
        return '태그 삭제';
      case 'uts_alert_msg1':
        return ({required Object name}) => '#${name}를 정말로 삭제하시겠어요?\n';
      case 'uts_alert_msg2':
        return ({required Object count}) => '${count}개  UTXO에 적용되어 있어요.';
      case 'uts_toast1':
        return '태그 추가에 실패 했습니다.';
      case 'uts_toast2':
        return '태그 편집에 실패 했습니다.';
      case 'uts_toast3':
        return '태그 삭제에 실패 했습니다.';
      case 'wds_tooltip':
        return '테스트용 비트코인으로 마음껏 테스트 해보세요';
      case 'wds_toast1':
        return '화면을 아래로 당겨 최신 데이터를 가져와 주세요.';
      case 'wis_text1':
        return ({required Object name}) => '${name} 정보';
      case 'wis_text2':
        return '확장 공개키 보기';
      case 'wis_alert_title':
        return '지갑 삭제';
      case 'wis_alert_msg':
        return '지갑을 정말 삭제하시겠어요?';
      case 'wis_tooltip1':
        return ({required Object total, required Object count}) =>
            '${total}개의 키 중 ${count}개로 서명해야 하는\n다중 서명 지갑이에요.';
      case 'wis_tooltip2':
        return '지갑의 고유 값이에요.\n마스터 핑거프린트(MFP)라고도 해요.';
      case 'frbs_hint':
        return '주소를 입력해 주세요.\n주소는 [받기] 버튼을 눌러서 확인할 수 있어요.';
      case 'frbs_text1':
        return '테스트 비트코인 받기';
      case 'frbs_text2':
        return ({required Object name, required Object index}) =>
            '내 지갑(${name}) 주소 - ${index}';
      case 'frbs_text3':
        return '요청 중...';
      case 'frbs_text4':
        return ({required Object bitcoin}) => '${bitcoin} BTC 요청하기';
      case 'frbs_error1':
        return '올바른 주소인지 확인해 주세요';
      case 'frbs_error2':
        return ({required Object count}) => '${count} 후에 다시 시도해 주세요';
      case 'lbs_text1':
        return 'Coconut Wallet';
      case 'lbs_text2':
        return '라이선스 안내';
      case 'lbs_text3':
        return '코코넛 월렛은 MIT 라이선스를 따르며 저작권은 대한민국의 논스랩 주식회사에 있습니다. MIT 라이선스 전문은 ';
      case 'lbs_text4':
        return '에서 확인해 주세요.\n\n이 애플리케이션에 포함된 타사 소프트웨어에 대한 저작권을 다음과 같이 명시합니다. 이에 대해 궁금한 사항이 있으시면 ';
      case 'lbs_text5':
        return '으로 문의해 주시기 바랍니다.';
      case 'obs_text1':
        return '건너뛰기 |';
      case 'obs_text2':
        return '사용하시다 도움이 필요할 때';
      case 'obs_text3':
        return '튜토리얼 안내 버튼';
      case 'obs_text4':
        return '을 눌러주세요';
      case 'sscbs_text1':
        return '나의 개인키는 내가 스스로 책임집니다.';
      case 'sscbs_text2':
        return '니모닉 문구 화면을 캡처하거나 촬영하지 않습니다.';
      case 'sscbs_text3':
        return '니모닉 문구를 네트워크와 연결된 환경에 저장하지 않습니다.';
      case 'sscbs_text4':
        return '니모닉 문구의 순서와 단어의 철자를 확인합니다.';
      case 'sscbs_text5':
        return '패스프레이즈에 혹시 의도하지 않은 문자가 포함되지는 않았는지 한번 더 확인합니다.';
      case 'sscbs_text6':
        return '니모닉 문구와 패스프레이즈는 아무도 없는 안전한 곳에서 확인합니다.';
      case 'sscbs_text7':
        return '니모닉 문구와 패스프레이즈를 함께 보관하지 않습니다.';
      case 'sscbs_text8':
        return '소액으로 보내기 테스트를 한 후 지갑 사용을 시작합니다.';
      case 'sscbs_text9':
        return '위 사항을 주기적으로 점검하고, 안전하게 니모닉 문구를 보관하겠습니다.';
      case 'sscbs_text10':
        return '아래 점검 항목을 숙지하고 비트코인을 반드시 안전하게 보관합니다.';
      case 'tbs_text1':
        return '새 태그';
      case 'tbs_text2':
        return '태그 편집';
      case 'tbs_text3':
        return '새 태그 만들기';
      case 'tbs_toast':
        return '태그는 최대 5개 지정할 수 있어요';
      case 'tebs_text1':
        return '포우에 물어보기';
      case 'tebs_text2':
        return '텔레그램에 물어보기';
      case 'tebs_text3':
        return '같은 용어';
      case 'tebs_text4':
        return '관련 용어';
      case 'uesbs_text1':
        return '비트코인 전송을 완료하셨군요👍';
      case 'uesbs_text2':
        return '코코넛 월렛이 도움이 되었나요?';
      case 'uesbs_text3':
        return '네, 좋아요!';
      case 'uesbs_text4':
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
      default:
        return null;
    }
  }
}
