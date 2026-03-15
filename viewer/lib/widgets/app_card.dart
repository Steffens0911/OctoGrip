import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/design/app_tokens.dart';

/// Card reutilizável com superfície, borda e radius do tema (Memo).
/// Use em todas as telas para consistência visual.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool useShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.useShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppTheme.borderOf(context)),
        boxShadow: useShadow ? AppShadow.card(context) : null,
      ),
      child: child,
    );
  }
}
