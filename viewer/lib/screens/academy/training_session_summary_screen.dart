import 'package:flutter/material.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class _Person {
  final String userId;
  final String? name;
  final String? avatarUrl;

  _Person({required this.userId, this.name, this.avatarUrl});

  factory _Person.fromJson(Map<String, dynamic> j) => _Person(
        userId: j['user_id'] as String,
        name: j['name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
      );

  String get displayName => (name?.trim().isNotEmpty == true) ? name! : userId.substring(0, 8);
}

class _Summary {
  final String? label;
  final String classDate;
  final String startTime;
  final int totalPreConfirmed;
  final int totalAttended;
  final List<_Person> confirmedAndAttended;
  final List<_Person> furos;
  final List<_Person> surpresas;

  _Summary({
    this.label,
    required this.classDate,
    required this.startTime,
    required this.totalPreConfirmed,
    required this.totalAttended,
    required this.confirmedAndAttended,
    required this.furos,
    required this.surpresas,
  });

  factory _Summary.fromJson(Map<String, dynamic> j) => _Summary(
        label: j['label'] as String?,
        classDate: j['class_date'] as String,
        startTime: j['start_time'] as String,
        totalPreConfirmed: j['total_pre_confirmed'] as int? ?? 0,
        totalAttended: j['total_attended'] as int? ?? 0,
        confirmedAndAttended: (j['confirmed_and_attended'] as List<dynamic>? ?? [])
            .map((e) => _Person.fromJson(e as Map<String, dynamic>))
            .toList(),
        furos: (j['furos'] as List<dynamic>? ?? [])
            .map((e) => _Person.fromJson(e as Map<String, dynamic>))
            .toList(),
        surpresas: (j['surpresas'] as List<dynamic>? ?? [])
            .map((e) => _Person.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Resumo pós-treino: pré-confirmados × presenças reais (furo inteligente).
class TrainingSessionSummaryScreen extends StatefulWidget {
  final String sessionId;
  final String sessionName;

  const TrainingSessionSummaryScreen({
    super.key,
    required this.sessionId,
    required this.sessionName,
  });

  @override
  State<TrainingSessionSummaryScreen> createState() =>
      _TrainingSessionSummaryScreenState();
}

class _TrainingSessionSummaryScreenState
    extends State<TrainingSessionSummaryScreen> {
  final ApiService _api = ApiService();
  _Summary? _summary;
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
      final raw = await _api.getTrainingSessionSummary(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _summary = _Summary.fromJson(raw);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppStandardAppBar(title: 'Resumo — ${widget.sessionName}'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final s = _summary!;
    final parts = s.classDate.split('-');
    final dateLabel = '${parts[2]}/${parts[1]}/${parts[0]}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(AppTheme.screenPadding(context)),
        children: [
          // Cabeçalho com números
          Text(
            '$dateLabel · ${s.startTime}',
            style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatCard(
                label: 'Confirmaram',
                value: s.totalPreConfirmed,
                color: const Color(0xFF378ADD),
                icon: Icons.thumb_up_alt_outlined,
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Vieram',
                value: s.totalAttended,
                color: const Color(0xFF1D9E75),
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Furos',
                value: s.furos.length,
                color: s.furos.isEmpty ? Colors.grey : Colors.orange.shade700,
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (s.furos.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              title: 'Confirmaram e não vieram (${s.furos.length})',
              subtitle: 'Deram furo',
            ),
            ...s.furos.map((p) => _PersonTile(person: p)),
            const SizedBox(height: 20),
          ],

          if (s.surpresas.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.star_outline_rounded,
              color: const Color(0xFF378ADD),
              title: 'Vieram sem confirmar (${s.surpresas.length})',
              subtitle: 'Surpresa positiva',
            ),
            ...s.surpresas.map((p) => _PersonTile(person: p)),
            const SizedBox(height: 20),
          ],

          if (s.confirmedAndAttended.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF1D9E75),
              title: 'Confirmaram e vieram (${s.confirmedAndAttended.length})',
              subtitle: 'Palavra cumprida',
            ),
            ...s.confirmedAndAttended.map((p) => _PersonTile(person: p)),
            const SizedBox(height: 20),
          ],

          if (s.totalPreConfirmed == 0 && s.totalAttended == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Nenhum pré-checkin ou presença registrado para este treino.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.85)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMutedOf(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final _Person person;

  const _PersonTile({required this.person});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundImage:
            person.avatarUrl != null ? NetworkImage(person.avatarUrl!) : null,
        child: person.avatarUrl == null
            ? Text(
                person.displayName.isNotEmpty
                    ? person.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(person.displayName),
    );
  }
}
