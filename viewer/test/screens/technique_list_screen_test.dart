import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/presentation/pages/techniques_list_page.dart';
import 'package:viewer/features/techniques/presentation/providers/technique_providers.dart';
import 'package:viewer/features/techniques/presentation/state/technique_list_notifier.dart';
import 'package:viewer/features/techniques/presentation/state/technique_list_state.dart';
import 'package:viewer/screens/admin/technique_list_screen.dart';

import '../helpers/pump_app.dart';

class _FakeNotifier extends TechniqueListNotifier {
  @override
  TechniqueListState build(String academyId) => TechniqueListState(
        academyId: academyId,
        isInitialLoading: false,
      );

  @override
  Future<void> refresh() async {}
}

void main() {
  setUpAll(disableGoogleFontsFetch);

  testWidgets('TechniqueListScreen renderiza TechniquesListPage', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          techniqueListNotifierProvider.overrideWith(() => _FakeNotifier()),
        ],
        child: const MaterialApp(
          home: TechniqueListScreen(academyId: 'ac1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TechniquesListPage), findsOneWidget);
  });
}
