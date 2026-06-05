import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:viewer/features/photos/presentation/state/photos_feed_notifier.dart';
import 'package:viewer/features/photos/presentation/state/photos_feed_state.dart';
import 'package:viewer/features/photos/presentation/state/photos_user_feed_notifier.dart';

export 'package:viewer/features/techniques/presentation/providers/technique_di.dart'
    show apiServiceProvider;

final photosFeedNotifierProvider = NotifierProvider.autoDispose
    .family<PhotosFeedNotifier, PhotosFeedState, String>(
  PhotosFeedNotifier.new,
);

/// Provider para o feed de fotos de um aluno específico.
/// Key: "academyId|authorId"
final photosUserFeedNotifierProvider = NotifierProvider.autoDispose
    .family<PhotosUserFeedNotifier, PhotosFeedState, String>(
  PhotosUserFeedNotifier.new,
);
