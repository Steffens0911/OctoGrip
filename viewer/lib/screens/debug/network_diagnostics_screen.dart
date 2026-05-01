import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:viewer/services/network_diagnostics_service.dart';
import 'package:viewer/widgets/app_standard_app_bar.dart';

class NetworkDiagnosticsScreen extends StatelessWidget {
  const NetworkDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final details = NetworkDiagnosticsService.lastErrorDetails;
    final at = NetworkDiagnosticsService.lastErrorAt;
    final contextName = NetworkDiagnosticsService.lastErrorContext;

    final info = StringBuffer()
      ..writeln('API base atual: ${NetworkDiagnosticsService.apiBase}')
      ..writeln('Plataforma: ${NetworkDiagnosticsService.platformName}')
      ..writeln('Modo: ${NetworkDiagnosticsService.runtimeEnv}')
      ..writeln('Origem atual: ${NetworkDiagnosticsService.currentOrigin}');

    if (at != null) {
      info.writeln(
        'Último erro em: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(at)}',
      );
    }
    if (contextName != null && contextName.isNotEmpty) {
      info.writeln('Contexto: $contextName');
    }
    if (details != null && details.isNotEmpty) {
      info.writeln('\nErro técnico:\n$details');
    } else {
      info.writeln('\nErro técnico:\n(nenhum erro registrado nesta sessão)');
    }

    final text = info.toString().trimRight();

    return Scaffold(
      appBar: AppStandardAppBar(
        title: 'Diagnóstico de conexão',
        actions: [
          IconButton(
            tooltip: 'Copiar detalhes',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Diagnóstico copiado.')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectableText(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
