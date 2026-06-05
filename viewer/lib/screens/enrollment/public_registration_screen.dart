import 'package:flutter/material.dart';

import 'package:viewer/branding/app_brand.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart' show userFacingMessage;

const _belts = [
  'white',
  'blue',
  'purple',
  'brown',
  'black',
];

const _beltLabels = {
  'white': 'Branca',
  'blue': 'Azul',
  'purple': 'Roxa',
  'brown': 'Marrom',
  'black': 'Preta',
};

/// Tela pública de cadastro — acessada via link de convite (sem login).
class PublicRegistrationScreen extends StatefulWidget {
  final String token;

  const PublicRegistrationScreen({super.key, required this.token});

  @override
  State<PublicRegistrationScreen> createState() =>
      _PublicRegistrationScreenState();
}

class _PublicRegistrationScreenState extends State<PublicRegistrationScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String? _academyName;
  String? _selectedBelt;
  bool _loading = true;
  bool _submitting = false;
  bool _success = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInviteInfo();
  }

  Future<void> _loadInviteInfo() async {
    try {
      final info = await _api.getInvitePublicInfo(widget.token);
      if (mounted) {
        setState(() {
          _academyName = info['academy_name'] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.submitEnrollment(
        widget.token,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        confirmPassword: _confirmCtrl.text,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        graduation: _selectedBelt,
      );
      if (mounted) setState(() => _success = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = userFacingMessage(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _loading
                  ? const CircularProgressIndicator()
                  : _error != null && _academyName == null
                      ? _buildError()
                      : _success
                          ? _buildSuccess()
                          : _buildForm(cs, tt),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_off, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Link inválido',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Este link de convite não existe ou foi desativado.',
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildSuccess() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
          const SizedBox(height: 20),
          Text(
            'Solicitação enviada!',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Aguarde a aprovação da academia $_academyName.\n'
            'Você receberá acesso assim que for aprovado.',
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildForm(ColorScheme cs, TextTheme tt) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo e cabeçalho
            Center(
              child: Text(
                AppBrand.name,
                style: tt.headlineMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Cadastro — $_academyName',
                style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Nome
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome completo *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe seu nome.' : null,
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'E-mail *',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe seu e-mail.';
                if (!v.contains('@')) return 'E-mail inválido.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Celular (opcional)
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Celular (opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // Faixa (opcional)
            DropdownButtonFormField<String>(
              value: _selectedBelt,
              decoration: const InputDecoration(
                labelText: 'Faixa atual (opcional)',
                prefixIcon: Icon(Icons.emoji_events_outlined),
              ),
              items: _belts
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(_beltLabels[b] ?? b),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBelt = v),
            ),
            const SizedBox(height: 16),

            // Senha
            TextFormField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'Senha *',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              obscureText: !_showPassword,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe uma senha.';
                if (v.length < 6) return 'Mínimo 6 caracteres.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirmar senha
            TextFormField(
              controller: _confirmCtrl,
              decoration: InputDecoration(
                labelText: 'Confirmar senha *',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      _showConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              obscureText: !_showConfirm,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirme sua senha.';
                if (v != _passwordCtrl.text) return 'As senhas não coincidem.';
                return null;
              },
            ),
            const SizedBox(height: 8),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Solicitar cadastro'),
            ),
          ],
        ),
      );
}
