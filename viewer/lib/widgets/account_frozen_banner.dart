import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';

/// Aviso quando o aluno está em modo leitura (conta congelada pelo gestor/admin).
class AccountFrozenBanner extends StatelessWidget {
  const AccountFrozenBanner({
    super.key,
    required this.reason,
  });

  /// Motivo da API ou texto padrão.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final text = (reason != null && reason!.trim().isNotEmpty)
        ? reason!.trim()
        : 'Sua conta está em modo leitura. Regularize sua situação com a academia para treinar e pontuar novamente.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
            color: Colors.amber.shade900.withValues(alpha: 0.12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade800, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimaryOf(context),
                        height: 1.35,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
