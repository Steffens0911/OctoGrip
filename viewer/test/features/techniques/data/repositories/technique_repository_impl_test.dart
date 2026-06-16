import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/techniques/data/datasources/technique_local_datasource.dart';
import 'package:viewer/features/techniques/data/datasources/technique_remote_datasource.dart';
import 'package:viewer/features/techniques/data/models/technique_dto.dart';
import 'package:viewer/features/techniques/data/repositories/technique_repository_impl.dart';
import 'package:viewer/features/techniques/domain/failures/technique_failure.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeRemote implements TechniqueRemoteDataSource {
  List<TechniqueDto> items = [];
  Object? fetchError;
  Object? createError;
  Object? updateError;
  Object? deleteError;
  TechniqueDto? createResult;
  TechniqueDto? updateResult;

  @override
  Future<List<TechniqueDto>> fetchAll(String academyId) async {
    if (fetchError != null) throw fetchError!;
    return items;
  }

  @override
  Future<TechniqueDto> create({
    required String academyId,
    required String name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    if (createError != null) throw createError!;
    return createResult ??
        TechniqueDto(
          id: 'new-id',
          academyId: academyId,
          name: name,
          slug: slug ?? name.toLowerCase(),
          description: description,
          videoUrl: videoUrl,
        );
  }

  @override
  Future<TechniqueDto> update({
    required String academyId,
    required String id,
    String? name,
    String? slug,
    String? description,
    String? videoUrl,
  }) async {
    if (updateError != null) throw updateError!;
    return updateResult ??
        TechniqueDto(
          id: id,
          academyId: academyId,
          name: name ?? '',
          slug: slug ?? '',
          description: description,
          videoUrl: videoUrl,
        );
  }

  @override
  Future<void> delete({required String academyId, required String id}) async {
    if (deleteError != null) throw deleteError!;
  }
}

class FakeLocal implements TechniqueLocalDataSource {
  final Map<String, List<TechniqueDto>> _store = {};
  Object? readError;
  Object? writeError;

  @override
  Future<List<TechniqueDto>?> read(String academyId) async {
    if (readError != null) throw const CacheTechniqueFailure('read failed');
    return _store[academyId];
  }

  @override
  Future<void> write(String academyId, List<TechniqueDto> items) async {
    if (writeError != null) throw const CacheTechniqueFailure('write failed');
    _store[academyId] = List<TechniqueDto>.from(items);
  }

  @override
  Future<void> clear(String academyId) async {
    _store.remove(academyId);
  }

  List<TechniqueDto>? get(String academyId) => _store[academyId];
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

TechniqueDto makeDto({String id = 'id1', String name = 'Armlock'}) =>
    TechniqueDto(id: id, academyId: 'ac1', name: name, slug: name.toLowerCase());

void main() {
  late FakeRemote remote;
  late FakeLocal local;
  late TechniqueRepositoryImpl repo;

  setUp(() {
    remote = FakeRemote();
    local = FakeLocal();
    repo = TechniqueRepositoryImpl(remote: remote, local: local);
  });

  // ---- getCached ----
  group('getCached', () {
    test('retorna Right([]) quando cache vazio', () async {
      final result = await repo.getCached('ac1');
      result.fold(
        (f) => fail('esperava Right mas recebeu Left($f)'),
        (list) => expect(list, isEmpty),
      );
    });

    test('retorna entidades quando há dados no cache', () async {
      local._store['ac1'] = [makeDto()];
      final result = await repo.getCached('ac1');
      result.fold(
        (f) => fail('esperava Right mas recebeu Left($f)'),
        (list) {
          expect(list, hasLength(1));
          expect(list.first.name, 'Armlock');
        },
      );
    });

    test('retorna Left(CacheTechniqueFailure) em erro de leitura', () async {
      local.readError = const CacheTechniqueFailure('read failed');
      final result = await repo.getCached('ac1');
      result.fold(
        (f) => expect(f, isA<CacheTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- syncFromRemote ----
  group('syncFromRemote', () {
    test('retorna Right com entidades e persiste no cache', () async {
      remote.items = [makeDto(), makeDto(id: 'id2', name: 'Triângulo')];
      final result = await repo.syncFromRemote('ac1');
      result.fold(
        (f) => fail('esperava Right'),
        (list) => expect(list, hasLength(2)),
      );
      expect(local.get('ac1'), hasLength(2));
    });

    test('retorna Left(NetworkTechniqueFailure) em erro de rede', () async {
      remote.fetchError = Exception('timeout');
      final result = await repo.syncFromRemote('ac1');
      result.fold(
        (f) => expect(f, isA<NetworkTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('retorna entidades mesmo quando Hive write falha (limpa cache)', () async {
      remote.items = [makeDto()];
      local.writeError = const CacheTechniqueFailure('write fail');
      final result = await repo.syncFromRemote('ac1');
      result.fold(
        (f) => fail('esperava Right mesmo com falha de cache'),
        (list) => expect(list, hasLength(1)),
      );
    });

    test('cache fica limpo após falha de write', () async {
      local._store['ac1'] = [makeDto(id: 'old')];
      remote.items = [makeDto()];
      local.writeError = const CacheTechniqueFailure('write fail');
      await repo.syncFromRemote('ac1');
      // _tryClearLocal remove a entrada corrompida
      expect(local.get('ac1'), isNull);
    });
  });

  // ---- create ----
  group('create', () {
    test('retorna Right com entidade criada', () async {
      remote.createResult = makeDto(id: 'new-id', name: 'Guarda');
      final result = await repo.create(academyId: 'ac1', name: 'Guarda');
      result.fold(
        (f) => fail('esperava Right'),
        (e) => expect(e.id, 'new-id'),
      );
    });

    test('novo item fica no cache local', () async {
      remote.createResult = makeDto(id: 'new-id', name: 'Guarda');
      await repo.create(academyId: 'ac1', name: 'Guarda');
      expect(local.get('ac1')?.any((d) => d.id == 'new-id'), isTrue);
    });

    test('retorna Left(NetworkTechniqueFailure) em erro remoto', () async {
      remote.createError = Exception('network error');
      final result = await repo.create(academyId: 'ac1', name: 'X');
      result.fold(
        (f) => expect(f, isA<NetworkTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- update ----
  group('update', () {
    test('retorna Right com entidade atualizada', () async {
      local._store['ac1'] = [makeDto()];
      remote.updateResult = TechniqueDto(
        id: 'id1',
        academyId: 'ac1',
        name: 'Armlock v2',
        slug: 'armlock-v2',
      );
      final result = await repo.update(academyId: 'ac1', id: 'id1', name: 'Armlock v2');
      result.fold(
        (f) => fail('esperava Right'),
        (e) => expect(e.name, 'Armlock v2'),
      );
    });

    test('substitui item no cache (merge preserva os demais)', () async {
      local._store['ac1'] = [makeDto(), makeDto(id: 'id2', name: 'Triângulo')];
      remote.updateResult = TechniqueDto(
        id: 'id1',
        academyId: 'ac1',
        name: 'Armlock v2',
        slug: 'armlock-v2',
      );
      await repo.update(academyId: 'ac1', id: 'id1', name: 'Armlock v2');
      final cached = local.get('ac1')!;
      expect(cached, hasLength(2));
      expect(cached.any((d) => d.name == 'Armlock v2'), isTrue);
      expect(cached.any((d) => d.name == 'Triângulo'), isTrue);
    });

    test('cache fica ordenado por nome após update', () async {
      local._store['ac1'] = [
        makeDto(id: 'id1', name: 'Zebra'),
        makeDto(id: 'id2', name: 'Armlock'),
      ];
      remote.updateResult = TechniqueDto(
        id: 'id1',
        academyId: 'ac1',
        name: 'Âncora',
        slug: 'ancora',
      );
      await repo.update(academyId: 'ac1', id: 'id1', name: 'Âncora');
      final cached = local.get('ac1')!;
      expect(cached.first.name.toLowerCase().compareTo(cached.last.name.toLowerCase()),
          lessThanOrEqualTo(0));
    });

    test('retorna Left(NetworkTechniqueFailure) em erro remoto', () async {
      remote.updateError = Exception('error');
      final result = await repo.update(academyId: 'ac1', id: 'id1', name: 'X');
      result.fold(
        (f) => expect(f, isA<NetworkTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- delete ----
  group('delete', () {
    test('retorna Right(unit) em sucesso', () async {
      final result = await repo.delete(academyId: 'ac1', id: 'id1');
      expect(result.isRight(), isTrue);
    });

    test('remove item do cache', () async {
      local._store['ac1'] = [makeDto(), makeDto(id: 'id2', name: 'Triângulo')];
      await repo.delete(academyId: 'ac1', id: 'id1');
      expect(local.get('ac1')?.any((d) => d.id == 'id1'), isFalse);
      expect(local.get('ac1')?.any((d) => d.id == 'id2'), isTrue);
    });

    test('retorna Left(NetworkTechniqueFailure) em erro remoto', () async {
      remote.deleteError = Exception('error');
      final result = await repo.delete(academyId: 'ac1', id: 'id1');
      result.fold(
        (f) => expect(f, isA<NetworkTechniqueFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- clearLocalCache ----
  group('clearLocalCache', () {
    test('remove entrada do cache local', () async {
      local._store['ac1'] = [makeDto()];
      await repo.clearLocalCache('ac1');
      expect(local.get('ac1'), isNull);
    });

    test('não lança quando cache já estava vazio', () async {
      await expectLater(repo.clearLocalCache('ac1'), completes);
    });
  });
}
