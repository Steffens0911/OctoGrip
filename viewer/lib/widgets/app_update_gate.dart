import 'package:flutter/material.dart';

import 'package:viewer/branding/app_brand.dart';
import 'package:viewer/services/app_update_service.dart';

/// Envolve o app inteiro (MaterialApp.builder):
/// - versão abaixo da mínima → tela cheia que bloqueia o uso até atualizar;
/// - versão abaixo da mais recente → aviso no rodapé, que o usuário pode dispensar.
class AppUpdateGate extends StatelessWidget {
  const AppUpdateGate({super.key, required this.child, this.service});

  final Widget child;

  /// Injetável em testes; padrão é [AppUpdateService.instance].
  final AppUpdateService? service;

  @override
  Widget build(BuildContext context) {
    final updates = service ?? AppUpdateService.instance;
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        if (updates.status == AppUpdateStatus.required) {
          return UpdateRequiredScreen(service: updates);
        }
        if (!updates.showOptionalPrompt) return child;
        return Stack(
          children: [
            child,
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(child: _OptionalUpdateBar(service: updates)),
            ),
          ],
        );
      },
    );
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.service});

  final AppUpdateService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = service.message?.trim().isNotEmpty == true
        ? service.message!
        : 'Há uma nova versão do ${AppBrand.name}. Atualize o app para continuar.';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(AppBrand.logoAsset, height: 96),
                  const SizedBox(height: 32),
                  Text(
                    'Atualização necessária',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    key: const Key('update-required-button'),
                    onPressed: service.openStore,
                    icon: const Icon(Icons.system_update),
                    label: const Text('Atualizar agora'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionalUpdateBar extends StatelessWidget {
  const _OptionalUpdateBar({required this.service});

  final AppUpdateService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Nova versão do ${AppBrand.name} disponível.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: service.dismissOptional,
              child: const Text('Agora não'),
            ),
            FilledButton(
              key: const Key('update-optional-button'),
              onPressed: service.openStore,
              child: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
