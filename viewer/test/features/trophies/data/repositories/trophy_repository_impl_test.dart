import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer/features/trophies/data/datasources/trophy_local_datasource.dart';
import 'package:viewer/features/trophies/data/datasources/trophy_remote_datasource.dart';
import 'package:viewer/features/trophies/data/models/trophy_dto.dart';
import 'package:viewer/features/trophies/data/repositories/trophy_repository_impl.dart';
import 'package:viewer/features/trophies/domain/failures/trophy_failure.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeRemote implements TrophyRemoteDataSource {
  List<TrophyDto> items = [];
  Object? fetchError;
  Object? createError;
  Object? updateError;
  Object? deleteError;
  TrophyDto? createResult;
  TrophyDto? updateResult;

  @override
  Future<List<TrophyDto>> fetchAll(String academyId) async {
    if (fetchError != null) throw fetchError!;
    return items;
  }

  @override
  Future<TrophyDto> create({
    required String academyId,
    required String techniqueId,
    required String name,
    required String startDate,
    required String endDate,
    required int targetCount,
    required String awardKind,
    int? minDurationDays,
    int minRewardLevelToUnlock = 0,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,
  }) async {
    if (createError != null) throw createError!;
    return createResult ?? makeDto(id: 'new-id', name: name);
  }

  @override
  Future<TrophyDto> update({
    required String id,
    String? techniqueId,
    String? name,
    String? startDate,
    String? endDate,
    int? targetCount,
    String? awardKind,
    int? minDurationDays,
    int? minRewardLevelToUnlock,
    String? minGraduationToUnlock,
    int? maxCountPerOpponent,
    bool setMaxCountPerOpponent = false,
  }) async {
    if (updateError != null) throw updateError!;
    return updateResult ?? makeDto(id: id, name: name ?? 'updated');
  }

  @override
  Future<void> delete(String id) async {
    if (deleteError != null) throw deleteError!;
  }
}

class FakeLocal implements TrophyLocalDataSource {
  final Map<String, List<TrophyDto>> _store = {};
  Object? readError;
  Object? writeError;

  @override
  Future<List<TrophyDto>?> read(String academyId) async {
    if (readError != null) throw const CacheTrophyFailure('read failed');
    return _store[academyId];
  }

  @override
  Future<void> write(String academyId, List<TrophyDto> items) async {
    if (writeError != null) throw const CacheTrophyFailure('write failed');
    _store[academyId] = List<TrophyDto>.from(items);
  }

  @override
  Future<void> clear(String academyId) async => _store.remove(academyId);

  List<TrophyDto>? get(String academyId) => _store[academyId];
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

TrophyDto makeDto({String id = 'tr1', String name = 'Armlock 5x'}) =>
    TrophyDto(
      id: id,
      academyId: 'ac1',
      techniqueId: 'tech1',
      name: name,
      startDateIso: '2026-01-01',
      endDateIso: '2026-12-31',
      targetCount: 5,
      awardKind: 'trophy',
    );

void main() {
  late FakeRemote remote;
  late FakeLocal local;
  late TrophyRepositoryImpl repo;

  setUp(() {
    remote = FakeRemote();
    local = FakeLocal();
    repo = TrophyRepositoryImpl(remote: remote, local: local);
  });

  // ---- getCached ----
  group('getCached', () {
    test('retorna Right([]) quando cache vazio', () async {
      final result = await repo.getCached('ac1');
      result.fold(
        (f) => fail('esperava Right'),
        (list) => expect(list, isEmpty),
      );
    });

    test('retorna entidades quando há dados no cache', () async {
      local._store['ac1'] = [makeDto()];
      final result = await repo.getCached('ac1');
      result.fold(
        (f) => fail('esperava Right'),
        (list) {
          expect(list, hasLength(1));
          expect(list.first.name, 'Armlock 5x');
        },
      );
    });

    test('retorna Left(CacheTrophyFailure) em erro de leitura', () async {
      local.readError = const CacheTrophyFailure('read failed');
      final result = await repo.getCached('ac1');
      result.fold(
        (f) => expect(f, isA<CacheTrophyFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- syncFromRemote ----
  group('syncFromRemote', () {
    test('retorna Right com entidades e persiste no cache', () async {
      remote.items = [makeDto(), makeDto(id: 'tr2', name: 'Triângulo')];
      final result = await repo.syncFromRemote('ac1');
      result.fold(
        (f) => fail('esperava Right'),
        (list) => expect(list, hasLength(2)),
      );
      expect(local.get('ac1'), hasLength(2));
    });

    test('retorna Left(NetworkTrophyFailure) em erro de rede', () async {
      remote.fetchError = Exception('timeout');
      final result = await repo.syncFromRemote('ac1');
      result.fold(
        (f) => expect(f, isA<NetworkTrophyFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('retorna entidades mesmo quando Hive write falha', () async {
      remote.items = [makeDto()];
      local.writeError = const CacheTrophyFailure('write fail');
      final result = await repo.syncFromRemote('ac1');
      result.fold(
        (f) => fail('esperava Right mesmo com falha de cache'),
        (list) => expect(list, hasLength(1)),
      );
    });
  });

  // ---- create ----
  group('create', () {
    test('retorna Right com entidade criada', () async {
      remote.createResult = makeDto(id: 'new-id', name: 'Guarda 3x');
      final result = await repo.create(
        academyId: 'ac1',
        techniqueId: 'tech1',
        name: 'Guarda 3x',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        targetCount: 3,
        awardKind: 'trophy',
      );
      result.fold(
        (f) => fail('esperava Right'),
        (e) => expect(e.id, 'new-id'),
      );
    });

    test('novo item é adicionado ao cache', () async {
      remote.createResult = makeDto(id: 'new-id', name: 'Guarda 3x');
      await repo.create(
        academyId: 'ac1',
        techniqueId: 'tech1',
        name: 'Guarda 3x',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        targetCount: 3,
        awardKind: 'trophy',
      );
      expect(local.get('ac1')?.any((d) => d.id == 'new-id'), isTrue);
    });

    test('retorna Left(NetworkTrophyFailure) em erro remoto', () async {
      remote.createError = Exception('network error');
      final result = await repo.create(
        academyId: 'ac1',
        techniqueId: 'tech1',
        name: 'X',
        startDate: '2026-01-01',
        endDate: '2026-12-31',
        targetCount: 1,
        awardKind: 'trophy',
      );
      result.fold(
        (f) => expect(f, isA<NetworkTrophyFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- update ----
  group('update', () {
    test('retorna Right com entidade atualizada', () async {
      local._store['ac1'] = [makeDto()];
      remote.updateResult = makeDto(id: 'tr1', name: 'Armlock 10x');
      final result = await repo.update(id: 'tr1', academyId: 'ac1', name: 'Armlock 10x');
      result.fold(
        (f) => fail('esperava Right'),
        (e) => expect(e.name, 'Armlock 10x'),
      );
    });

    test('substitui item no cache (merge preserva os demais)', () async {
      local._store['ac1'] = [makeDto(), makeDto(id: 'tr2', name: 'Triângulo')];
      remote.updateResult = makeDto(id: 'tr1', name: 'Armlock 10x');
      await repo.update(id: 'tr1', academyId: 'ac1', name: 'Armlock 10x');
      final cached = local.get('ac1')!;
      expect(cached, hasLength(2));
      expect(cached.any((d) => d.name == 'Armlock 10x'), isTrue);
      expect(cached.any((d) => d.name == 'Triângulo'), isTrue);
    });

    test('retorna Left(NetworkTrophyFailure) em erro remoto', () async {
      remote.updateError = Exception('error');
      final result = await repo.update(id: 'tr1', academyId: 'ac1');
      result.fold(
        (f) => expect(f, isA<NetworkTrophyFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  // ---- delete ----
  group('delete', () {
    test('retorna Right(unit) em sucesso', () async {
      final result = await repo.delete(academyId: 'ac1', id: 'tr1');
      expect(result.isRight(), isTrue);
    });

    test('remove item do cache', () async {
      local._store['ac1'] = [makeDto(), makeDto(id: 'tr2', name: 'Triângulo')];
      await repo.delete(academyId: 'ac1', id: 'tr1');
      expect(local.get('ac1')?.any((d) => d.id == 'tr1'), isFalse);
      expect(local.get('ac1')?.any((d) => d.id == 'tr2'), isTrue);
    });

    test('retorna Left(NetworkTrophyFailure) em erro remoto', () async {
      remote.deleteError = Exception('error');
      final result = await repo.delete(academyId: 'ac1', id: 'tr1');
      result.fold(
        (f) => expect(f, isA<NetworkTrophyFailure>()),
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
  });
}
