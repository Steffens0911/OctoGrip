import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/models/global_partner.dart';
import 'package:viewer/models/lesson.dart';
import 'package:viewer/models/marketplace_item.dart';
import 'package:viewer/models/partner.dart';

// Testes unitários para modelos de conteúdo: Lesson, MarketplaceItem,
// GlobalPartner e Partner.

void main() {
  group('Lesson.fromJson', () {
    test('desserializa todos os campos', () {
      final l = Lesson.fromJson({
        'id': 'ls1',
        'academy_id': 'ac1',
        'title': 'Triângulo',
        'slug': 'triangulo',
        'video_url': 'https://example.com/v.mp4',
        'content': 'Descrição da aula',
        'order_index': 3,
        'technique_id': 'tc1',
        'technique_name': 'Finalização',
        'position_name': 'Guarda',
        'technique_video_url': 'https://example.com/tv.mp4',
      });

      expect(l.id, 'ls1');
      expect(l.title, 'Triângulo');
      expect(l.slug, 'triangulo');
      expect(l.orderIndex, 3);
      expect(l.techniqueId, 'tc1');
      expect(l.techniqueName, 'Finalização');
    });

    test('aceita campos opcionais nulos', () {
      final l = Lesson.fromJson({
        'id': 'ls2',
        'title': 'Aula sem vídeo',
        'slug': 'aula-sem-video',
        'order_index': 1,
        'technique_id': 'tc2',
      });

      expect(l.videoUrl, isNull);
      expect(l.content, isNull);
      expect(l.academyId, isNull);
    });
  });

  group('MarketplaceItem.fromAdminJson', () {
    test('desserializa todos os campos', () {
      final m = MarketplaceItem.fromAdminJson({
        'id': 'mi1',
        'academy_id': 'ac1',
        'academy_name': 'Academia Teste',
        'title': 'Kimono',
        'description': 'Kimono A2',
        'price_cents': 29900,
        'currency': 'BRL',
        'image_url': 'https://example.com/kimono.jpg',
        'whatsapp_url': 'https://wa.me/55...',
        'whatsapp_ddd': '11',
        'whatsapp_number': '999999999',
        'sort_order': 1,
        'is_active': true,
        'whatsapp_clicks': 5,
      });

      expect(m.id, 'mi1');
      expect(m.title, 'Kimono');
      expect(m.priceCents, 29900);
      expect(m.currency, 'BRL');
      expect(m.isActive, isTrue);
      expect(m.whatsappClicks, 5);
    });

    test('usa defaults quando campos opcionais ausentes', () {
      final m = MarketplaceItem.fromAdminJson({
        'id': 'mi2',
        'title': 'Item simples',
      });

      expect(m.priceCents, 0);
      expect(m.currency, 'BRL');
      expect(m.isActive, isTrue);
      expect(m.description, isNull);
      expect(m.imageUrl, isNull);
      expect(m.sortOrder, isNull);
    });
  });

  group('MarketplaceItem.fromStudentJson', () {
    test('desserializa campos do aluno', () {
      final m = MarketplaceItem.fromStudentJson({
        'id': 'mi3',
        'title': 'Camiseta',
        'description': 'Camiseta do time',
        'price_cents': 8900,
        'currency': 'BRL',
        'image_url': 'https://example.com/camiseta.jpg',
        'whatsapp_url': 'https://wa.me/5511...',
      });

      expect(m.id, 'mi3');
      expect(m.title, 'Camiseta');
      expect(m.priceCents, 8900);
      expect(m.whatsappUrl, isNotNull);
    });
  });

  group('GlobalPartner.fromJson', () {
    test('desserializa todos os campos', () {
      final p = GlobalPartner.fromJson({
        'id': 'gp1',
        'name': 'Parceiro Global',
        'description': 'Desconto em suplementos',
        'logo_url': 'https://example.com/logo.png',
        'offer_text': '10% off',
        'external_url': 'https://parceiro.com',
        'button_label': 'Ver oferta',
        'featured_order': 1,
        'is_active': true,
      });

      expect(p.id, 'gp1');
      expect(p.name, 'Parceiro Global');
      expect(p.offerText, '10% off');
      expect(p.featuredOrder, 1);
      expect(p.isActive, isTrue);
    });

    test('aceita campos opcionais nulos', () {
      final p = GlobalPartner.fromJson({'id': 'gp2', 'name': 'Parceiro'});

      expect(p.description, isNull);
      expect(p.logoUrl, isNull);
      expect(p.isActive, isTrue);
    });
  });

  group('Partner.fromJson', () {
    test('desserializa todos os campos', () {
      final p = Partner.fromJson({
        'id': 'p1',
        'academy_id': 'ac1',
        'name': 'Fornecedor local',
        'description': 'Quimonos premium',
        'url': 'https://loja.com',
        'logo_url': 'https://example.com/logo.png',
        'button_label': 'Ver loja',
        'highlight_on_login': true,
      });

      expect(p.id, 'p1');
      expect(p.academyId, 'ac1');
      expect(p.name, 'Fornecedor local');
      expect(p.highlightOnLogin, isTrue);
    });

    test('highlightOnLogin default é false', () {
      final p = Partner.fromJson({
        'id': 'p2',
        'academy_id': 'ac1',
        'name': 'Parceiro simples',
      });

      expect(p.highlightOnLogin, isFalse);
      expect(p.url, isNull);
    });
  });
}
