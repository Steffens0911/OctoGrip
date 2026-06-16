import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:viewer/services/api_service.dart';

class MockApiService extends Mock implements ApiService {}

class MockHttpClient extends Mock implements http.Client {}
