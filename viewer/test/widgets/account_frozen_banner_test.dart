import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/widgets/account_frozen_banner.dart';

import '../helpers/pump_app.dart';

void main() {
  setUpAll(disableGoogleFontsFetch);

  group('AccountFrozenBanner', () {
    testWidgets('exibe o motivo passado pelo caller', (tester) async {
      await tester.pumpWidget(wrapApp(
        const AccountFrozenBanner(reason: 'Mensalidade em atraso'),
      ));

      expect(find.text('Mensalidade em atraso'), findsOneWidget);
    });

    testWidgets('usa texto padrão quando reason é nulo', (tester) async {
      await tester.pumpWidget(wrapApp(
        const AccountFrozenBanner(reason: null),
      ));

      expect(
        find.textContaining('modo leitura'),
        findsOneWidget,
      );
    });

    testWidgets('usa texto padrão quando reason é só espaços', (tester) async {
      await tester.pumpWidget(wrapApp(
        const AccountFrozenBanner(reason: '   '),
      ));

      expect(find.textContaining('modo leitura'), findsOneWidget);
    });

    testWidgets('mostra ícone de info', (tester) async {
      await tester.pumpWidget(wrapApp(
        const AccountFrozenBanner(reason: null),
      ));

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });
}
