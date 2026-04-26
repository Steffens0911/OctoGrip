import 'package:flutter/material.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_feedback.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

/// Formulário criar/editar parceiro da academia.
class PartnerFormScreen extends StatefulWidget {
  final Academy academy;
  final Partner? partner;

  const PartnerFormScreen({super.key, required this.academy, this.partner});

  @override
  State<PartnerFormScreen> createState() => _PartnerFormScreenState();
}

class _PartnerFormScreenState extends State<PartnerFormScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _offerTextController = TextEditingController();
  final _externalUrlController = TextEditingController();
  final _featuredOrderController = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _highlightOnLogin = false;
  bool _isFeatured = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final p = widget.partner;
    if (p != null) {
      _nameController.text = p.name;
      _descriptionController.text = p.description ?? '';
      _urlController.text = p.url ?? '';
      _logoUrlController.text = p.logoUrl ?? '';
      _highlightOnLogin = p.highlightOnLogin;
      _offerTextController.text = p.offerText ?? '';
      _externalUrlController.text = p.externalUrl ?? '';
      _featuredOrderController.text = p.featuredOrder?.toString() ?? '';
      _isFeatured = p.isFeatured;
      _isActive = p.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
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
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final url = _urlController.text.trim();
    final logoUrl = _logoUrlController.text.trim();
    final offerText = _offerTextController.text.trim();
    final externalUrl = _externalUrlController.text.trim();
    final featuredOrderRaw = _featuredOrderController.text.trim();
    final featuredOrder = featuredOrderRaw.isEmpty ? null : int.tryParse(featuredOrderRaw);
    try {
      if (widget.partner != null) {
        await _api.updatePartner(
          partnerId: widget.partner!.id,
          academyId: widget.academy.id,
          name: name,
          description: description.isEmpty ? null : description,
          url: url.isEmpty ? null : url,
          logoUrl: logoUrl.isEmpty ? null : logoUrl,
          highlightOnLogin: _highlightOnLogin,
          isActive: _isActive,
          isFeatured: _isFeatured,
          featuredOrder: _isFeatured ? featuredOrder : null,
          offerText: offerText.isEmpty ? null : offerText,
          externalUrl: externalUrl.isEmpty ? null : externalUrl,
        );
      } else {
        await _api.createPartner(
          academyId: widget.academy.id,
          name: name,
          description: description.isEmpty ? null : description,
          url: url.isEmpty ? null : url,
          logoUrl: logoUrl.isEmpty ? null : logoUrl,
          highlightOnLogin: _highlightOnLogin,
          isActive: _isActive,
          isFeatured: _isFeatured,
          featuredOrder: _isFeatured ? featuredOrder : null,
          offerText: offerText.isEmpty ? null : offerText,
          externalUrl: externalUrl.isEmpty ? null : externalUrl,
        );
      }
      if (mounted) {
        AppFeedback.show(
          context,
          message: widget.partner != null ? 'Parceiro atualizado' : 'Parceiro criado',
          type: AppFeedbackType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.partner != null;
    return Scaffold(
      appBar: AppStandardAppBar(
        title: isEdit ? 'Editar parceiro' : 'Novo parceiro',
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
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL / site (opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'https://...',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _logoUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL do logo (opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'https://... ou /media/...',
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Usar no pop-up inicial do aluno'),
                subtitle: const Text(
                  'Quando um aluno desta academia fizer login, este parceiro poderá aparecer aleatoriamente em destaque.',
                ),
                value: _highlightOnLogin,
                onChanged: (v) {
                  setState(() {
                    _highlightOnLogin = v;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Destacar na Central'),
                subtitle: const Text(
                  'Exibe este parceiro no banner rotativo no topo da Central da academia.',
                ),
                value: _isFeatured,
                onChanged: (v) {
                  setState(() {
                    _isFeatured = v;
                    if (!v) _featuredOrderController.text = '';
                  });
                },
              ),
              if (_isFeatured) ...[
                const SizedBox(height: 8),
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
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativo'),
                subtitle: const Text('Se desativado, não aparece para alunos.'),
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
