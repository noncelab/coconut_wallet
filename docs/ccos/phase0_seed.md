Create an Ouroboros seed for Phase 0A of CCOS.

Project:
CCOS — Coconut Contribution Open Store, pronounced “COS”.

Repository:
https://github.com/noncelab/coconut_wallet

Current realization:
Before implementing CCOS FeatureRegistry or inviting external developer PRs, Coconut Wallet must first be refactored into an extension-ready host app.

Problem:
The current app has UI values such as colors, typography, spacing, and component styling embedded directly across screens and widgets.
Because of this, defining a theme feature or theme registry would not actually affect the app consistently.
The impact is broad because this touches many existing screens.
Therefore, the first milestone is not marketplace functionality.
The first milestone is to introduce a stable design token and theme abstraction layer, then migrate key screens incrementally.

Goal of Phase 0A:
Refactor Coconut Wallet so that future CCOS features can integrate into a consistent, token-based, extension-ready UI architecture without changing wallet behavior.

Important:
Do not implement the full CCOS marketplace yet.
Do not implement real IAP.
Do not implement developer PR onboarding yet.
Do not build a plugin runtime.
Do not change Bitcoin wallet behavior.
Do not modify signing, seed, transaction construction, broadcast, UTXO selection, backup/recovery, or fee policy logic.

Main objectives:
1. Introduce a Coconut design token layer.
2. Move hardcoded colors and common UI styling into theme tokens.
3. Provide context-based accessors for Coconut theme values.
4. Create or align common Coconut UI primitives such as buttons, cards, list tiles, app bars, and bottom sheets.
5. Migrate a limited set of high-impact screens to the new token system.
6. Add guardrails to prevent new hardcoded colors from being introduced.
7. Keep the app behavior visually equivalent under the default theme.

Proposed directories:
- lib/design_system/
  - coconut_colors.dart
  - coconut_typography.dart
  - coconut_spacing.dart
  - coconut_radius.dart
  - coconut_theme.dart
  - coconut_theme_extension.dart
- lib/widgets/coconut/
  - coconut_button.dart
  - coconut_card.dart
  - coconut_list_tile.dart
  - coconut_bottom_sheet.dart
  - coconut_app_bar.dart

Preferred Flutter approach:
Use ThemeData and ThemeExtension for custom Coconut tokens.
Expose tokens through BuildContext extensions.

Example:
context.coconutColors.primary
context.coconutColors.background
context.coconutTypography.body
context.coconutSpacing.md

Migration target for Phase 0A:
Prioritize only the minimum screens needed to prove theme readiness:
- Home / Wallet list
- Wallet detail
- Settings
- Transaction detail
- A placeholder CCOS store screen if useful

Do not attempt to migrate every screen in one PR unless the diff remains manageable.
Prefer incremental commits or separate PRs:
1. Introduce tokens with zero behavior change.
2. Migrate common widgets.
3. Migrate selected screens.
4. Add lint/checks.

Default theme requirement:
The default Coconut theme must match the current app visually as closely as possible.
Any visual changes should be intentional and documented.

Hardcoded value policy:
After Phase 0A, new feature code should not introduce raw Color(0x...), hardcoded text colors, hardcoded button colors, or ad-hoc spacing in migrated areas.
Allow exceptions for:
- illustrations
- charts
- brand assets
- one-off debug/test code
- external package limitations

Suggested guardrail:
Add a lightweight script or CI check that flags new raw Color(0x...) usages outside approved token files.
Do not block the whole migration if legacy hardcoded colors still exist.
Only block newly introduced hardcoded colors in modified files or CCOS-related paths.

Required outputs:
1. Problem statement
2. Refactoring scope
3. Non-goals
4. Design token architecture
5. Migration plan
6. File-by-file implementation plan
7. Guardrail strategy
8. Acceptance criteria
9. Risks and mitigations

Acceptance criteria:
- App builds successfully.
- Existing wallet behavior remains unchanged.
- Default theme visually matches current app closely.
- CoconutColors and related tokens are available through BuildContext.
- At least the selected target screens use token-based colors for background, text, surfaces, and primary actions.
- A second sample theme can be created and applied in development to prove the abstraction works.
- No CCOS registry or marketplace logic is required yet.
- CI or a script can detect newly added hardcoded colors in CCOS/migrated areas.
- Documentation explains that Phase 0A is a prerequisite for CCOS Phase 0B FeatureRegistry work.

Now generate a concrete Phase 0A implementation seed with:
1. Task breakdown
2. Proposed file structure
3. Dart interface/code skeletons
4. Migration order
5. Review checklist
6. Acceptance tests
