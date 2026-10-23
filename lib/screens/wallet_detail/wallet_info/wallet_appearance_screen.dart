import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutTextField, CoconutTextFieldStyle, CoconutToast, CoconutToastLevel;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/constants/wallet_skins.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_appearance_view_model.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/custom_wallet_icons.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_photo_crop_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/home/span_size_option.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class WalletAppearanceScreen extends StatelessWidget {
  final int id;
  final PhotoPicker? pickPhoto;

  const WalletAppearanceScreen({super.key, required this.id, this.pickPhoto});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WalletAppearanceViewModel>(
      create:
          (context) => WalletAppearanceViewModel(
            id,
            context.read<WalletProvider>(),
            context.read<PreferenceProvider>(),
            context.read<WalletAppearanceProvider>(),
            pickPhoto: pickPhoto,
          ),
      child: const _WalletAppearanceBody(),
    );
  }
}

class _WalletAppearanceBody extends StatelessWidget {
  const _WalletAppearanceBody();

  static const double _horizontalPadding = 16;
  static const double _cardGap = 12;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletAppearanceViewModel>();
    final colors = context.coconutColors;
    return PopScope(
      canPop: !viewModel.isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) viewModel.discard();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: CoconutAppBar.build(
          context: context,
          onBackPressed: () {
            if (!viewModel.isSaving) Navigator.maybePop(context);
          },
        ),
        body: Stack(
          children: [
            Column(
              children: [
                _preview(context, viewModel),
                CoconutLayout.spacing_300h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final size in WalletCardSize.values)
                      SpanSizeOption(
                        key: Key('wallet-appearance-size-${size.name}'),
                        columns: size == WalletCardSize.wide ? 4 : 2,
                        rows: 2,
                        isSelected: viewModel.previewSize == size,
                        onTap: () => viewModel.selectPreviewSize(size),
                      ),
                  ],
                ),
                CoconutLayout.spacing_400h,
                _WallpaperTabBar(tabs: viewModel.tabs, selected: viewModel.tab, onSelected: viewModel.selectTab),
                Expanded(
                  child: SingleChildScrollView(
                    key: PageStorageKey('wallet-appearance-tab-body-${viewModel.tab.name}'),
                    padding: const EdgeInsets.fromLTRB(_horizontalPadding, 24, _horizontalPadding, 120),
                    child: SizedBox(width: double.infinity, child: _TabBody(viewModel: viewModel)),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FixedBottomButton(
                text: t.complete,
                isActive: viewModel.canSave,
                onButtonClicked: () async {
                  await viewModel.save();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, WalletAppearanceViewModel viewModel) {
    final width = MediaQuery.sizeOf(context).width - _horizontalPadding * 2;
    final side = (width - _cardGap) / 2;
    final isWide = viewModel.previewSize == WalletCardSize.wide;
    final size = Size(isWide ? width : side, side);
    final photo = viewModel.photo;
    final card = AnimatedContainer(
      key: const Key('wallet-appearance-preview'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: WalletCard.elevationOf(context)),
      child: WalletCard(
        wallet: viewModel.wallet,
        appearance: viewModel.appearance,
        size: viewModel.previewSize,
        displayName: viewModel.name.trim().isEmpty ? null : viewModel.name.trim(),
        balanceDisplay: viewModel.balanceText,
        backgroundPhoto: photo == null ? null : viewModel.photoFileOf(photo),
      ),
    );
    return Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: card));
  }
}

class _WallpaperTabBar extends StatelessWidget {
  final List<WalletAppearanceTab> tabs;
  final WalletAppearanceTab selected;
  final ValueChanged<WalletAppearanceTab> onSelected;

  const _WallpaperTabBar({required this.tabs, required this.selected, required this.onSelected});

  String _label(WalletAppearanceTab tab) => switch (tab) {
    WalletAppearanceTab.wallet => t.wallet_appearance_screen.wallet_tab,
    WalletAppearanceTab.skins => t.wallet_appearance_screen.skins,
    WalletAppearanceTab.colors => t.wallet_appearance_screen.colors,
    WalletAppearanceTab.photos => t.wallet_appearance_screen.photos,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            spacing: 28,
            children: [
              for (final tab in tabs)
                GestureDetector(
                  key: Key('wallet-appearance-tab-${tab.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(tab),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          style: CoconutTypography.heading4_18_Bold.setColor(
                            tab == selected ? colors.primaryText : colors.mutedText,
                          ),
                          child: Text(_label(tab), textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 10),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: tab == selected ? 1 : 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: colors.primaryText,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, color: colors.divider),
      ],
    );
  }
}

class _TabBody extends StatelessWidget {
  final WalletAppearanceViewModel viewModel;

  const _TabBody({required this.viewModel});

  static const int _columns = 5;
  static const double _tileRadius = 14;
  static const double _selectionWidth = 1.8;
  static const double _selectionGap = 3;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final selected = viewModel.background;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
        Widget grid(List<Widget> tiles) => Wrap(spacing: _gap, runSpacing: _gap, children: tiles);
        switch (viewModel.tab) {
          case WalletAppearanceTab.wallet:
            return _WalletTab(viewModel: viewModel);
          case WalletAppearanceTab.skins:
            return grid([
              _tile(
                context,
                key: const Key('wallet-appearance-option-default'),
                size: tileSize,
                outlined: true,
                isSelected: selected == null,
                onPressed: () => viewModel.selectBackground(null),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const WalletCardBackground(background: null),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            t.wallet_appearance_screen.default_background,
                            maxLines: 1,
                            softWrap: false,
                            style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.secondaryText),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final skin in walletSkins)
                _tile(
                  context,
                  key: Key('wallet-appearance-option-skin-${skin.id}'),
                  size: tileSize,
                  isSelected: selected == WalletSkinBackground(skin.id),
                  onPressed: () => viewModel.selectBackground(WalletSkinBackground(skin.id)),
                  child: WalletCardBackground(background: WalletSkinBackground(skin.id)),
                ),
            ]);
          case WalletAppearanceTab.colors:
            final selectedColor = selected is WalletColorBackground ? selected.color : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                grid([
                  for (var index = 0; index < walletPaletteColors.length; index++)
                    _tile(
                      context,
                      key: Key('wallet-appearance-option-color-$index'),
                      size: tileSize,
                      isSelected: selectedColor == walletPaletteColors[index],
                      onPressed: () => viewModel.selectBackground(WalletColorBackground.of(walletPaletteColors[index])),
                      child: ColoredBox(color: walletPaletteColors[index]),
                    ),
                ]),
                CoconutLayout.spacing_600h,
                _SolidColorSliders(
                  color: selectedColor ?? walletPaletteColors.first,
                  onChanged: (color) => viewModel.selectBackground(WalletColorBackground.of(color)),
                ),
              ],
            );
          case WalletAppearanceTab.photos:
            final lastPhoto = viewModel.lastPhoto;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                grid([
                  if (lastPhoto != null)
                    _tile(
                      context,
                      key: const Key('wallet-appearance-option-photo'),
                      size: tileSize,
                      isSelected: selected is WalletPhotoBackground,
                      onPressed:
                          () =>
                              selected is WalletPhotoBackground
                                  ? _openCrop(context, selected, isNew: false)
                                  : viewModel.selectBackground(lastPhoto),
                      child: _photoThumbnail(lastPhoto),
                    ),
                  _tile(
                    context,
                    key: const Key('wallet-appearance-option-choose-photo'),
                    size: tileSize,
                    outlined: true,
                    isSelected: false,
                    onPressed: () => _pickPhoto(context),
                    child: _choosePhotoContent(context),
                  ),
                ]),
                if (viewModel.photo != null) ...[
                  CoconutLayout.spacing_400h,
                  Text(
                    t.wallet_appearance_screen.adjust_hint,
                    style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                  ),
                ],
              ],
            );
        }
      },
    );
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final result = await viewModel.pickPhoto();
    if (!context.mounted) return;
    if (result.failed) {
      CoconutToast.showToast(
        context: context,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.triangleWarning,
        text: t.wallet_appearance_screen.photo_pick_failed,
        level: CoconutToastLevel.warning,
      );
      return;
    }
    final photo = result.photo;
    if (photo != null) await _openCrop(context, photo, isNew: true);
  }

  Future<void> _openCrop(BuildContext context, WalletPhotoBackground photo, {required bool isNew}) async {
    final file = viewModel.photoFileOf(photo);
    if (file == null) return;
    final framed = await Navigator.push<WalletPhotoBackground>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: WalletPhotoCropScreen.routeName),
        fullscreenDialog: true,
        builder: (_) => WalletPhotoCropScreen(photo: photo, file: file, initialSize: viewModel.previewSize),
      ),
    );
    if (framed != null) {
      viewModel.applyPhoto(framed);
    } else if (isNew) {
      await viewModel.dropPhoto(photo);
    }
  }

  Widget _photoThumbnail(WalletPhotoBackground photo) {
    final file = viewModel.photoFileOf(photo);
    if (file == null) return const WalletCardBackground(background: null);
    return Image.file(file, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }

  Widget _choosePhotoContent(BuildContext context) {
    final colors = context.coconutColors;
    return ColoredBox(
      color: colors.homeSurface,
      child: Center(
        child:
            viewModel.isPickingPhoto
                ? SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.secondaryText),
                )
                : Icon(
                  Icons.add_photo_alternate_outlined,
                  color: colors.secondaryText,
                  size: 28,
                  semanticLabel: t.wallet_appearance_screen.choose_photo,
                ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required Key key,
    required double size,
    required bool isSelected,
    required VoidCallback onPressed,
    required Widget child,
    bool outlined = false,
  }) {
    final colors = context.coconutColors;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(_selectionGap),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_tileRadius + _selectionGap + _selectionWidth),
        border: Border.all(color: isSelected ? colors.primaryText : Colors.transparent, width: _selectionWidth),
      ),
      child: ShrinkAnimationButton(
        key: key,
        onPressed: onPressed,
        borderRadius: _tileRadius,
        defaultColor: colors.homeSurface,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_tileRadius),
            border: outlined ? Border.all(color: colors.border) : null,
          ),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

/// 이름·아이콘·색 편집. 바꿀 수 없는 항목은 보이지 않는다.
class _WalletTab extends StatefulWidget {
  final WalletAppearanceViewModel viewModel;

  const _WalletTab({required this.viewModel});

  @override
  State<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<_WalletTab> {
  late final TextEditingController _controller = TextEditingController(text: widget.viewModel.name);
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final colors = context.coconutColors;
    final hasError = viewModel.isNameDuplicated || viewModel.isNameEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.canEditName)
          CoconutTextField(
            key: const Key('wallet-appearance-name-field'),
            controller: _controller,
            focusNode: _focusNode,
            onChanged: viewModel.updateName,
            placeholderText: t.wallet_appearance_screen.name_placeholder,
            maxLength: 20,
            maxLines: 1,
            clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
            onClear: () {
              _controller.clear();
              viewModel.updateName('');
            },
            isError: viewModel.isNameDuplicated,
            errorText: viewModel.isNameDuplicated ? t.wallet_info_screen.duplicated_name : '',
          ),
        if (viewModel.canEditPalette) ...[
          if (viewModel.canEditName) SizedBox(height: hasError ? 16 : 8),
          _title(context, t.wallet_appearance_screen.color),
          _grid([
            for (var index = 0; index < CoconutColors.colorPalette.length; index++)
              _PaletteChoice(
                key: Key('wallet-appearance-color-$index'),
                isSelected: viewModel.colorIndex == index,
                onTap: () => viewModel.selectColor(index),
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: CoconutColors.colorPalette[index]),
                ),
              ),
          ]),
          CoconutLayout.spacing_400h,
          _title(context, t.wallet_appearance_screen.icon),
          _grid([
            for (var index = 0; index < CustomWalletIcons.totalCount; index++)
              _PaletteChoice(
                key: Key('wallet-appearance-icon-$index'),
                isSelected: viewModel.iconIndex == index,
                onTap: () => viewModel.selectIcon(index),
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: context.coconutColors.iconBackgroundSubtle),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SvgPicture.asset(
                      CustomWalletIcons.getPathByIndex(index),
                      colorFilter: ColorFilter.mode(
                        viewModel.iconIndex == index
                            ? context.coconutColors.primaryText
                            : context.coconutColors.iconSecondary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ],
        if (!viewModel.canEditName && !viewModel.canEditPalette)
          Text(viewModel.wallet.name, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
      ],
    );
  }

  Widget _title(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText)),
  );

  Widget _grid(List<Widget> children) => GridView.count(
    crossAxisCount: 5,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    children: children,
  );
}

class _PaletteChoice extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _PaletteChoice({super.key, required this.isSelected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(7),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? context.coconutColors.primaryText : Colors.transparent, width: 1.8),
        ),
        child: child,
      ),
    );
  }
}

/// 색상 막대와 밝기 막대로 단색을 고른다. 밝기는 옅은 파스텔(0)부터 진한 색(1)까지다.
class _SolidColorSliders extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const _SolidColorSliders({required this.color, required this.onChanged});

  static Color colorOf(double hue, double tone) =>
      HSVColor.fromAHSV(1, hue, 0.12 + 0.73 * tone, 1 - 0.58 * tone).toColor();

  @override
  State<_SolidColorSliders> createState() => _SolidColorSlidersState();
}

class _SolidColorSlidersState extends State<_SolidColorSliders> {
  late double _hue;
  late double _tone;

  @override
  void initState() {
    super.initState();
    _syncFrom(widget.color);
  }

  @override
  void didUpdateWidget(covariant _SolidColorSliders oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color.toARGB32() != _SolidColorSliders.colorOf(_hue, _tone).toARGB32()) _syncFrom(widget.color);
  }

  void _syncFrom(Color color) {
    _hue = HSVColor.fromColor(color).hue;
    double distance(Color other) => (other.r - color.r).abs() + (other.g - color.g).abs() + (other.b - color.b).abs();
    var best = 0.0;
    for (var step = 1; step <= 100; step++) {
      final tone = step / 100;
      if (distance(_SolidColorSliders.colorOf(_hue, tone)) < distance(_SolidColorSliders.colorOf(_hue, best))) {
        best = tone;
      }
    }
    _tone = best;
  }

  void _update({double? hue, double? tone}) {
    setState(() {
      _hue = hue ?? _hue;
      _tone = tone ?? _tone;
    });
    widget.onChanged(_SolidColorSliders.colorOf(_hue, _tone));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final current = _SolidColorSliders.colorOf(_hue, _tone);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: CoconutTypography.body3_12_Bold.setColor(colors.secondaryText)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(t.wallet_appearance_screen.hue),
        _GradientSlider(
          key: const Key('wallet-appearance-hue-slider'),
          colors: [for (var hue = 0; hue <= 360; hue += 30) _SolidColorSliders.colorOf(hue % 360, _tone)],
          value: _hue / 360,
          thumbColor: current,
          onChanged: (value) => _update(hue: value * 359.9),
        ),
        CoconutLayout.spacing_500h,
        label(t.wallet_appearance_screen.brightness),
        _GradientSlider(
          key: const Key('wallet-appearance-tone-slider'),
          colors: [
            for (final tone in const [0.0, 0.5, 1.0]) _SolidColorSliders.colorOf(_hue, tone),
          ],
          value: _tone,
          thumbColor: current,
          onChanged: (value) => _update(tone: value),
        ),
      ],
    );
  }
}

class _GradientSlider extends StatelessWidget {
  final List<Color> colors;
  final double value;
  final Color thumbColor;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    super.key,
    required this.colors,
    required this.value,
    required this.thumbColor,
    required this.onChanged,
  });

  static const double _height = 28;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void report(Offset position) => onChanged(((position.dx - _height / 2) / (width - _height)).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => report(details.localPosition),
          onHorizontalDragStart: (details) => report(details.localPosition),
          onHorizontalDragUpdate: (details) => report(details.localPosition),
          child: SizedBox(
            height: _height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_height / 2),
                      gradient: LinearGradient(colors: colors),
                    ),
                  ),
                ),
                Positioned(
                  left: value.clamp(0.0, 1.0) * (width - _height),
                  top: 0,
                  child: Container(
                    width: _height,
                    height: _height,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: thumbColor,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
