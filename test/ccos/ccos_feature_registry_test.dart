import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });

  group('CcosFeatureRegistrySource', () {
    test('allListings에는 featuredListing이 포함되어 있다', () {
      // CcosFeatureListing has no == override, and featuredListing/allListings each build a
      // fresh instance per call, so compare by id rather than by object identity.
      final ids = CcosFeatureRegistrySource.allListings.map((listing) => listing.id);
      expect(ids, contains(CcosFeatureRegistrySource.featuredListing.id));
    });

    test('findListingById는 일치하는 기능을 반환한다', () {
      const id = CoconutThemeFeature.id;

      final found = CcosFeatureRegistrySource.findListingById(id);

      expect(found, isNotNull);
      expect(found!.id, id);
    });

    test('findListingById는 존재하지 않는 id에 대해 null을 반환한다', () {
      final found = CcosFeatureRegistrySource.findListingById('does-not-exist');

      expect(found, isNull);
    });
  });

  group('CoconutPulpFeature.listing', () {
    test('id가 lib/ccos/features/coconut_pulp/ 폴더명 규칙과 일치한다', () {
      expect(CoconutThemeFeature.id, 'ccos-feature-theme-coconut-pulp');
      expect(CoconutThemeFeature.listing.id, CoconutThemeFeature.id);
    });

    test('theme 카테고리로 등록되어 있고 연결된 테마 variant가 있다', () {
      final listing = CoconutThemeFeature.listing;

      expect(listing.category, CcosFeatureCategory.theme);
      expect(listing.isSelectableTheme, isTrue);
      expect(listing.linkedVariant, isNotNull);
    });

    test('무료 기능은 entitlement가 필요하지 않다', () {
      expect(CoconutThemeFeature.listing.priceType, CcosListingPriceType.free);
      expect(CoconutThemeFeature.listing.requiresEntitlement, isFalse);
    });

    for (final locale in [AppLocale.ko, AppLocale.en, AppLocale.ja, AppLocale.es, AppLocale.de]) {
      test('locale=$locale 문구가 전부 번역되어 있다', () {
        LocaleSettings.setLocaleSync(locale);

        final listing = CoconutThemeFeature.listing;

        expect(listing.title, isNotEmpty);
        expect(listing.description, isNotEmpty);
        expect(listing.author, isNotEmpty);
        expect(listing.authorBio, isNotEmpty);
        expect(listing.authorIntent, isNotEmpty);
        expect(listing.whyItBelongs, isNotEmpty);
        expect(listing.featureHelp, isNotEmpty);
        expect(listing.tags, isNotEmpty);
      });
    }
  });

  group('store details', () {
    test('listings carry store details', () {
      for (final listing in CcosFeatureRegistrySource.allListings) {
        expect(listing.subtitle, isNotEmpty, reason: listing.id);
        expect(listing.iconPath, isNotEmpty, reason: listing.id);
        expect(listing.creatorStory.paragraphs, isNotEmpty, reason: listing.id);
        expect(listing.creatorStory.belief, isNotEmpty, reason: listing.id);
      }
    });

    test('the store lists ark first, then the coconut theme', () {
      expect(CcosFeatureRegistrySource.allListings.map((listing) => listing.id), [
        ArkFeature.id,
        CoconutThemeFeature.id,
      ]);
      expect(CcosFeatureRegistrySource.featuredListing.id, CoconutThemeFeature.id);
    });

    test('ark is authored by the Bark team and has no quote', () {
      final listing = ArkFeature.listing;

      expect(listing.author, 'Bark 팀');
      expect(listing.creatorStory.quote, isNull);
      expect(listing.creatorStory.quoteAttribution, isNull);
      expect(listing.screenshots, hasLength(5));
    });

    test('theme keeps the existing creator story', () {
      final story = CoconutThemeFeature.listing.creatorStory;
      final detail = t.ccos.first_pow_scene.creator_detail;

      expect(story.quote, detail.feedback_quote);
      expect(story.quoteAttribution, detail.feedback_attribution);
      expect(story.paragraphs, [detail.story_paragraph1, detail.story_paragraph2, detail.story_paragraph3]);
      expect(story.belief, detail.belief_statement);
    });

    test('ark is applied while a wallet uses it, added or not', () {
      final listing = ArkFeature.listing;

      expect(listing.isApplied(const CcosFeatureUsage(isActivated: false, hasArkOnWallet: true)), isTrue);
      expect(listing.isApplied(const CcosFeatureUsage(isActivated: true)), isFalse);
    });

    test('the theme is applied only when added and selected', () {
      final listing = CoconutThemeFeature.listing;

      expect(
        listing.isApplied(const CcosFeatureUsage(isActivated: true, themeVariant: CoconutThemeVariant.coconutTheme)),
        isTrue,
      );
      expect(
        listing.isApplied(const CcosFeatureUsage(isActivated: false, themeVariant: CoconutThemeVariant.coconutTheme)),
        isFalse,
      );
      expect(listing.isApplied(const CcosFeatureUsage(isActivated: true)), isFalse);
    });

    test('screenshots fall back to English outside Korean', () {
      final shot = ArkFeature.listing.screenshots.first;

      expect(shot.assetPathFor(AppLocale.ko), shot.koAssetPath);
      for (final locale in [AppLocale.en, AppLocale.ja, AppLocale.de, AppLocale.es]) {
        expect(shot.assetPathFor(locale), shot.enAssetPath);
      }
      expect(shot.koAssetPath, isNot(shot.enAssetPath));
    });

    for (final locale in [AppLocale.en, AppLocale.ja, AppLocale.de, AppLocale.es]) {
      test('locale=$locale ark store copy is translated', () {
        LocaleSettings.setLocaleSync(locale);
        final listing = ArkFeature.listing;

        expect(listing.author, contains('Bark'));
        expect(listing.subtitle, isNotEmpty);
        expect(listing.screenshots.every((shot) => shot.caption.isNotEmpty), isTrue);
      });
    }
  });
}
