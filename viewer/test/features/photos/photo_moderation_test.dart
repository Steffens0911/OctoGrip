import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viewer/features/photos/presentation/pages/blocked_users_screen.dart';
import 'package:viewer/features/photos/presentation/pages/photo_detail_screen.dart';
import 'package:viewer/features/photos/presentation/pages/photo_reports_screen.dart';
import 'package:viewer/features/photos/presentation/pages/photos_feed_screen.dart';
import 'package:viewer/models/academy_photo.dart';
import 'package:viewer/models/photo_moderation.dart';
import 'package:viewer/services/api_service.dart';

import '../../helpers/pump_app.dart';

// Denunciar e bloquear no feed de fotos (exigência de conteúdo de usuário da Google Play).

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _post(String id, String authorId, String authorName) => {
      'id': id,
      'academy_id': 'ac1',
      'author': {'id': authorId, 'name': authorName},
      'caption': 'post $id',
      'status': 'ready',
      'is_system_post': true,
      'system_post_type': 'trophy',
      'created_at': '2026-10-24T10:00:00Z',
    };

class _Fake {
  _Fake(
      {this.feed = const [],
      this.comments = const [],
      this.reports = const [],
      this.blocked = const []});

  List<Map<String, dynamic>> feed;
  List<Map<String, dynamic>> comments;
  List<Map<String, dynamic>> reports;
  List<Map<String, dynamic>> blocked;
  final List<String> calls = [];
  final List<Object?> bodies = [];

  MockClient get client => MockClient((request) async {
        final path = request.url.path;
        calls.add('${request.method} $path');
        if (request.body.isNotEmpty) bodies.add(jsonDecode(request.body));
        if (request.method == 'GET') {
          if (path.endsWith('/photos/blocks')) return _json(blocked);
          if (path.endsWith('/photos/reports')) return _json(reports);
          if (path.endsWith('/comments')) return _json(comments);
          if (path.endsWith('/photos')) {
            return _json({'items': feed, 'next_cursor': null});
          }
        }
        if (request.method == 'PUT' && path.contains('/photos/blocks/')) {
          // como o servidor: os comentários do bloqueado deixam de vir
          final blockedId = path.split('/').last;
          comments = comments
              .where((c) => (c['author'] as Map)['id'] != blockedId)
              .toList();
          return http.Response('', 204);
        }
        if (request.method == 'DELETE' && path.contains('/photos/blocks/')) {
          blocked = [];
          return http.Response('', 204);
        }
        if (request.method == 'POST' && path.endsWith('/report')) {
          // como o servidor: o comentário denunciado deixa de vir para quem denunciou
          final parts = path.split('/');
          if (path.contains('/comments/')) {
            final commentId = parts[parts.length - 2];
            comments = comments.where((c) => c['id'] != commentId).toList();
          }
          return _json(
              {'id': 'r1', 'status': 'open', 'already_reported': false}, 201);
        }
        if (request.method == 'PATCH' && path.contains('/photos/reports/')) {
          reports = [];
          return _json({'id': 'r1', 'status': 'removed'});
        }
        return _json({});
      });
}

Widget _feed() => const ProviderScope(
      child:
          MaterialApp(home: Scaffold(body: PhotosFeedScreen(academyId: 'ac1'))),
    );

Future<void> _openMenuOf(WidgetTester tester, String postId) async {
  final card = find.byKey(ValueKey(postId));
  await tester
      .tap(find.descendant(of: card, matching: find.byIcon(Icons.more_vert)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    disableGoogleFontsFetch();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setAuthForTesting(user: stubStudent(id: 'eu'));
  });

  tearDown(() {
    ApiService().setHttpClientForTesting(http.Client());
    ApiService().invalidateCache();
    clearAuthForTesting();
  });

  group('modelos tolerantes', () {
    test('PhotoReport e BlockedUser aceitam JSON vazio', () {
      expect(() => PhotoReport.fromJson(<String, dynamic>{}), returnsNormally);
      expect(() => BlockedUser.fromJson(<String, dynamic>{}), returnsNormally);
    });

    test('motivo desconhecido vira "Outro motivo"', () {
      expect(photoReportReasonLabel('novo_motivo_da_api'), 'Outro motivo');
      expect(photoReportReasonLabel('spam'), 'Spam ou propaganda');
    });
  });

  group('feed: denunciar e bloquear', () {
    testWidgets('menu de post de outra pessoa oferece denunciar e bloquear',
        (tester) async {
      final fake = _Fake(feed: [_post('p1', 'u2', 'Maria')]);
      ApiService().setHttpClientForTesting(fake.client);
      await tester.pumpWidget(_feed());
      await tester.pumpAndSettle();

      await _openMenuOf(tester, 'p1');

      expect(find.text('Denunciar post'), findsOneWidget);
      expect(find.text('Bloquear Maria'), findsOneWidget);
    });

    testWidgets('menu do próprio post não oferece denunciar nem bloquear',
        (tester) async {
      final fake = _Fake(feed: [_post('p1', 'eu', 'Eu mesmo')]);
      ApiService().setHttpClientForTesting(fake.client);
      await tester.pumpWidget(_feed());
      await tester.pumpAndSettle();

      await _openMenuOf(tester, 'p1');

      expect(find.text('Denunciar post'), findsNothing);
      expect(find.textContaining('Bloquear'), findsNothing);
    });

    testWidgets('denunciar envia o motivo e some só aquele post',
        (tester) async {
      final fake =
          _Fake(feed: [_post('p1', 'u2', 'Maria'), _post('p2', 'u3', 'João')]);
      ApiService().setHttpClientForTesting(fake.client);
      await tester.pumpWidget(_feed());
      await tester.pumpAndSettle();

      await _openMenuOf(tester, 'p1');
      await tester.tap(find.text('Denunciar post'));
      await tester.pumpAndSettle();

      // sem escolher o motivo, não dá para enviar
      expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('report-send')))
              .onPressed,
          isNull);

      await tester.tap(find.byKey(const Key('report-reason-harassment')));
      await tester.enterText(
          find.byKey(const Key('report-details')), 'ofensas no comentário');
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();

      expect(fake.calls, contains('POST /academies/ac1/photos/p1/report'));
      expect(fake.bodies.last,
          {'reason': 'harassment', 'details': 'ofensas no comentário'});
      expect(find.byKey(const ValueKey('p1')), findsNothing);
      expect(find.byKey(const ValueKey('p2')), findsOneWidget);
    });

    testWidgets('cancelar a denúncia não envia nada', (tester) async {
      final fake = _Fake(feed: [_post('p1', 'u2', 'Maria')]);
      ApiService().setHttpClientForTesting(fake.client);
      await tester.pumpWidget(_feed());
      await tester.pumpAndSettle();

      await _openMenuOf(tester, 'p1');
      await tester.tap(find.text('Denunciar post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(fake.calls.where((c) => c.endsWith('/report')), isEmpty);
      expect(find.byKey(const ValueKey('p1')), findsOneWidget);
    });

    testWidgets('bloquear pede confirmação e some todos os posts do autor',
        (tester) async {
      final fake = _Fake(feed: [
        _post('p1', 'u2', 'Maria'),
        _post('p2', 'u2', 'Maria'),
        _post('p3', 'u3', 'João'),
      ]);
      ApiService().setHttpClientForTesting(fake.client);
      await tester.pumpWidget(_feed());
      await tester.pumpAndSettle();

      await _openMenuOf(tester, 'p1');
      await tester.tap(find.text('Bloquear Maria'));
      await tester.pumpAndSettle();
      expect(find.text('Bloquear Maria?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
      await tester.pumpAndSettle();

      expect(fake.calls, contains('PUT /academies/ac1/photos/blocks/u2'));
      expect(find.byKey(const ValueKey('p1')), findsNothing);
      expect(find.byKey(const ValueKey('p2')), findsNothing);
      expect(find.byKey(const ValueKey('p3')), findsOneWidget);
    });

    testWidgets('erro do servidor ao denunciar mantém o post e avisa',
        (tester) async {
      final fake = _Fake(feed: [_post('p1', 'u2', 'Maria')]);
      ApiService().setHttpClientForTesting(MockClient((request) async {
        if (request.method == 'POST') return _json({'detail': 'Falhou'}, 500);
        return fake.client
            .send(http.Request(request.method, request.url))
            .then(http.Response.fromStream);
      }));
      await tester.pumpWidget(_feed());
      await tester.pumpAndSettle();

      await _openMenuOf(tester, 'p1');
      await tester.tap(find.text('Denunciar post'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-reason-spam')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('p1')), findsOneWidget);
    });
  });

  group('faixa de atalhos do feed', () {
    testWidgets('aluno vê só "Bloqueados"', (tester) async {
      ApiService().setHttpClientForTesting(_Fake().client);
      await tester.pumpWidget(_feed());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('open-blocked')), findsOneWidget);
      expect(find.byKey(const Key('open-reports')), findsNothing);
    });

    testWidgets(
        'gerente também vê "Denúncias", e a faixa aparece com o feed vazio',
        (tester) async {
      setAuthForTesting(user: stubStudent(id: 'g1', role: 'gerente_academia'));
      ApiService().setHttpClientForTesting(_Fake().client);
      await tester.pumpWidget(_feed());
      await tester.pumpAndSettle();

      expect(find.text('Nenhum post ainda.\nSeja o primeiro a compartilhar!'),
          findsOneWidget);
      expect(find.byKey(const Key('open-reports')), findsOneWidget);
      expect(find.byKey(const Key('open-blocked')), findsOneWidget);
    });
  });

  group('usuários bloqueados', () {
    testWidgets('lista e desbloqueia', (tester) async {
      final fake = _Fake(blocked: [
        {
          'user_id': 'u2',
          'name': 'Maria',
          'created_at': '2026-10-24T10:00:00Z'
        },
      ]);
      ApiService().setHttpClientForTesting(fake.client);
      await tester.pumpWidget(
          const MaterialApp(home: BlockedUsersScreen(academyId: 'ac1')));
      await tester.pumpAndSettle();

      expect(find.text('Maria'), findsOneWidget);
      await tester.tap(find.byKey(const Key('unblock-u2')));
      await tester.pumpAndSettle();

      expect(fake.calls, contains('DELETE /academies/ac1/photos/blocks/u2'));
      expect(find.text('Você não bloqueou ninguém.'), findsOneWidget);
    });

    testWidgets('lista vazia mostra o aviso', (tester) async {
      ApiService().setHttpClientForTesting(_Fake().client);
      await tester.pumpWidget(
          const MaterialApp(home: BlockedUsersScreen(academyId: 'ac1')));
      await tester.pumpAndSettle();

      expect(find.text('Você não bloqueou ninguém.'), findsOneWidget);
    });
  });

  group('denúncias para o gerente', () {
    Map<String, dynamic> report() => {
          'id': 'r1',
          'status': 'open',
          'reason': 'nudity',
          'details': 'foto imprópria',
          'created_at': '2026-10-24T10:00:00Z',
          'reporter_name': 'Ana',
          'photo_id': 'p1',
          'target_type': 'photo',
          'target_author_name': 'Maria',
          'target_text': 'legenda do post',
          'reports_on_target': 2,
        };

    testWidgets('mostra o resumo e mantém o conteúdo', (tester) async {
      final fake = _Fake(reports: [report()]);
      ApiService().setHttpClientForTesting(fake.client);
      await tester.pumpWidget(
          const MaterialApp(home: PhotoReportsScreen(academyId: 'ac1')));
      await tester.pumpAndSettle();

      expect(find.text('Post de Maria'), findsOneWidget);
      expect(find.text('legenda do post'), findsOneWidget);
      expect(find.textContaining('Nudez ou conteúdo sexual'), findsOneWidget);
      expect(find.textContaining('2 denúncias'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dismiss-r1')));
      await tester.pumpAndSettle();

      expect(fake.calls, contains('PATCH /academies/ac1/photos/reports/r1'));
      expect(fake.bodies.last, {'action': 'dismiss'});
      expect(find.text('Nenhuma denúncia aberta.'), findsOneWidget);
    });

    testWidgets('remover pede confirmação antes de apagar', (tester) async {
      final fake = _Fake(reports: [report()]);
      ApiService().setHttpClientForTesting(fake.client);
      await tester.pumpWidget(
          const MaterialApp(home: PhotoReportsScreen(academyId: 'ac1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('remove-r1')));
      await tester.pumpAndSettle();
      expect(find.text('Remover post?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(fake.calls.where((c) => c.startsWith('PATCH')), isEmpty);

      await tester.tap(find.byKey(const Key('remove-r1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover').last);
      await tester.pumpAndSettle();

      expect(fake.bodies.last, {'action': 'remove'});
    });
  });

  group('comentários', () {
    Future<_Fake> abrirDetalhe(WidgetTester tester) async {
      final fake = _Fake(comments: [
        {
          'id': 'c1',
          'photo_id': 'p1',
          'author': {'id': 'u9', 'name': 'Pedro'},
          'body': 'comentário ofensivo',
          'created_at': '2026-10-24T10:00:00Z',
        },
        {
          'id': 'c2',
          'photo_id': 'p1',
          'author': {'id': 'eu', 'name': 'Eu'},
          'body': 'meu comentário',
          'created_at': '2026-10-24T10:01:00Z',
        },
      ]);
      ApiService().setHttpClientForTesting(fake.client);
      await tester.pumpWidget(MaterialApp(
        home: PhotoDetailScreen(
          photo: AcademyPhoto.fromJson(_post('p1', 'u2', 'Maria')),
          academyId: 'ac1',
          currentUserId: 'eu',
          isModerator: false,
          onLike: () {},
          onUnlike: () {},
          onDelete: () {},
        ),
      ));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('só comentários de outras pessoas têm o menu', (tester) async {
      await abrirDetalhe(tester);

      expect(find.byKey(const Key('comment-menu-c1')), findsOneWidget);
      expect(find.byKey(const Key('comment-menu-c2')), findsNothing);
    });

    testWidgets('denunciar comentário envia e esconde só esse comentário',
        (tester) async {
      final fake = await abrirDetalhe(tester);

      await tester.tap(find.byKey(const Key('comment-menu-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Denunciar comentário'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-reason-harassment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-send')));
      await tester.pumpAndSettle();

      expect(fake.calls,
          contains('POST /academies/ac1/photos/p1/comments/c1/report'));
      expect(
          find.text('comentário ofensivo', findRichText: true), findsNothing);
      expect(find.text('meu comentário', findRichText: true), findsOneWidget);
    });

    testWidgets('bloquear o autor de um comentário esconde os comentários dele',
        (tester) async {
      final fake = await abrirDetalhe(tester);

      await tester.tap(find.byKey(const Key('comment-menu-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bloquear Pedro'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
      await tester.pumpAndSettle();

      expect(fake.calls, contains('PUT /academies/ac1/photos/blocks/u9'));
      expect(
          find.text('comentário ofensivo', findRichText: true), findsNothing);
    });
  });
}
