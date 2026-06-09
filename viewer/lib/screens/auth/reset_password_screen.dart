import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/branding/app_brand.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/api_base_persist.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_error_message.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _done = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final muted = AppTheme.textMutedOf(context);
    final r = BorderRadius.circular(12);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      prefixIcon: Icon(icon, color: muted, size: 22),
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(color: muted),
      border: OutlineInputBorder(borderRadius: r),
      enabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ApiService().resetPassword(
        widget.token,
        _passwordController.text,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cardBg = theme.cardTheme.color ?? cs.surfaceContainerHighest;
    final cardBorder = AppTheme.borderOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: cardBorder.withValues(alpha: 0.95),
                  ),
                  boxShadow: theme.brightness == Brightness.light
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          AppBrand.logoAsset,
                          width: 160,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Nova senha',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (!_done) ...[
                        Text(
                          'Crie uma nova senha para a sua conta.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMutedOf(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                              color: AppTheme.textPrimaryOf(context)),
                          decoration: _fieldDecoration(
                            context,
                            label: 'Nova senha',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppTheme.textMutedOf(context),
                                size: 22,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Informe a nova senha';
                            }
                            if (v.trim().isEmpty) {
                              return 'A senha não pode ser vazia';
                            }
                            if (v.length < 8) {
                              return 'Mínimo 8 caracteres';
                            }
                            return null;
                          },
                          enabled: !_loading,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          style: TextStyle(
                              color: AppTheme.textPrimaryOf(context)),
                          decoration: _fieldDecoration(
                            context,
                            label: 'Confirmar nova senha',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirm
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppTheme.textMutedOf(context),
                                size: 22,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Confirme a nova senha';
                            }
                            if (v != _passwordController.text) {
                              return 'As senhas não coincidem';
                            }
                            return null;
                          },
                          enabled: !_loading,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          AppErrorMessage(message: _error!),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            disabledBackgroundColor:
                                cs.primary.withValues(alpha: 0.45),
                            disabledForegroundColor:
                                cs.onPrimary.withValues(alpha: 0.55),
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.6,
                            ),
                          ),
                          child: _loading
                              ? SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Text('Redefinir senha'),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 52,
                          color: cs.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Senha redefinida com sucesso!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Faça login com a sua nova senha.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMutedOf(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () {
                            redirectToRoot();
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.6,
                            ),
                          ),
                          child: const Text('Ir para o login'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
