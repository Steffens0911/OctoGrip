import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

/// Tela de parceiros da academia para divulgação aos alunos.
class PartnersScreen extends StatefulWidget {
  /// Academia do usuário (aluno vê só os parceiros da sua academia).
  final String academyId;

  const PartnersScreen({super.key, required this.academyId});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  final ApiService _api = ApiService();
  List<Partner> _partners = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getPartners(widget.academyId);
      if (mounted) {
        setState(() {
          _partners = list;
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

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nossos parceiros'),
      ),
      body: Padding(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  )
                : _partners.isEmpty
                    ? Center(
                        child: Text(
                          'Em breve novidades aqui.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textSecondaryOf(context),
                              ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppTheme.primary,
                        child: ListView.builder(
                          itemCount: _partners.length,
                          itemBuilder: (context, i) {
                            final p = _partners[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (p.logoUrl != null && p.logoUrl!.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              p.logoUrl!.startsWith('/') ? '${_api.baseUrl}${p.logoUrl}' : p.logoUrl!,
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
                                            ),
                                          ),
                                        if (p.logoUrl != null && p.logoUrl!.isNotEmpty) const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                p.name,
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                      color: AppTheme.textPrimary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                              if (p.description != null && p.description!.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  p.description!,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        color: AppTheme.textSecondaryOf(context),
                                                      ),
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                              if (p.url != null && p.url!.isNotEmpty) ...[
                                                const SizedBox(height: 10),
                                                FilledButton.tonalIcon(
                                                  onPressed: () => _openUrl(p.url),
                                                  icon: const Icon(Icons.open_in_new, size: 18),
                                                  label: const Text('Conhecer'),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
