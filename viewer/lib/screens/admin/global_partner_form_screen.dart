import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/global_partner.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class GlobalPartnerFormScreen extends StatefulWidget {
  final GlobalPartner? partner;

  const GlobalPartnerFormScreen({super.key, this.partner});

  @override
  State<GlobalPartnerFormScreen> createState() => _GlobalPartnerFormScreenState();
}

class _GlobalPartnerFormScreenState extends State<GlobalPartnerFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _offerTextController = TextEditingController();
  final _externalUrlController = TextEditingController();
  final _featuredOrderController = TextEditingController();

  bool _isActive = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.partner;
    if (p != null) {
      _nameController.text = p.name;
      _descriptionController.text = p.description ?? '';
      _logoUrlController.text = p.logoUrl ?? '';
      _offerTextController.text = p.offerText ?? '';
      _externalUrlController.text = p.externalUrl ?? '';
      _featuredOrderController.text = p.featuredOrder?.toString() ?? '';
      _isActive = p.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _logoUrlController.dispose();
    _offerTextController.dispose();
    _externalUrlController.dispose();
    _featuredOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final featuredOrderRaw = _featuredOrderController.text.trim();
    final featuredOrder = featuredOrderRaw.isEmpty ? null : int.tryParse(featuredOrderRaw);
    try {
      if (widget.partner == null) {
        await _api.createGlobalPartner(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          logoUrl: _logoUrlController.text.trim().isEmpty
              ? null
              : _logoUrlController.text.trim(),
          offerText: _offerTextController.text.trim().isEmpty
              ? null
              : _offerTextController.text.trim(),
          externalUrl: _externalUrlController.text.trim().isEmpty
              ? null
              : _externalUrlController.text.trim(),
          featuredOrder: featuredOrder,
          isActive: _isActive,
        );
      } else {
        await _api.updateGlobalPartner(
          id: widget.partner!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          logoUrl: _logoUrlController.text.trim().isEmpty
              ? null
              : _logoUrlController.text.trim(),
          offerText: _offerTextController.text.trim().isEmpty
              ? null
              : _offerTextController.text.trim(),
          externalUrl: _externalUrlController.text.trim().isEmpty
              ? null
              : _externalUrlController.text.trim(),
          featuredOrder: featuredOrder,
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      AppFeedback.show(
        context,
        message: widget.partner == null ? 'Parceiro global criado' : 'Parceiro global atualizado',
        type: AppFeedbackType.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = userFacingMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.partner != null;
    return Scaffold(
      appBar: AppStandardAppBar(
        title: isEdit ? 'Editar parceiro global' : 'Novo parceiro global',
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o nome';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _logoUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL do logo (opcional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _offerTextController,
                decoration: const InputDecoration(
                  labelText: 'Texto da oferta (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _externalUrlController,
                decoration: const InputDecoration(
                  labelText: 'Link externo / WhatsApp (opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'https://... ou wa.me/...',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _featuredOrderController,
                decoration: const InputDecoration(
                  labelText: 'Ordem de exibição (opcional)',
                  border: OutlineInputBorder(),
                  hintText: '1, 2, 3...',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return null;
                  final n = int.tryParse(s);
                  if (n == null) return 'Informe um número inteiro';
                  if (n < 0) return 'Use 0 ou maior';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                subtitle: const Text('Se desativado, não aparece no banner da Central.'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_saving ? 'Salvando...' : (isEdit ? 'Salvar' : 'Criar')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
