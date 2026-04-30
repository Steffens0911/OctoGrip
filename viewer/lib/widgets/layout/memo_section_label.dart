import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';

/// Label uppercase para secções (estilo Central / Memo).
class MemoSectionLabel extends StatelessWidget {
  const MemoSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.45,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMutedOf(context),
            ),
      ),
    );
  }
}
