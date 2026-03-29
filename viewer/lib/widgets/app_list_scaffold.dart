import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';

class AppListScaffold extends StatelessWidget {
  const AppListScaffold({
    super.key,
    required this.children,
    this.topFilters,
    this.onRefresh,
    this.padding,
  });

  final List<Widget> children;
  final Widget? topFilters;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding ?? const EdgeInsets.all(16),
      children: [
        if (topFilters != null) ...[
          topFilters!,
          const SizedBox(height: 12),
        ],
        ...children,
      ],
    );

    if (onRefresh == null) return content;
    return RefreshIndicator(
      onRefresh: onRefresh!,
      color: AppTheme.primary,
      child: content,
    );
  }
}
