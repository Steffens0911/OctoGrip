import 'package:intl/intl.dart';

/// Utilitários reutilizáveis para validação e formatação de formulários.

/// Formato de data para exibição em pt-BR (dd/MM/aaaa).
DateFormat get brDateFormat => DateFormat('dd/MM/yyyy', 'pt_BR');

/// Regex para validação de e-mail.
final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Valida e-mail. Retorna mensagem de erro ou null se válido.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'E-mail é obrigatório';
  }
  if (!emailRegex.hasMatch(value.trim())) {
    return 'Informe um e-mail válido';
  }
  return null;
}

/// Formata DateTime para exibição em pt-BR (dd/MM/aaaa).
String toBrDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Formata DateTime para envio à API (aaaa-MM-dd).
String toApiDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Converte string da API (aaaa-MM-dd) em DateTime. Retorna null se inválido.
DateTime? parseApiDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}
