import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/features/techniques/presentation/state/technique_list_notifier.dart';
import 'package:viewer/features/techniques/presentation/state/technique_list_state.dart';

export 'technique_di.dart';

/// Notifier por academia — `autoDispose` libera debounce ao sair da tela.
/// Após CRUD: invalida cache HTTP/Hive e recarrega lista do servidor.
final techniqueListNotifierProvider = NotifierProvider.autoDispose
    .family<TechniqueListNotifier, TechniqueListState, String>(
  TechniqueListNotifier.new,
);
