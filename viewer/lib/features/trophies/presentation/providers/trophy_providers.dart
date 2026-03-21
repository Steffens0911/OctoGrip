import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/features/trophies/presentation/state/trophy_list_notifier.dart';
import 'package:viewer/features/trophies/presentation/state/trophy_list_state.dart';

export 'package:viewer/features/trophies/presentation/providers/trophy_di.dart';

final trophyListNotifierProvider = NotifierProvider.autoDispose
    .family<TrophyListNotifier, TrophyListState, String>(
  TrophyListNotifier.new,
);
