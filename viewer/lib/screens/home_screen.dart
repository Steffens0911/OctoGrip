import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';

/// Tela inicial do viewer (conteúdo para o usuário comum).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/branding/flowroll_app_icon.png',
              width: 96,
              height: 96,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 24),
            Text(
              'FlowRoll',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use o menu para acessar a Administração.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
