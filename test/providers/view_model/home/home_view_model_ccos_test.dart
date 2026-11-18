import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_home_entry.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CcosWidget extends HomeItemDefinition {
  _CcosWidget()
    : super(
        id: 'ccos_test_widget',
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small],
        category: HomeItemCategory.wallets,
        ccosFeatureId: 'ccos-test',
      );

  @override
  Widget build(BuildContext context, HomeItem item) => const SizedBox();
}

CcosFeatureListing _listing(String id, {CcosHomeShortcut? shortcut, CcosHomeWidget? widget}) => CcosFeatureListing(
  id: id,
  category: CcosFeatureCategory.tool,
  title: id,
  description: '',
  author: '',
  authorBio: '',
  authorIntent: '',
  whyItBelongs: '',
  featureHelp: '',
  priceType: CcosListingPriceType.free,
  subtitle: '',
  iconPath: '',
  creatorStory: const CcosCreatorStory(paragraphs: [], belief: ''),
  homeShortcut: shortcut,
  homeWidget: widget,
);

void main() {
  late HomeConfigurationRepository repository;
  late Set<String> activated;
  late ChangeNotifier activation;
  late CcosHomeEntryLog homeEntries;

  final withEntries = _listing(
    'ccos-test',
    shortcut: CcosHomeShortcut(
      id: 'ccos_test_shortcut',
      label: () => '테스트',
      iconPath: FeatureShortcutIconPath.openStore,
      launch: (_) {},
      addToHomeOnActivate: true,
    ),
    widget: CcosHomeWidget(definition: _CcosWidget.new),
  );
  final withoutEntries = _listing('ccos-plain');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    repository = HomeConfigurationRepository(prefs);
    activated = {};
    activation = ChangeNotifier();
    homeEntries = CcosHomeEntryLog();
  });

  HomeViewModel create() {
    final viewModel = HomeViewModel(
      repository: repository,
      wallets: () => [],
      onShortcutTap: (_, __) {},
      widgetDefinitions: const [],
      isCcosFeatureActivated: activated.contains,
      ccosActivationChanges: activation,
      ccosListings: () => [withEntries, withoutEntries],
      ccosHomeEntries: homeEntries,
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  void setActive(String id, bool on) {
    on ? activated.add(id) : activated.remove(id);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    activation.notifyListeners();
  }

  int onHome(HomeViewModel viewModel, String definitionId) =>
      viewModel.configuration.items.where((item) => item.definitionId == definitionId).length;

  final shortcutId = HomeItemIds.shortcut('ccos_test_shortcut');

  test('features without home entries register nothing', () {
    final viewModel = create();

    expect(viewModel.registry.all.where((definition) => definition.ccosFeatureId == 'ccos-plain'), isEmpty);
  });

  test('locked entries are listed but locked', () {
    final viewModel = create();

    final shortcut = viewModel.addableShortcutDefinitions.firstWhere((definition) => definition.id == shortcutId);
    final widget = viewModel.widgetDefinitions.firstWhere((definition) => definition.id == 'ccos_test_widget');
    expect(viewModel.isLockedByCcos(shortcut), isTrue);
    expect(viewModel.isLockedByCcos(widget), isTrue);
  });

  test('activating adds the shortcut once, never the widget', () {
    final viewModel = create();

    setActive('ccos-test', true);
    expect(homeEntries.takeAdded('ccos-test'), '테스트');
    setActive('ccos-test', false);
    setActive('ccos-test', true);

    expect(onHome(viewModel, shortcutId), 1);
    expect(onHome(viewModel, 'ccos_test_widget'), 0);
    expect(viewModel.isLockedByCcos(viewModel.registry.byId(shortcutId)!), isFalse);
    expect(homeEntries.takeAdded('ccos-test'), '테스트');
  });

  test('already on home is not reported', () {
    final viewModel = create();
    viewModel.addItem(viewModel.registry.byId(shortcutId)!);

    setActive('ccos-test', true);

    expect(onHome(viewModel, shortcutId), 1);
    expect(homeEntries.takeAdded('ccos-test'), isNull);
  });

  test('deactivating removes its home items', () {
    activated.add('ccos-test');
    final viewModel = create();
    viewModel.addItem(viewModel.registry.byId(shortcutId)!);
    viewModel.addItem(viewModel.registry.byId('ccos_test_widget')!);

    setActive('ccos-test', false);

    expect(onHome(viewModel, shortcutId), 0);
    expect(onHome(viewModel, 'ccos_test_widget'), 0);
    expect(homeEntries.takeRemoved('ccos-test'), '테스트');
  });

  test('deactivating without the shortcut on home is not reported', () {
    activated.add('ccos-test');
    create();

    setActive('ccos-test', false);

    expect(homeEntries.takeRemoved('ccos-test'), isNull);
  });

  test('a locked shortcut on home leads to its store detail', () {
    final viewModel = create();
    final shortcut = viewModel.registry.byId(shortcutId)! as ShortcutDefinition;

    expect(viewModel.lockedCcosFeatureOf(shortcut.feature), 'ccos-test');
    setActive('ccos-test', true);
    expect(viewModel.lockedCcosFeatureOf(shortcut.feature), isNull);
  });
}
