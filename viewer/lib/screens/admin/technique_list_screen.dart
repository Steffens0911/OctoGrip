import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/features/techniques/presentation/pages/techniques_list_page.dart';

/// Lista de técnicas (vínculo a troféus e posições da semana) — delega ao módulo Clean + Riverpod.
class TechniqueListScreen extends ConsumerWidget {
  final String academyId;

  const TechniqueListScreen({super.key, required this.academyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TechniquesListPage(academyId: academyId);
  }
}
