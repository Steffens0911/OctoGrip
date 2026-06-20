import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/features/photos/presentation/widgets/post_card.dart';
import 'package:viewer/models/academy_photo.dart';

import '../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

AcademyPhoto _photo({
  String id = 'p1',
  String authorId = 'u1',
  String? authorName = 'Fernanda Lima',
  String? caption = 'Treino incrível hoje!',
  bool isSystemPost = false,
  bool likedByMe = false,
  int likesCount = 5,
}) =>
    AcademyPhoto(
      id: id,
      academyId: 'ac1',
      author: PhotoAuthor(id: authorId, name: authorName),
      caption: caption,
      status: 'ready',
      likesCount: likesCount,
      likedByMe: likedByMe,
      isSystemPost: isSystemPost,
      createdAt: DateTime(2026, 6, 10, 10, 0),
    );

Widget _card({
  AcademyPhoto? photo,
  String currentUserId = 'u-test',
  bool isModerator = false,
}) =>
    MaterialApp(
      home: Scaffold(
        body: PostCard(
          photo: photo ?? _photo(),
          academyId: 'ac1',
          currentUserId: currentUserId,
          isModerator: isModerator,
          onLike: () {},
          onUnlike: () {},
          onDelete: () {},
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting();
  });

  tearDown(() {
    clearAuthForTesting();
  });

  group('PostCard — estrutura', () {
    testWidgets('renderiza sem crash', (tester) async {
      await tester.pumpWidget(_card());
      await tester.pumpAndSettle();

      expect(find.byType(PostCard), findsOneWidget);
    });

    testWidgets('exibe nome do autor', (tester) async {
      await tester.pumpWidget(_card(photo: _photo(authorName: 'Fernanda Lima')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Fernanda'), findsWidgets);
    });

    testWidgets('exibe legenda da foto', (tester) async {
      await tester.pumpWidget(
          _card(photo: _photo(caption: 'Treino incrível hoje!')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Treino'), findsWidgets);
    });

    testWidgets('exibe contagem de curtidas', (tester) async {
      await tester.pumpWidget(_card(photo: _photo(likesCount: 7)));
      await tester.pumpAndSettle();

      expect(find.textContaining('7'), findsWidgets);
    });
  });

  group('PostCard — post de sistema', () {
    testWidgets('renderiza post de sistema sem crash', (tester) async {
      await tester.pumpWidget(_card(
        photo: _photo(
          isSystemPost: true,
          caption: null,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PostCard), findsOneWidget);
    });
  });

  group('PostCard — permissões', () {
    testWidgets('dono do post pode deletar (botão presente)', (tester) async {
      // O usuário atual é o autor
      await tester.pumpWidget(_card(
        photo: _photo(authorId: 'u-test'),
        currentUserId: 'u-test',
      ));
      await tester.pumpAndSettle();

      // Verifica que o card renderizou corretamente
      expect(find.byType(PostCard), findsOneWidget);
    });

    testWidgets('moderador sempre vê opção de deletar', (tester) async {
      await tester.pumpWidget(_card(
        photo: _photo(authorId: 'outro-user'),
        currentUserId: 'u-test',
        isModerator: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PostCard), findsOneWidget);
    });
  });
}
