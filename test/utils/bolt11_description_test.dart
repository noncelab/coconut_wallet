import 'package:coconut_wallet/utils/payment_request_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('인보이스 메모를 읽는다', () {
    expect(
      PaymentRequest.bolt11Description(
        'lnbcrt10u1p40t5f0sp57wunzjsxjz8r3t6hwsglmuu5w88dgzj47tje30fyeefqgalgz05spp5ar0ctejvqlzg645smy83w58vmzhr7t4mxq2q93p9xhmnc9y6ruqsdqhajsfpmyt4n4tpy3qw3jhxaqxqy9gcqcqzgq9qyysgq2sgrme7h9gjx3cxpj0p5we0nh8jz9u29lk45uz3dgv38dshmmq4y8fvyhnfncsnsuvljpdjuuqx79dxhtypgdz7dev6rdlqtsue57zcqqujsek',
      ),
      '점심값 test',
    );
  });

  test('메모 없는 인보이스는 null', () {
    expect(
      PaymentRequest.bolt11Description(
        'lnbcrt100u1p40tjf7sp5c9855wpvk4s2w4eqs3c4d0vmejxdpatjh2tk3y0z4gfskncxkysqpp5ra3ajqd20mmztlxn6c8upla3wms5p8v8hfwqf9ywr8yftwvk0m6qdqqxqy9gcqcqzgq9qyysgqczveua3wyyaaq6z66ckacn4lx0q5mt36qytv63jexxm6y9c74jqzzyyl2gly4hh86v75je543pgd0q660e9tuwp2lelf4mfj5j4n3xgq0zkx5v',
      ),
      isNull,
    );
  });

  test('형식이 틀리면 null', () {
    expect(PaymentRequest.bolt11Description('lnbcrt1bad'), isNull);
  });

  test('인보이스 결제 해시를 읽는다', () {
    expect(
      PaymentRequest.bolt11PaymentHash(
        'lnbcrt100u1p40tjf7sp5c9855wpvk4s2w4eqs3c4d0vmejxdpatjh2tk3y0z4gfskncxkysqpp5ra3ajqd20mmztlxn6c8upla3wms5p8v8hfwqf9ywr8yftwvk0m6qdqqxqy9gcqcqzgq9qyysgqczveua3wyyaaq6z66ckacn4lx0q5mt36qytv63jexxm6y9c74jqzzyyl2gly4hh86v75je543pgd0q660e9tuwp2lelf4mfj5j4n3xgq0zkx5v',
      ),
      '1f63d901aa7ef625fcd3d60fc0ffb176e1409d87ba5c04948e19c895b9967ef4',
    );
  });
}
