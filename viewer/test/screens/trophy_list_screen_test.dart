import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/trophies/presentation/pages/trophies_list_page.dart';
import 'package:viewer/features/trophies/presentation/providers/trophy_providers.dart';
import 'package:viewer/features/trophies/presentation/state/trophy_list_notifier.dart';
import 'package:viewer/features/trophies/presentation/state/trophy_list_state.dart';
import 'package:viewer/screens/admin/trophy_list_screen.dart';

import '../helpers/pump_app.dart';

class _FakeNotifier extends TrophyListNotifier {
  @override
  TrophyListState build(String academyId) => TrophyListState(
        academyId: academyId,
        isInitialLoading: false,
      );

  @override
  Future<void> refresh() async {}
}

void main() {
  setUpAll(disableGoogleFontsFetch);

  testWidgets('TrophyListScreen renderiza TrophiesListPage', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trophyListNotifierProvider.overrideWith(() => _FakeNotifier()),
        ],
        child: const MaterialApp(
          home: TrophyListScreen(academyId: 'ac1', academyName: 'Octogrip'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TrophiesListPage), findsOneWidget);
  });
}
