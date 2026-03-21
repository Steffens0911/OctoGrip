import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/features/trophies/presentation/pages/trophies_list_page.dart';

/// Lista de troféus da academia — delega ao módulo Clean Architecture + Riverpod.
class TrophyListScreen extends ConsumerWidget {
  const TrophyListScreen({
    super.key,
    required this.academyId,
    required this.academyName,
  });

  final String academyId;
  final String academyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TrophiesListPage(
      academyId: academyId,
      academyName: academyName,
    );
  }
}
