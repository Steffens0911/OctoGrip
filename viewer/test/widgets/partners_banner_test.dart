import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/models/global_partner.dart';
import 'package:viewer/models/partner.dart';
import 'package:viewer/widgets/student/featured_partners_banner.dart';
import 'package:viewer/widgets/student/academy_partners_training_banner.dart';

import '../helpers/pump_app.dart';

// FeaturedPartnersBanner e AcademyPartnersTrainingBanner:
// Widgets com dados via construtor (List<Partner/GlobalPartner>), sem API calls.
// Com lista vazia: sem timer, sem conteúdo de parceiro.
// Com 1 item: sem timer (só avança com 2+), exibe o item.

GlobalPartner _globalPartner({String id = 'gp1', String name = 'Parceiro Global'}) =>
    GlobalPartner(id: id, name: name);

Partner _partner({String id = 'p1', String name = 'Parceiro Local'}) =>
    Partner(id: id, academyId: 'ac1', name: name);

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FeaturedPartnersBanner — lista vazia', () {
    testWidgets('renderiza sem crash com lista vazia', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FeaturedPartnersBanner(partners: const []),
        ),
      ));
      await tester.pump();

      expect(find.byType(FeaturedPartnersBanner), findsOneWidget);
    });
  });

  group('FeaturedPartnersBanner — com parceiro', () {
    testWidgets('renderiza sem crash com 1 parceiro', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FeaturedPartnersBanner(
            partners: [_globalPartner(name: 'Nike')],
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(FeaturedPartnersBanner), findsOneWidget);
    });

    testWidgets('exibe nome do parceiro', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FeaturedPartnersBanner(
            partners: [_globalPartner(name: 'Nike')],
          ),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Nike'), findsWidgets);
    });
  });

  group('AcademyPartnersTrainingBanner — lista vazia', () {
    testWidgets('renderiza sem crash com lista vazia', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AcademyPartnersTrainingBanner(partners: const []),
        ),
      ));
      await tester.pump();

      expect(find.byType(AcademyPartnersTrainingBanner), findsOneWidget);
    });
  });

  group('AcademyPartnersTrainingBanner — com parceiro', () {
    testWidgets('renderiza sem crash com 1 parceiro', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AcademyPartnersTrainingBanner(
            partners: [_partner(name: 'Adidas')],
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(AcademyPartnersTrainingBanner), findsOneWidget);
    });

    testWidgets('exibe nome do parceiro', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AcademyPartnersTrainingBanner(
            partners: [_partner(name: 'Adidas')],
          ),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Adidas'), findsWidgets);
    });
  });
}
