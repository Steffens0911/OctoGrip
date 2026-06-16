import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/utils/youtube_utils.dart';

void main() {
  group('extractYouTubeVideoId', () {
    test('youtu.be encurtado', () {
      expect(extractYouTubeVideoId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('youtu.be com query extra', () {
      expect(
        extractYouTubeVideoId('https://youtu.be/dQw4w9WgXcQ?t=30'),
        'dQw4w9WgXcQ',
      );
    });

    test('watch?v= com e sem www', () {
      expect(
        extractYouTubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        extractYouTubeVideoId('https://youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('formatos embed e shorts', () {
      expect(
        extractYouTubeVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        extractYouTubeVideoId('https://youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('faz trim de espaços', () {
      expect(
        extractYouTubeVideoId('  https://youtu.be/dQw4w9WgXcQ  '),
        'dQw4w9WgXcQ',
      );
    });

    test('retorna null para nulo, vazio e URLs não-YouTube', () {
      expect(extractYouTubeVideoId(null), isNull);
      expect(extractYouTubeVideoId(''), isNull);
      expect(extractYouTubeVideoId('   '), isNull);
      expect(extractYouTubeVideoId('https://vimeo.com/12345'), isNull);
    });

    test('retorna null quando o id não tem 11 caracteres', () {
      expect(extractYouTubeVideoId('https://youtu.be/short'), isNull);
    });
  });

  group('isYouTubeUrl', () {
    test('true para URL válida, false para inválida', () {
      expect(isYouTubeUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(isYouTubeUrl('https://example.com'), isFalse);
      expect(isYouTubeUrl(null), isFalse);
    });
  });
}
