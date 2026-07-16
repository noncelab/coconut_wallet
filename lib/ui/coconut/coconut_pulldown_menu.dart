import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract class CoconutPulldownMenuEntry {}

class CoconutPulldownMenuItem extends CoconutPulldownMenuEntry {
  final String title;
  final bool isDisabled;
  final bool hasSwitch;
  final bool switchValue;
  final Function(bool value)? onSwitchChanged;

  CoconutPulldownMenuItem({
    required this.title,
    this.isDisabled = false,
    this.hasSwitch = false,
    this.switchValue = false,
    this.onSwitchChanged,
  });
}

class CoconutPulldownMenuGroup extends CoconutPulldownMenuEntry {
  final String groupTitle;
  final List<CoconutPulldownMenuItem> items;

  CoconutPulldownMenuGroup({required this.groupTitle, required this.items});
}

class CoconutPulldownMenu extends StatelessWidget {
  final List<CoconutPulldownMenuEntry> entries;
  final int? selectedIndex;
  final Function(int, String) onSelected;
  final EdgeInsets margin;
  final EdgeInsets? buttonPadding;
  final double buttonHeight;
  final double iconSize;
  final double blurRadius;
  final double borderRadius;
  final double spreadRadius;
  final double? dividerHeight;
  final double? thickDividerHeight;
  final List<int>? thickDividerIndexList;
  final Color? textColor;
  final Color? backgroundColor;
  final Color? dividerColor;
  final Color? iconColor;
  final Color? splashColor;
  final Color? shadowColor;
  final TextStyle? groupTitleStyle;
  final Color? groupTitleColor;
  final EdgeInsets? groupTitlePadding;
  final bool? isSelectedItemBold;
  final Function(int index, bool value)? onSwitchChanged;
  final Color? switchActiveTrackColor;
  final Color? switchInactiveTrackColor;
  final Color? switchThumbColor;

  const CoconutPulldownMenu({
    super.key,
    required this.entries,
    required this.onSelected,
    this.selectedIndex,
    this.margin = EdgeInsets.zero,
    this.buttonPadding,
    this.buttonHeight = 44,
    this.blurRadius = 12,
    this.spreadRadius = 4,
    this.borderRadius = 16,
    this.iconSize = 24,
    this.dividerHeight = 1,
    this.thickDividerHeight = 5,
    this.thickDividerIndexList,
    this.textColor,
    this.backgroundColor,
    this.dividerColor,
    this.iconColor,
    this.splashColor,
    this.shadowColor,
    this.groupTitleColor,
    this.groupTitlePadding,
    this.groupTitleStyle,
    this.isSelectedItemBold = false,
    this.onSwitchChanged,
    this.switchActiveTrackColor,
    this.switchInactiveTrackColor,
    this.switchThumbColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final flattenedEntries = <_FlattenedEntry>[];
    var runningIndex = 0;

    for (final entry in entries) {
      if (entry is CoconutPulldownMenuGroup) {
        flattenedEntries.add(_FlattenedEntry.group(entry.groupTitle));
        for (final item in entry.items) {
          flattenedEntries.add(_FlattenedEntry.item(item, runningIndex++));
        }
      } else if (entry is CoconutPulldownMenuItem) {
        flattenedEntries.add(_FlattenedEntry.item(entry, runningIndex++));
      }
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        margin: margin,
        constraints: const BoxConstraints(minWidth: 152),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: shadowColor ?? colors.shadowDefault.withValues(alpha: 0.12),
              spreadRadius: spreadRadius,
              blurRadius: blurRadius,
              offset: Offset.zero,
            ),
          ],
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(flattenedEntries.length, (index) {
              final entry = flattenedEntries[index];
              final isLast = index == flattenedEntries.length - 1;

              if (entry.isGroupTitle) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: groupTitlePadding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: backgroundColor ?? colors.pulldownMenuBackground,
                        borderRadius:
                            index == 0
                                ? BorderRadius.only(
                                  topLeft: Radius.circular(borderRadius),
                                  topRight: Radius.circular(borderRadius),
                                )
                                : null,
                      ),
                      child: Text(
                        entry.groupTitle!,
                        style:
                            groupTitleStyle ??
                            CoconutTypography.body3_12.copyWith(
                              color: groupTitleColor ?? colors.secondaryText,
                            ),
                      ),
                    ),
                    if (!isLast) _buildDivider(context, entry.groupItemIndex),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulldownMenuItemButton(
                    title: entry.item!.title,
                    index: entry.itemIndex!,
                    isDisabled: entry.item!.isDisabled,
                    hasSwitch: entry.item!.hasSwitch,
                    switchValue: entry.item!.switchValue,
                    isTopRounded: _isTopRounded(flattenedEntries, index),
                    isBottomRounded: _isBottomRounded(flattenedEntries, index),
                    borderRadius: borderRadius,
                    backgroundColor: backgroundColor ?? colors.pulldownMenuBackground,
                    buttonHeight: buttonHeight,
                    buttonPadding: buttonPadding,
                    textColor: textColor ?? colors.pulldownMenuTextColor,
                    disabledTextColor: colors.secondaryText,
                    isSelectedItemBold: isSelectedItemBold ?? false,
                    selectedIndex: selectedIndex,
                    iconSize: iconSize,
                    iconColor: iconColor ?? colors.pulldownMenuTextColor,
                    splashColor: splashColor ?? colors.pulldownMenuPressedColor,
                    switchActiveTrackColor: switchActiveTrackColor,
                    switchThumbColor: switchThumbColor,
                    switchInactiveTrackColor: switchInactiveTrackColor,
                    onTap:
                        entry.item!.isDisabled
                            ? null
                            : () {
                              if (entry.item!.hasSwitch) {
                                final nextValue = !entry.item!.switchValue;
                                onSwitchChanged?.call(entry.itemIndex!, nextValue);
                                entry.item!.onSwitchChanged?.call(nextValue);
                              } else {
                                onSelected(entry.itemIndex!, entry.item!.title);
                              }
                            },
                  ),
                  if (!isLast) _buildDivider(context, entry.itemIndex),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  bool _isTopRounded(List<_FlattenedEntry> entries, int index) {
    if (index != 0) {
      return entries[index - 1].isGroupTitle;
    }
    return !entries[index].isGroupTitle;
  }

  bool _isBottomRounded(List<_FlattenedEntry> entries, int index) {
    if (index == entries.length - 1) {
      return !entries[index].isGroupTitle;
    }
    return entries[index + 1].isGroupTitle;
  }

  Widget _buildDivider(BuildContext context, int? index) {
    final colors = context.coconutColors;
    final isThick = index != null && (thickDividerIndexList?.contains(index) ?? false);
    return Container(
      height: isThick ? thickDividerHeight : dividerHeight,
      color: dividerColor ?? colors.pulldownMenuDividerColor,
    );
  }
}

class _FlattenedEntry {
  const _FlattenedEntry.group(this.groupTitle)
    : item = null,
      itemIndex = null,
      groupItemIndex = null,
      isGroupTitle = true;

  const _FlattenedEntry.item(this.item, this.itemIndex)
    : groupTitle = null,
      groupItemIndex = itemIndex,
      isGroupTitle = false;

  final bool isGroupTitle;
  final String? groupTitle;
  final CoconutPulldownMenuItem? item;
  final int? itemIndex;
  final int? groupItemIndex;
}

class _PulldownMenuItemButton extends StatefulWidget {
  const _PulldownMenuItemButton({
    required this.title,
    required this.index,
    required this.isDisabled,
    required this.hasSwitch,
    required this.switchValue,
    required this.isTopRounded,
    required this.isBottomRounded,
    required this.borderRadius,
    required this.backgroundColor,
    required this.buttonHeight,
    required this.textColor,
    required this.disabledTextColor,
    required this.isSelectedItemBold,
    required this.selectedIndex,
    required this.iconSize,
    required this.iconColor,
    required this.splashColor,
    required this.onTap,
    this.buttonPadding,
    this.switchActiveTrackColor,
    this.switchThumbColor,
    this.switchInactiveTrackColor,
  });

  final String title;
  final int index;
  final bool isDisabled;
  final bool hasSwitch;
  final bool switchValue;
  final bool isTopRounded;
  final bool isBottomRounded;
  final double borderRadius;
  final Color backgroundColor;
  final double buttonHeight;
  final EdgeInsets? buttonPadding;
  final Color textColor;
  final Color disabledTextColor;
  final bool isSelectedItemBold;
  final int? selectedIndex;
  final double iconSize;
  final Color iconColor;
  final Color splashColor;
  final Color? switchActiveTrackColor;
  final Color? switchThumbColor;
  final Color? switchInactiveTrackColor;
  final VoidCallback? onTap;

  @override
  State<_PulldownMenuItemButton> createState() => _PulldownMenuItemButtonState();
}

class _PulldownMenuItemButtonState extends State<_PulldownMenuItemButton> {
  bool _isPressed = false;

  BorderRadius get _borderRadius => BorderRadius.only(
    topLeft: widget.isTopRounded ? Radius.circular(widget.borderRadius) : Radius.zero,
    topRight: widget.isTopRounded ? Radius.circular(widget.borderRadius) : Radius.zero,
    bottomLeft: widget.isBottomRounded ? Radius.circular(widget.borderRadius) : Radius.zero,
    bottomRight: widget.isBottomRounded ? Radius.circular(widget.borderRadius) : Radius.zero,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: _borderRadius),
      child: GestureDetector(
        onTapDown: widget.isDisabled ? null : (_) => setState(() => _isPressed = true),
        onTapUp:
            widget.isDisabled
                ? null
                : (_) {
                  setState(() => _isPressed = false);
                  widget.onTap?.call();
                },
        onTapCancel: widget.isDisabled ? null : () => setState(() => _isPressed = false),
        child: Container(
          height: widget.buttonHeight,
          padding: widget.buttonPadding ?? const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: _isPressed ? widget.splashColor : Colors.transparent,
            borderRadius: _borderRadius,
          ),
          child: Row(
            children: [
              Text(
                widget.title,
                style: CoconutTypography.body2_14.copyWith(
                  color: widget.isDisabled ? widget.disabledTextColor : widget.textColor,
                  fontWeight:
                      widget.isSelectedItemBold
                          ? (widget.selectedIndex == widget.index ? FontWeight.bold : FontWeight.normal)
                          : null,
                ),
              ),
              const SizedBox(width: 16),
              const Spacer(),
              if (widget.hasSwitch)
                IgnorePointer(
                  child: CoconutSwitch(
                    isOn: widget.switchValue,
                    onChanged: (_) {},
                    activeTrackColor: widget.switchActiveTrackColor,
                    activeThumbColor: widget.switchThumbColor,
                    inactiveTrackColor: widget.switchInactiveTrackColor,
                    scale: 0.6,
                  ),
                )
              else
                Visibility(
                  visible: widget.selectedIndex == widget.index,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  maintainInteractivity: true,
                  child: SvgPicture.asset(
                    'packages/coconut_design_system/assets/svg/pulldown_check.svg',
                    width: widget.iconSize,
                    height: widget.iconSize,
                    colorFilter: ColorFilter.mode(widget.iconColor, BlendMode.srcIn),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
