// 홈 위젯 통화가 HomeViewModel에서 PriceProvider.setHomeWidgetFiats로 실제로 전달되는지 본다.
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Widget extends HomeItemDefinition {
  _Widget({super.id = 'w'})
    : super(
        kind: HomeItemKind.widget,
        supportedSpans: [HomeSpan.small],
        category: HomeItemCategory.wallets,
        allowsMultipleInstances: true,
      );

  @override
  Widget build(BuildContext context, HomeItem item) => const SizedBox();
}

class _RecordingPrices extends Fake with ChangeNotifier implements PriceProvider {
  final calls = <Set<FiatCode>>[];

  @override
  void setHomeWidgetFiats(Iterable<FiatCode> fiats) => calls.add(fiats.toSet());
}

void main() {
  late HomeConfigurationRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    repository = HomeConfigurationRepository(prefs);
  });

  test('저장된 위젯 통화는 시작할 때, 위젯 설정을 바꾸거나 지울 때마다 PriceProvider로 전달된다', () async {
    await repository.save(
      HomeConfiguration(
        items: const [
          HomeItem(
            id: 'saved',
            definitionId: 'w',
            kind: HomeItemKind.widget,
            order: 0,
            span: HomeSpan.small,
            configuration: {
              'fiats': ['ZAR', 'USD'],
            },
          ),
        ],
      ),
    );
    final prices = _RecordingPrices();
    final definition = _Widget();
    final viewModel = HomeViewModel(
      repository: repository,
      wallets: () => const [],
      onShortcutTap: (_, __) {},
      widgetDefinitions: [definition],
      priceProvider: prices,
    );
    addTearDown(viewModel.dispose);

    expect(prices.calls, isNotEmpty, reason: '시작할 때 저장된 위젯 통화를 알린다');
    expect(prices.calls.last, {FiatCode.ZAR, FiatCode.USD});

    viewModel.updateItemConfiguration('saved', {
      'fiats': ['KWD'],
    });
    expect(prices.calls.last, {FiatCode.KWD});

    viewModel.addItem(
      definition,
      configuration: {
        'fiats': ['THB', 'JPY'],
      },
    );
    expect(prices.calls.last, {FiatCode.KWD, FiatCode.THB, FiatCode.JPY});

    viewModel.removeItem('saved');
    expect(prices.calls.last, {FiatCode.THB, FiatCode.JPY});
  });
}
