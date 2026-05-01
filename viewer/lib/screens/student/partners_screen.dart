import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:viewer/app_theme.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

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
  static const int _pageSize = 20;
  List<Partner> _partners = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = true}) async {
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _offset = 0;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final list = await _api.getPartners(
        widget.academyId,
        offset: _offset,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          if (reset) {
            _partners = list;
            _loading = false;
          } else {
            _partners = [..._partners, ...list];
            _loadingMore = false;
          }
          _offset += list.length;
          _hasMore = list.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(e);
          if (reset) {
            _loading = false;
          } else {
            _loadingMore = false;
          }
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
      appBar: const AppStandardAppBar(title: 'Nossos parceiros'),
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
                        onRefresh: () => _load(reset: true),
                        color: AppTheme.primary,
                        child: ListView.builder(
                          itemCount: _partners.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= _partners.length) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Center(
                                  child: _loadingMore
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton.icon(
                                          onPressed: () => _load(reset: false),
                                          icon: const Icon(Icons.expand_more),
                                          label: const Text('Carregar mais'),
                                        ),
                                ),
                              );
                            }
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
                                            child: CachedNetworkImage(
                                              imageUrl: p.logoUrl!.startsWith('/') ? '${_api.baseUrl}${p.logoUrl}' : p.logoUrl!,
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => const SizedBox(
                                                width: 48,
                                                height: 48,
                                                child: Center(
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              ),
                                              errorWidget: (_, __, ___) => const SizedBox(width: 48, height: 48),
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
                                                      color: AppTheme.textPrimaryOf(context),
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
