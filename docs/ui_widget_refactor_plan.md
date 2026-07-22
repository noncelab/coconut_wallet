# UI / Widgets Refactor Plan

## Goal

- `lib/ui/`는 app-specific design-system wrapper 전용으로 제한한다.
- `lib/widgets/common/`은 cross-feature reusable composition만 둔다.
- `lib/widgets/features/`는 feature-owned composed widget만 둔다.
- 파일 위치만 보고도 "어떤 성격의 요소인지" 판단할 수 있게 만든다.

## Folder Rules

### `lib/ui/`

Use only for app-specific wrappers around design-system components.

Examples:

- `ui/coconut/coconut_app_bar.dart`
- `ui/coconut/coconut_text_field.dart`
- `ui/coconut/coconut_underlined_button.dart`
- `ui/coconut/coconut_overlays.dart`
- `ui/coconut/coconut_option_picker.dart`

Do not place cross-feature reusable compositions or feature-owned composed widgets here.

### `lib/widgets/common/`

Use for cross-feature reusable compositions that are not design-system wrappers.

Current / target examples:

- `widgets/common/loading/loading_indicator.dart`
- `widgets/common/buttons/shrink_animation_button.dart`
- `widgets/common/buttons/shrink_tap_wrapper.dart`
- `widgets/common/dialogs/dialog.dart`
- `widgets/common/dialogs/custom_dialogs.dart`
- `widgets/common/effects/ripple_effect.dart`
- `widgets/common/overlays/coconut_loading_overlay.dart`
- `widgets/common/overlays/common_bottom_sheets.dart`
- `widgets/common/overlays/custom_loading_overlay.dart`

### `lib/widgets/features/`

Use for feature-owned composed widgets.

Target buckets:

- `widgets/features/wallet/...`
- `widgets/features/utxo/...`
- `widgets/features/send/...`
- `widgets/features/qr/...`
- `widgets/features/settings/...`

## Phase Plan

## Token Removal Plan

Completed cleanup:

- `lib/design_system/tokens/coconut_typography.dart` deleted
- `lib/design_system/tokens/coconut_spacing.dart` deleted
- `lib/design_system/tokens/coconut_radius.dart` deleted

Resulting direction:

- app-owned `ThemeExtension` now carries `colors` only
- app code should access host semantic colors via `context.coconutColors`
- typography should come from `coconut_design_system` tokens such as `CoconutTypography.body2_14`
- spacing should use `CoconutLayout.spacing_*`, `CoconutLayout.defaultPadding`, or explicit local constants when more readable
- radius should use `CoconutStyles.radius_*` or explicit `BorderRadius.circular(...)`

Follow-up note:

- some docs and architectural notes still mention removed local typography / spacing / radius token files as historical Phase 0A artifacts
- those references should be treated as documentation debt, not active architecture

### Phase 1

Move common loading / overlay building blocks.

Done:

- `widgets/loading_indicator/loading_indicator.dart`
  -> `widgets/common/loading/loading_indicator.dart`
- `widgets/custom_loading_overlay.dart`
  -> `widgets/common/overlays/custom_loading_overlay.dart`
- `widgets/overlays/coconut_loading_overlay.dart`
  -> `widgets/common/overlays/coconut_loading_overlay.dart`

### Phase 2

Normalize common infrastructure under `widgets/common/`.

Done:

- `widgets/overlays/common_bottom_sheets.dart`
  -> `widgets/common/overlays/common_bottom_sheets.dart`
- `widgets/dialog.dart`
  -> `widgets/common/dialogs/dialog.dart`
- `widgets/custom_dialogs.dart`
  -> `widgets/common/dialogs/custom_dialogs.dart`
- `widgets/button/shrink_animation_button.dart`
  -> `widgets/common/buttons/shrink_animation_button.dart`
- `widgets/button/shrink_tap_wrapper.dart`
  -> `widgets/common/buttons/shrink_tap_wrapper.dart`
- `widgets/ripple_effect.dart`
  -> `widgets/common/effects/ripple_effect.dart`

### Phase 3

Split feature widgets into explicit feature folders.

Done:

- `widgets/header/selected_utxo_amount_header.dart`
  -> `widgets/features/utxo/header/selected_utxo_amount_header.dart`
- `widgets/header/utxo_list_header.dart`
  -> `widgets/features/utxo/header/utxo_list_header.dart`
- `widgets/header/utxo_list_sticky_header.dart`
  -> `widgets/features/utxo/header/utxo_list_sticky_header.dart`
- `widgets/header/utxo_tag_list_widget.dart`
  -> `widgets/features/utxo/header/utxo_tag_list_widget.dart`
- `widgets/send_amount_header.dart`
  -> `widgets/features/send/send_amount_header.dart`
- `widgets/send_output_detail_card.dart`
  -> `widgets/features/send/send_output_detail_card.dart`
- `widgets/send_output_detail_row.dart`
  -> `widgets/features/send/send_output_detail_row.dart`
- `widgets/card/send_transaction_flow_card.dart`
  -> `widgets/features/send/send_transaction_flow_card.dart`
- `widgets/adaptive_qr_image.dart`
  -> `widgets/features/qr/adaptive_qr_image.dart`
- `widgets/input_and_share_overlay.dart`
  -> `widgets/features/qr/input_and_share_overlay.dart`
- `widgets/qrcode_info.dart`
  -> `widgets/features/qr/qrcode_info.dart`
- `widgets/animated_qr/...`
  -> `widgets/features/qr/animated_qr/...`

Follow-up candidates:

- `widgets/card/address_list_address_item_card.dart`
  -> `widgets/features/wallet/address/...`

### Phase 4

Continue splitting wallet-bound compositions into `widgets/features/wallet/`.

Done:

- `widgets/header/wallet_detail_header.dart`
  -> `widgets/features/wallet/header/wallet_detail_header.dart`
- `widgets/header/wallet_detail_sticky_header.dart`
  -> `widgets/features/wallet/header/wallet_detail_sticky_header.dart`
- `widgets/card/wallet_expandable_info_card.dart`
  -> `widgets/features/wallet/card/wallet_expandable_info_card.dart`
- `widgets/card/wallet_info_item_card.dart`
  -> `widgets/features/wallet/card/wallet_info_item_card.dart`
- `widgets/card/wallet_item_card.dart`
  -> `widgets/features/wallet/card/wallet_item_card.dart`
- `widgets/card/wallet_list_add_guide_card.dart`
  -> `widgets/features/wallet/card/wallet_list_add_guide_card.dart`

Next candidates:

- `widgets/card/address_list_address_item_card.dart`
  -> `widgets/features/wallet/address/address_list_address_item_card.dart`
- `widgets/card/utxo_item_card.dart`
  -> `widgets/features/utxo/card/utxo_item_card.dart`
- `widgets/card/selectable_utxo_item_card.dart`
  -> `widgets/features/utxo/card/selectable_utxo_item_card.dart`
- `widgets/card/locked_utxo_item_card.dart`
  -> `widgets/features/utxo/card/locked_utxo_item_card.dart`
- `widgets/dropdown/utxo_filter_dropdown.dart`
  -> `widgets/features/utxo/dropdown/utxo_filter_dropdown.dart`

Done in Phase 4 continuation:

- `widgets/card/address_list_address_item_card.dart`
  -> `widgets/features/wallet/address/address_list_address_item_card.dart`
- `widgets/card/utxo_item_card.dart`
  -> `widgets/features/utxo/card/utxo_item_card.dart`
- `widgets/card/selectable_utxo_item_card.dart`
  -> `widgets/features/utxo/card/selectable_utxo_item_card.dart`
- `widgets/card/locked_utxo_item_card.dart`
  -> `widgets/features/utxo/card/locked_utxo_item_card.dart`
- `widgets/dropdown/utxo_filter_dropdown.dart`
  -> `widgets/features/utxo/dropdown/utxo_filter_dropdown.dart`

### Phase 5

Split remaining transaction-bound widgets and UTXO-specific summary compositions.

Done:

- `widgets/card/transaction_draft_card.dart`
  -> `widgets/features/transaction/card/transaction_draft_card.dart`
- `widgets/card/transaction_input_output_card.dart`
  -> `widgets/features/transaction/card/transaction_input_output_card.dart`
- `widgets/card/transaction_item_card.dart`
  -> `widgets/features/transaction/card/transaction_item_card.dart`
- `widgets/card/underline_button_item_card.dart`
  -> `widgets/features/transaction/card/underline_button_item_card.dart`
- `widgets/input_output_detail_row.dart`
  -> `widgets/features/transaction/row/input_output_detail_row.dart`
- `widgets/card/animated_summary_card.dart`
  -> `widgets/features/utxo/summary/animated_summary_card.dart`

Next candidates:

- `widgets/card/multisig_signer_card.dart`
- `widgets/card/taproot_participant_card.dart`
- `widgets/card/taproot_setup_summary_card.dart`
- `widgets/card/role_description_card.dart`
- `widgets/card/transaction_*` references inside docs handoff notes

### Phase 6

Normalize remaining generic presentation widgets under `widgets/common/`.

Done:

- `widgets/animated_dots_text.dart`
  -> `widgets/common/text/animated_dots_text.dart`
- `widgets/shimmer_text.dart`
  -> `widgets/common/text/shimmer_text.dart`
- `widgets/check_list.dart`
  -> `widgets/common/list/check_list.dart`
- `widgets/svg_box_container.dart`
  -> `widgets/common/icon/svg_box_container.dart`

Next candidates:

- `widgets/animated_dialog.dart`
- `widgets/bubble_clipper.dart`
- `widgets/custom_expansion_panel.dart`
- `widgets/highlighted_info_area.dart`
- `widgets/floating_widget.dart`

### Phase 7

Finish residual card/overlay classification by domain ownership.

Done:

- `widgets/card/multisig_signer_card.dart`
  -> `widgets/features/wallet/signer/multisig_signer_card.dart`
- `widgets/card/role_description_card.dart`
  -> `widgets/features/wallet/taproot/role_description_card.dart`
- `widgets/card/taproot_participant_card.dart`
  -> `widgets/features/wallet/taproot/taproot_participant_card.dart`
- `widgets/card/taproot_setup_summary_card.dart`
  -> `widgets/features/wallet/taproot/taproot_setup_summary_card.dart`
- `widgets/overlays/error_tooltip.dart`
  -> `widgets/common/overlays/error_tooltip.dart`
- `widgets/overlays/scanner_overlay.dart`
  -> `widgets/features/qr/overlay/scanner_overlay.dart`

Notes:

- `ErrorTooltip` is reused across multiple flows, so it belongs to `common/overlays/`.
- `ScannerOverlay` is QR-scanner specific, so it belongs to `features/qr/overlay/`.

### Phase 8

Move PIN-authentication widgets under a dedicated auth feature bucket.

Done:

- `widgets/pin/pin_box.dart`
  -> `widgets/features/auth/pin/pin_box.dart`
- `widgets/pin/pin_input_pad.dart`
  -> `widgets/features/auth/pin/pin_input_pad.dart`
- `widgets/pin/pin_length_toggle_button.dart`
  -> `widgets/features/auth/pin/pin_length_toggle_button.dart`
- `widgets/button/key_button.dart`
  -> `widgets/features/auth/pin/key_button.dart`

Notes:

- PIN entry widgets are used only by PIN check / PIN setting flows.
- `key_button.dart` is effectively part of the PIN keypad, so it moves with the same feature.

### Phase 9

Split debug/settings widgets and icon widgets by domain ownership.

Done:

- `widgets/realm_debug/query_input_section.dart`
  -> `widgets/features/settings/realm_debug/query_input_section.dart`
- `widgets/realm_debug/results_area.dart`
  -> `widgets/features/settings/realm_debug/results_area.dart`
- `widgets/realm_debug/sort_options_section.dart`
  -> `widgets/features/settings/realm_debug/sort_options_section.dart`
- `widgets/realm_debug/statistics_section.dart`
  -> `widgets/features/settings/realm_debug/statistics_section.dart`
- `widgets/icon/splash_logo_icon.dart`
  -> `widgets/common/icon/splash_logo_icon.dart`
- `widgets/icon/transaction_status_gradient_mask.dart`
  -> `widgets/common/icon/transaction_status_gradient_mask.dart`
- `widgets/icon/wallet_icon.dart`
  -> `widgets/features/wallet/icon/wallet_icon.dart`
- `widgets/icon/wallet_icon_small.dart`
  -> `widgets/features/wallet/icon/wallet_icon_small.dart`
- `widgets/icon/icon_palette_cell.dart`
  -> `widgets/features/wallet/icon/icon_palette_cell.dart`
- `widgets/icon/pending_transaction_lottie_icon.dart`
  -> `widgets/features/transaction/icon/pending_transaction_lottie_icon.dart`

Notes:

- `realm_debug` widgets are effectively a settings/devtools feature.
- icon widgets were split into `common`, `wallet`, and `transaction` ownership.

### Phase 10

Move selector/tooltip widgets under their owning features.

Done:

- `widgets/selector/custom_tag_horizontal_selector.dart`
  -> `widgets/features/utxo/selector/custom_tag_horizontal_selector.dart`
- `widgets/selector/custom_tag_vertical_selector.dart`
  -> `widgets/features/utxo/selector/custom_tag_vertical_selector.dart`
- `widgets/tooltip/faucet_tooltip.dart`
  -> `widgets/features/wallet/tooltip/faucet_tooltip.dart`

Notes:

- tag selectors are UTXO/tag-management specific, not generic selectors.
- `faucet_tooltip` is specific to the wallet detail faucet affordance.

### Phase 11

Normalize remaining common primitives and move obvious feature-owned bodies/bottom sheets.

Done:

- `widgets/animated_balance.dart`
  -> `widgets/common/amount/animated_balance.dart`
- `widgets/bitcoin_amount_unit.dart`
  -> `widgets/common/amount/bitcoin_amount_unit.dart`
- `widgets/contents/fiat_price.dart`
  -> `widgets/common/amount/fiat_price.dart`
- `widgets/animated_dialog.dart`
  -> `widgets/common/dialogs/animated_dialog.dart`
- `widgets/bubble_clipper.dart`
  -> `widgets/common/clipper/bubble_clipper.dart`
- `widgets/bottom_sheet/selectable_list_bottom_sheet.dart`
  -> `widgets/common/bottom_sheet/selectable_list_bottom_sheet.dart`
- `widgets/bottom_sheet/selection_bottom_sheet.dart`
  -> `widgets/common/bottom_sheet/selection_bottom_sheet.dart`
- `widgets/bottom_sheet/single_field_fixed_bottom_sheet_body.dart`
  -> `widgets/common/bottom_sheet/single_field_fixed_bottom_sheet_body.dart`
- `widgets/bottom_sheet/estimated_fee_bottom_sheet.dart`
  -> `widgets/features/utxo/bottom_sheet/estimated_fee_bottom_sheet.dart`
- `widgets/body/address_qr_scanner_body.dart`
  -> `widgets/features/qr/body/address_qr_scanner_body.dart`
- `widgets/fixed_text_scale.dart`
  -> `widgets/common/text/fixed_text_scale.dart`
- `widgets/button/bottom_action_bar.dart`
  -> `widgets/common/buttons/bottom_action_bar.dart`
- `widgets/button/button_group.dart`
  -> `widgets/common/buttons/button_group.dart`
- `widgets/button/copy_text_container.dart`
  -> `widgets/common/buttons/copy_text_container.dart`
- `widgets/button/custom_underlined_button.dart`
  -> `widgets/common/buttons/custom_underlined_button.dart`
- `widgets/button/fixed_bottom_button.dart`
  -> `widgets/common/buttons/fixed_bottom_button.dart`
- `widgets/button/fixed_bottom_tween_button.dart`
  -> `widgets/common/buttons/fixed_bottom_tween_button.dart`
- `widgets/button/single_button.dart`
  -> `widgets/common/buttons/single_button.dart`
- `widgets/button/tooltip_button.dart`
  -> `widgets/common/buttons/tooltip_button.dart`

Notes:

- amount display primitives are shared broadly enough to live under `common/amount/`.
- generic bottom sheet building blocks moved under `common/bottom_sheet/`.
- `estimated_fee_bottom_sheet` and `address_qr_scanner_body` are feature-owned and moved accordingly.
- several completed button compositions are reused enough to justify `common/buttons/`.

### Phase 12

Finish residual root-widget cleanup by moving app/common/feature-owned leftovers.

Done:

- `widgets/deep_link_listener.dart`
  -> `app/deep_link/deep_link_listener.dart`
- `widgets/custom_expansion_panel.dart`
  -> `widgets/common/panel/custom_expansion_panel.dart`
- `widgets/highlighted_info_area.dart`
  -> `widgets/common/info/highlighted_info_area.dart`
- `widgets/long_pressed_menu_widget.dart`
  -> `widgets/features/wallet/menu/long_pressed_menu_widget.dart`
- `widgets/button/custom_tag_chip_color_button.dart`
  -> `widgets/features/utxo/tag/custom_tag_chip_color_button.dart`

Notes:

- `deep_link_listener` is app-shell behavior rather than a reusable widget primitive.
- `custom_expansion_panel` and `highlighted_info_area` are reusable UI compositions.
- `long_pressed_menu_widget` is currently owned by wallet-home editing UX.
- `custom_tag_chip_color_button` belongs to UTXO tag editing flow.

## Naming Rules

- Prefer role names over brand names when folder context already explains intent.
- Keep brand names only for wrapper layer under `ui/coconut/`.

Examples:

- Good: `widgets/common/loading/loading_indicator.dart`
- Good: `widgets/features/utxo/header/utxo_list_header.dart`
- Avoid: putting non-wrapper files under `ui/coconut/`

## Decision Heuristic

When placing a new file:

1. Is it adapting or patching the design system?
   - Put it in `ui/`.
2. Is it reused by multiple unrelated features?
   - Put it in `widgets/common/`.
3. Is it mainly for one feature/domain?
   - Put it in `widgets/features/<feature>/`.
4. Is it app-shell behavior rather than a reusable UI building block?
   - Put it in `app/`.
