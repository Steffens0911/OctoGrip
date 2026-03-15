import 'package:flutter/material.dart';

import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';

class OpponentPickerSheet extends StatefulWidget {
  final String academyId;
  final String currentUserId;
  final String title;
  final bool allowSkip;

  const OpponentPickerSheet({
    super.key,
    required this.academyId,
    required this.currentUserId,
    this.title = 'Em quem voce aplicou a tecnica?',
    this.allowSkip = false,
  });

  static Future<String?> show(
    BuildContext context, {
    required String academyId,
    required String currentUserId,
    String title = 'Em quem voce aplicou a tecnica?',
    bool allowSkip = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => OpponentPickerSheet(
        academyId: academyId,
        currentUserId: currentUserId,
        title: title,
        allowSkip: allowSkip,
      ),
    );
  }

  @override
  State<OpponentPickerSheet> createState() => _OpponentPickerSheetState();
}

class _OpponentPickerSheetState extends State<OpponentPickerSheet> {
  final _api = ApiService();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<UserModel> _all = [];
  String _query = '';
  String _beltFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.getUsers(academyId: widget.academyId);
      final colleagues = list
          .where((u) => u.id != widget.currentUserId)
          .toList()
        ..sort((a, b) {
          final aName = (a.name ?? a.email).toLowerCase();
          final bName = (b.name ?? b.email).toLowerCase();
          return aName.compareTo(bName);
        });

      if (!mounted) return;
      setState(() {
        _all = colleagues;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingMessage(e);
        _loading = false;
      });
    }
  }

  List<UserModel> get _filtered {
    return _all.where((u) {
      final name = (u.name ?? '').toLowerCase();
      final email = u.email.toLowerCase();
      final belt = (u.graduation ?? '').toLowerCase();

      final matchesQuery =
          _query.isEmpty || name.contains(_query) || email.contains(_query);

      final matchesBelt = switch (_beltFilter) {
        'white' => belt == 'white',
        'blue' => belt == 'blue',
        'purple_plus' => belt == 'purple' || belt == 'brown' || belt == 'black',
        _ => true,
      };

      return matchesQuery && matchesBelt;
    }).toList();
  }

  static String _faixaLabel(String? graduation) {
    if (graduation == null || graduation.isEmpty) return 'Sem faixa';
    switch (graduation.toLowerCase()) {
      case 'white':
        return 'Branca';
      case 'blue':
        return 'Azul';
      case 'purple':
        return 'Roxa';
      case 'brown':
        return 'Marrom';
      case 'black':
        return 'Preta';
      default:
        return graduation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: _all.length > 5,
              decoration: const InputDecoration(
                labelText: 'Buscar por nome ou e-mail',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _beltFilter == 'all',
                  onSelected: (_) => setState(() => _beltFilter = 'all'),
                ),
                ChoiceChip(
                  label: const Text('Branca'),
                  selected: _beltFilter == 'white',
                  onSelected: (_) => setState(() => _beltFilter = 'white'),
                ),
                ChoiceChip(
                  label: const Text('Azul'),
                  selected: _beltFilter == 'blue',
                  onSelected: (_) => setState(() => _beltFilter = 'blue'),
                ),
                ChoiceChip(
                  label: const Text('Roxa+'),
                  selected: _beltFilter == 'purple_plus',
                  onSelected: (_) => setState(() => _beltFilter = 'purple_plus'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              )
            else if (_all.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.allowSkip
                      ? 'Nenhum colega disponivel na academia. Voce pode registrar sem oponente.'
                      : 'Nenhum colega disponivel na academia.',
                ),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum colega encontrado com esse filtro.'),
              )
            else
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(user.name ?? user.email),
                        subtitle: Text(_faixaLabel(user.graduation)),
                        onTap: () => Navigator.pop(context, user.id),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                if (widget.allowSkip) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(context, ''),
                      child: const Text('Sem oponente'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
