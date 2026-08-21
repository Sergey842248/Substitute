import 'package:flutter/material.dart';

class ListItem extends StatelessWidget {
  ListItem({
    Key? key,
    required this.title,
    this.subtitle,
    this.actionButton,
    this.leading,
    this.padding,
    this.margin,
    required this.onClick,
    this.color,
    this.shadow,
    this.borderRadius,
  }) : super(key: key);

  final Widget title;
  final Widget? subtitle;
  final Widget? actionButton;
  final Widget? leading;
  final Function onClick;
  final Color? color;
  final double? padding;
  final double? margin;
  final BorderRadius? borderRadius;
  bool? shadow;

  @override
  Widget build(BuildContext context) {
    shadow ??= false;
    final BorderRadius radius = borderRadius == null
        ? BorderRadius.circular(25)
        : borderRadius!;
    return Container(
      margin: EdgeInsets.all(margin == null ? 5 : margin!),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow!
            ? [
                BoxShadow(
                  color: Theme.of(context).focusColor.withValues(alpha: 0.1),
                  blurRadius: 5, // soften the shadow
                  spreadRadius: 0.1, //extend the shadow
                ),
              ]
            : null,
      ),
      // A Material widget is required so that child widgets (InkWell,
      // DropdownButton, IconButton, ...) can find a Material ancestor even
      // when this ListItem is rendered inside a ListView/PageView, whose
      // children are wrapped in a LookupBoundary that blocks lookups to the
      // Scaffold's Material above it.
      child: Material(
        color: this.color == null
            ? Theme.of(context).colorScheme.surface
            : this.color,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          onTap: () => this.onClick(),
          child: Padding(
            padding: EdgeInsets.all(padding == null ? 9 : padding!),
            child: ListTile(
              leading: this.leading,
              title: this.title,
              subtitle: this.subtitle != null ? this.subtitle : null,
              trailing: this.actionButton,
            ),
          ),
        ),
      ),
    );
  }
}
