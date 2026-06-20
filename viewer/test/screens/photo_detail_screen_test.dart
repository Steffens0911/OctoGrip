import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/features/photos/presentation/pages/photo_detail_screen.dart';
import 'package:viewer/models/academy_photo.dart';
import 'package:viewer/services/api_service.dart';

import '../helpers/mock_api_service.dart';
import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

AcademyPhoto _photo({
  String id = 'p1',
  String authorId = 'u1',
  String? authorName = 'Carlos Mendes',
  String? caption = 'Grande treino!',
  bool likedByMe = false,
  int likesCount = 3,
}) =>
    AcademyPhoto(
      id: id,
      academyId: 'ac1',
      author: PhotoAuthor(id: authorId, name: authorName),
      caption: caption,
      status: 'ready',
      likesCount: likesCount,
      likedByMe: likedByMe,
      isSystemPost: false,
      createdAt: DateTime(2026, 6, 10, 10, 0),
    );

Map<String, dynamic> _comment({
  String id = 'c1',
  String body = 'Boa foto!',
  String authorId = 'u2',
  String authorName = 'Ana Beatriz',
}) =>
    {
      'id': id,
      'photo_id': 'p1',
      'body': body,
      'author': {'id': authorId, 'name': authorName, 'avatar_url': null},
      'created_at': '2026-06-10T10:05:00',
    };

Widget _screen({AcademyPhoto? photo}) => MaterialApp(
      home: PhotoDetailScreen(
        photo: photo ?? _photo(),
        academyId: 'ac1',
        currentUserId: 'u-test',
        isModerator: false,
        onLike: () {},
        onUnlike: () {},
        onDelete: () {},
      ),
    );

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    disableGoogleFontsFetch();
    registerFallbackValue(Uri.parse('http://fallback'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting();
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('PhotoDetailScreen — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(PhotoDetailScreen), findsOneWidget);
    });

    testWidgets('exibe AppBar com título "Foto"', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // A tela de detalhe mostra "Foto" no AppBar; o nome do autor fica no PostCard (feed)
      expect(find.text('Foto'), findsOneWidget);
    });

    testWidgets('exibe legenda da foto', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen(photo: _photo(caption: 'Grande treino!')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Grande treino'), findsWidgets);
    });

    testWidgets('campo de comentário está presente', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });
  });

  group('PhotoDetailScreen — comentários', () {
    testWidgets('exibe comentário da API', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([_comment(body: 'Boa foto!')]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      // O body do comentário é renderizado em RichText (suporte a @menções),
      // por isso usamos byWidgetPredicate em vez de find.textContaining.
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Boa foto'),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('exibe nome do autor do comentário', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async =>
              _json([_comment(authorName: 'Ana Beatriz')]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Ana'), findsWidgets);
    });

    testWidgets('não trava sem comentários', (tester) async {
      final client = MockHttpClient();
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _json([]));
      ApiService().setHttpClientForTesting(client);

      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
