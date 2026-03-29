import 'package:flutter/material.dart';

enum AppFeedbackType { success, info, warning, error }

class AppFeedback {
  static void show(
    BuildContext context, {
    required String message,
    required AppFeedbackType type,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (type) {
      AppFeedbackType.success => (
          const Color(0xFF1B5E20),
          Colors.white,
          Icons.check_circle_outline
        ),
      AppFeedbackType.info => (colorScheme.primary, Colors.white, Icons.info_outline),
      AppFeedbackType.warning => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
          Icons.warning_amber_outlined
        ),
      AppFeedbackType.error => (colorScheme.error, colorScheme.onError, Icons.error_outline),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        content: Row(
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
