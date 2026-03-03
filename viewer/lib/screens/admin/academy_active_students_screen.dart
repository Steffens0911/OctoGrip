import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viewer/app_theme.dart';
import 'package:viewer/models/academy.dart';
import 'package:viewer/models/active_students_report.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/auth_service.dart';
import 'package:viewer/utils/error_message.dart';
import 'package:viewer/utils/form_utils.dart';
import 'package:viewer/widgets/role_guard.dart';

class AcademyActiveStudentsScreen extends StatefulWidget {
  final Academy academy;

  const AcademyActiveStudentsScreen({
    super.key,
    required this.academy,
  });

  @override
  State<AcademyActiveStudentsScreen> createState() =>
      _AcademyActiveStudentsScreenState();
}

class _AcademyActiveStudentsScreenState
    extends State<AcademyActiveStudentsScreen> {
  final ApiService _api = ApiService();

  late DateTime _referenceDate;
  ActiveStudentsReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _referenceDate = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.getActiveStudentsReport(
        referenceDate: _referenceDate,
        academyId: widget.academy.id,
      );
      if (!mounted) return;
      setState(() {
        _report = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingMessage(e);
      });
    }
  }

  Future<void> _pickReferenceDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _referenceDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Selecione a data de referência',
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _referenceDate = DateTime(picked.year, picked.month, picked.day);
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['administrador', 'gerente_academia', 'supervisor'],
      child: Scaffold(
        appBar: AppBar(
          title: Text('Alunos ativos · ${widget.academy.name}'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _error!,
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      );
    }
    if (_report == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            'Ainda não há dados suficientes para este relatório.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      );
    }

    final r = _report!;
    final windowText =
        '${toBrDate(r.startDate)} a ${toBrDate(r.endDate)} (últimos 7 dias)';

    return ListView(
      padding: EdgeInsets.all(AppTheme.screenPadding(context)),
      children: [
        Text(
          'Alunos ativos na academia',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimaryOf(context),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Um aluno é considerado ativo se tiver feito pelo menos 1 login nos últimos 7 dias em relação à data de referência.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryOf(context),
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Data de referência: ${toBrDate(_referenceDate)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _pickReferenceDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: const Text('Alterar data'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  windowText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${r.activeStudents} de ${r.totalStudents} alunos ativos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: r.totalStudents > 0
                        ? (r.activeRate / 100.0).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 10,
                    backgroundColor: AppTheme.surfaceOf(context),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (r.students.isEmpty)
          const Text(
            'Nenhum aluno ativo na janela selecionada.',
            style: TextStyle(color: AppTheme.textSecondary),
          )
        else ...[
          Text(
            'Alunos ativos (${r.students.length}):',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          _buildStudentsList(context, r.students),
        ],
      ],
    );
  }

  Widget _buildStudentsList(
    BuildContext context,
    List<ActiveStudent> students,
  ) {
    final dtFormatter = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = students[index];
        final name = (s.name != null && s.name!.trim().isNotEmpty)
            ? s.name!
            : s.email;
        final roleText =
            s.graduation != null ? 'Faixa: ${s.graduation}' : 'Aluno';
        final lastLogin = s.lastLoginAt != null
            ? dtFormatter.format(s.lastLoginAt!.toLocal())
            : 'Nunca';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            child: const Icon(Icons.person, color: AppTheme.primary),
          ),
          title: Text(name),
          subtitle: Text(
            '$roleText · Último login: $lastLogin',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: AuthService().isAdmin()
              ? Text(
                  s.academyName ?? '',
                  style: TextStyle(
                    color: AppTheme.textSecondaryOf(context),
                    fontSize: 12,
                  ),
                )
              : null,
        );
      },
    );
  }
}

