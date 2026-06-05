import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Sheet de confirmação simples antes de registrar a execução.
/// Mostra "Você aplicou [técnica] em [colega]?" e aguarda Confirmar ou Cancelar.
class ExecutionConfirmSheet extends StatelessWidget {
  final String techniqueName;
  final String opponentName;

  const ExecutionConfirmSheet({
    super.key,
    required this.techniqueName,
    required this.opponentName,
  });

  static Future<bool> show(
    BuildContext context, {
    required String techniqueName,
    required String opponentName,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PointerInterceptor(
        child: ExecutionConfirmSheet(
          techniqueName: techniqueName,
          opponentName: opponentName,
        ),
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Confirmar indicação', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.sports_martial_arts,
                      color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyLarge,
                        children: [
                          const TextSpan(text: 'Você aplicou '),
                          TextSpan(
                            text: techniqueName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const TextSpan(text: ' em '),
                          TextSpan(
                            text: opponentName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: '?'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
