import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';

enum AppScreenStateType { loading, error, empty, content }

class AppScreenState extends StatelessWidget {
  const AppScreenState.loading({super.key})
      : type = AppScreenStateType.loading,
        message = null,
        onRetry = null,
        child = null;

  const AppScreenState.error({
    super.key,
    required this.message,
    required this.onRetry,
  })  : type = AppScreenStateType.error,
        child = null;

  const AppScreenState.empty({
    super.key,
    required this.message,
    this.onRetry,
  })  : type = AppScreenStateType.empty,
        child = null;

  const AppScreenState.content({
    super.key,
    required this.child,
  })  : type = AppScreenStateType.content,
        message = null,
        onRetry = null;

  final AppScreenStateType type;
  final String? message;
  final VoidCallback? onRetry;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case AppScreenStateType.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        );
      case AppScreenStateType.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message ?? 'Não foi possível carregar agora.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        );
      case AppScreenStateType.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  color: AppTheme.textMutedOf(context),
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  message ?? 'Nenhum item encontrado.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  TextButton(onPressed: onRetry, child: const Text('Atualizar')),
                ],
              ],
            ),
          ),
        );
      case AppScreenStateType.content:
        return child ?? const SizedBox.shrink();
    }
  }
}
