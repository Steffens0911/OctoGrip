import 'package:flutter/material.dart';
import 'package:viewer/design/app_tokens.dart';

/// Bloco de mensagem de erro com ícone e texto. Usa cor de erro do tema.
class AppErrorMessage extends StatelessWidget {
  final String message;

  const AppErrorMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.1),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: errorColor, size: 20),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: errorColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
