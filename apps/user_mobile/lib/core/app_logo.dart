import 'package:flutter/material.dart';

/// A reusable app logo widget that renders the main logo asset
/// with optional title text next to it.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showTitle;
  final TextStyle? titleStyle;
  final String title;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AppLogo({
    super.key,
    this.size = 40,
    this.showTitle = false,
    this.title = 'UPS',
    this.titleStyle,
    this.padding = const EdgeInsets.all(0),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: size,
            width: size,
            fit: BoxFit.contain,
            color: color,
          ),
          if (showTitle) ...[
            const SizedBox(width: 8),
            Text(
              title,
              style:
                  titleStyle ??
                  theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
